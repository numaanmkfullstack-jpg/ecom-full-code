import pika
import json
import os
import requests
import psycopg2
from dotenv import load_dotenv
import time
import threading
from flask import Flask, jsonify, request

# ======================
# LOAD ENV
# ======================
load_dotenv()

# ======================
# CONFIG (ENV DRIVEN)
# ======================
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'localhost')
RABBITMQ_QUEUE = os.getenv('RABBITMQ_QUEUE', 'inventory_orders')

POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'localhost')
POSTGRES_DB = os.getenv('POSTGRES_DB', 'inventory')
POSTGRES_USER = os.getenv('POSTGRES_USER', 'postgres')
POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'postgres123')

EMAIL_SERVICE_URL = os.getenv('EMAIL_SERVICE_URL', 'http://localhost:3005')

# Flask app for HTTP endpoint
app = Flask(__name__)

# ======================
# DATABASE INITIALIZATION (AUTO-CREATE TABLE)
# ======================
def init_database():
    """Create stock table and indexes if they don't exist, plus insert default stock"""
    try:
        conn = psycopg2.connect(
            host=POSTGRES_HOST,
            database=POSTGRES_DB,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD
        )
        cur = conn.cursor()
        
        # Create stock table if not exists
        cur.execute("""
            CREATE TABLE IF NOT EXISTS stock (
                product_id VARCHAR(36) PRIMARY KEY,
                quantity INTEGER NOT NULL DEFAULT 0,
                last_updated TIMESTAMP NOT NULL DEFAULT NOW()
            )
        """)
        
        # Create index for faster low-stock queries
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_stock_quantity 
            ON stock(quantity)
        """)
        
        conn.commit()
        print("✅ Stock table verified/created")
        
        # Insert default stock if table is empty
        cur.execute("SELECT COUNT(*) FROM stock")
        count = cur.fetchone()[0]
        
        if count == 0:
            print("📦 Inserting default stock data...")
            cur.execute("""
                INSERT INTO stock (product_id, quantity) VALUES 
                ('6a2914382d73c5edd9cc11f9', 100),
                ('6a290d0f2d73c5edd9cc11f7', 50),
                ('6a290d6e2d73c5edd9cc11f8', 25)
                ON CONFLICT (product_id) DO NOTHING
            """)
            conn.commit()
            print("✅ Default stock inserted (100, 50, 25)")
        
        cur.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Database init error: {e}")
        print("Retrying in 5 seconds...")
        time.sleep(5)
        init_database()

# ======================
# DATABASE CONNECTION
# ======================
def get_db_connection():
    return psycopg2.connect(
        host=POSTGRES_HOST,
        database=POSTGRES_DB,
        user=POSTGRES_USER,
        password=POSTGRES_PASSWORD
    )

# ======================
# STOCK UPDATE LOGIC
# ======================
def update_stock(product_id, quantity_change):
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            UPDATE stock 
            SET quantity = quantity + %s, 
                last_updated = NOW()
            WHERE product_id = %s
            RETURNING quantity
        """, (quantity_change, product_id))

        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        if result:
            new_quantity = result[0]
            print(f"[STOCK] {product_id} updated → {new_quantity}")

            # low stock alert
            if new_quantity < 10:
                try:
                    requests.post(
                        f"{EMAIL_SERVICE_URL}/alert",
                        json={
                            "product_id": product_id,
                            "current_stock": new_quantity,
                            "threshold": 10
                        },
                        timeout=5
                    )
                    print(f"[ALERT] Low stock email sent for {product_id}")
                except Exception as e:
                    print(f"[ALERT ERROR] {e}")

            return new_quantity
        else:
            print(f"[WARN] Product not found: {product_id}")
            return None

    except Exception as e:
        print(f"[DB ERROR] {e}")
        return None

# ======================
# FLASK HTTP ENDPOINTS
# ======================

@app.route('/inventory', methods=['GET'])
def get_inventory():
    """Get all stock levels"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT product_id, quantity, last_updated FROM stock ORDER BY product_id")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        
        inventory = []
        for row in rows:
            inventory.append({
                'product_id': row[0],
                'quantity': row[1],
                'last_updated': row[2].isoformat() if row[2] else None
            })
        
        return jsonify(inventory)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/inventory/<product_id>', methods=['GET'])
def get_stock_by_product(product_id):
    """Get stock for a specific product"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT product_id, quantity, last_updated FROM stock WHERE product_id = %s", (product_id,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        
        if row:
            return jsonify({
                'product_id': row[0],
                'quantity': row[1],
                'last_updated': row[2].isoformat() if row[2] else None
            })
        else:
            return jsonify({'error': 'Product not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/inventory', methods=['POST'])
def add_stock():
    """Add or update stock for a product"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        product_id = data.get('product_id')
        quantity = data.get('quantity', 0)
        
        if not product_id:
            return jsonify({'error': 'product_id is required'}), 400
        
        if not isinstance(quantity, int) or quantity <= 0:
            return jsonify({'error': 'quantity must be a positive integer'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        # Insert or update stock
        cur.execute("""
            INSERT INTO stock (product_id, quantity, last_updated)
            VALUES (%s, %s, NOW())
            ON CONFLICT (product_id) DO UPDATE 
            SET quantity = EXCLUDED.quantity, last_updated = NOW()
            RETURNING quantity
        """, (product_id, quantity))
        
        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        print(f"[STOCK ADDED] {product_id} → {quantity}")
        
        return jsonify({
            'message': 'Stock added/updated successfully',
            'product_id': product_id,
            'quantity': quantity
        }), 201
        
    except Exception as e:
        print(f"[ERROR] Add stock failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/inventory/<product_id>', methods=['PUT'])
def update_stock_amount(product_id):
    """Update stock for a specific product (replace quantity)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        quantity = data.get('quantity')
        
        if quantity is None:
            return jsonify({'error': 'quantity is required'}), 400
        
        if not isinstance(quantity, int) or quantity < 0:
            return jsonify({'error': 'quantity must be a non-negative integer'}), 400
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            INSERT INTO stock (product_id, quantity, last_updated)
            VALUES (%s, %s, NOW())
            ON CONFLICT (product_id) DO UPDATE 
            SET quantity = EXCLUDED.quantity, last_updated = NOW()
            RETURNING quantity
        """, (product_id, quantity))
        
        result = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()
        
        print(f"[STOCK UPDATED] {product_id} → {quantity}")
        
        return jsonify({
            'message': 'Stock updated successfully',
            'product_id': product_id,
            'quantity': quantity
        }), 200
        
    except Exception as e:
        print(f"[ERROR] Update stock failed: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check for the inventory service"""
    return jsonify({'status': 'healthy', 'service': 'inventory-service'})

def run_flask():
    """Run Flask server on port 3004"""
    app.run(host='0.0.0.0', port=3004, debug=False, use_reloader=False)

# ======================
# RABBITMQ CALLBACK
# ======================
def callback(ch, method, properties, body):
    try:
        order = json.loads(body)
        print(f"\n[ORDER RECEIVED] {order['orderId']}")

        for item in order.get('items', []):
            product_id = item['productId']
            quantity = item['quantity']
            new_stock = update_stock(product_id, -quantity)

            if new_stock is None:
                print(f"[FAIL] Could not update {product_id}")

        ch.basic_ack(delivery_tag=method.delivery_tag)
        print(f"[DONE] Order processed: {order['orderId']}")

    except Exception as e:
        print(f"[ERROR] Processing failed: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

# ======================
# WAIT FOR DEPENDENCIES
# ======================
def wait_for_rabbitmq():
    """Wait for RabbitMQ to be ready"""
    max_retries = 10
    for i in range(max_retries):
        try:
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(host=RABBITMQ_HOST)
            )
            connection.close()
            print("✅ RabbitMQ connected")
            return True
        except Exception as e:
            print(f"⏳ Waiting for RabbitMQ... ({i+1}/{max_retries})")
            time.sleep(3)
    return False

# ======================
# MAIN WORKER
# ======================
def main():
    print("[STARTING] Inventory Worker")
    
    # Initialize database (creates table and default stock)
    init_database()
    
    # Start Flask HTTP server in a separate thread
    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()
    print("✅ HTTP server started on port 3004")
    
    # Wait for RabbitMQ
    if not wait_for_rabbitmq():
        print("❌ RabbitMQ not available. Exiting.")
        return
    
    # Connect to RabbitMQ
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=RABBITMQ_HOST)
    )
    
    channel = connection.channel()
    channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(
        queue=RABBITMQ_QUEUE,
        on_message_callback=callback
    )
    
    print(f"[LISTENING] Queue: {RABBITMQ_QUEUE}")
    print("[READY] Waiting for orders...")
    print("[HTTP] Inventory API available at http://localhost:3004/inventory")
    print("[HTTP] POST /inventory - Add stock")
    print("[HTTP] PUT /inventory/{id} - Update stock")
    
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print("\n[STOPPED] Worker shutdown")
        channel.close()
        connection.close()

if __name__ == '__main__':
    main()