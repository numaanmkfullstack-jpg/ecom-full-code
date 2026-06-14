// API endpoints via proxy (no CORS issues!)
const API_GATEWAY = '/api/3000';
const PRODUCT_SERVICE = '/api/3001';
const ORDER_SERVICE = '/api/3002';
const PAYMENT_SERVICE = '/api/3003';
const EMAIL_SERVICE = '/api/3005';
const INVENTORY_SERVICE = '/api/3004';

// Track created orders
let createdOrders = [];
let availableProducts = [];

// =========================
// SERVICE HEALTH CHECKS
// =========================

async function checkServiceHealth() {
    const services = [
        { name: 'API Gateway', url: `${API_GATEWAY}/health`, port: 3000 },
        { name: 'Product Service', url: `${PRODUCT_SERVICE}/health`, port: 3001 },
        { name: 'Order Service', url: `${ORDER_SERVICE}/health`, port: 3002 },
        { name: 'Payment Service', url: `${PAYMENT_SERVICE}/health`, port: 3003 },
        { name: 'Inventory Service', url: `${INVENTORY_SERVICE}/health`, port: 3004 },
        { name: 'Email Service', url: `${EMAIL_SERVICE}/health`, port: 3005 }
    ];
    
    const results = [];
    
    for (const service of services) {
        try {
            const response = await fetch(service.url);
            const isRunning = response.status === 200;
            results.push({
                name: service.name,
                status: isRunning ? 'UP' : 'DOWN',
                code: response.status
            });
        } catch (error) {
            results.push({
                name: service.name,
                status: 'DOWN',
                code: 0
            });
        }
    }
    
    displayHealth(results);
}

function displayHealth(services) {
    const container = document.getElementById('health-status');
    container.innerHTML = services.map(service => `
        <div class="health-card ${service.status === 'UP' ? 'healthy' : 'unhealthy'}">
            <h3>${service.name}</h3>
            <p>Status: ${service.status}</p>
            <small>HTTP: ${service.code}</small>
        </div>
    `).join('');
}

// =========================
// PRODUCT SERVICE
// =========================

async function loadProducts() {
    const container = document.getElementById('products-list');
    container.innerHTML = '<div class="loading">Loading products...</div>';
    
    try {
        const response = await fetch(`${PRODUCT_SERVICE}/products`);
        const data = await response.json();
        
        if (data.data && data.data.length > 0) {
            availableProducts = data.data;
            displayProducts(data.data);
            updateProductDropdown();
            updateStockProductDropdown();
        } else {
            container.innerHTML = '<div class="loading">No products found. Add one using the form above!</div>';
        }
    } catch (error) {
        container.innerHTML = `<div class="error">⚠️ Error loading products: ${error.message}</div>`;
    }
}

function displayProducts(products) {
    const container = document.getElementById('products-list');
    container.innerHTML = `
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Price</th>
                    <th>Category</th>
                    <th>In Stock</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${products.map(product => `
                    <tr>
                        <td><code>${product._id.substring(0, 16)}...</code></td>
                        <td><strong>${escapeHtml(product.name)}</strong></td>
                        <td>$${product.price.toFixed(2)}</span>点
                        <td>${escapeHtml(product.category || '-')}</span>点
                        <td>${product.in_stock ? '✅ Yes' : '❌ No'}</span>点
                        <td>
                            <button onclick="deleteProduct('${product._id}')" class="btn-danger">Delete</button>
                        </span>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

async function createProduct() {
    const name = document.getElementById('product-name').value;
    const price = parseFloat(document.getElementById('product-price').value);
    const category = document.getElementById('product-category').value;
    
    if (!name || isNaN(price)) {
        alert('Please fill in Product Name and Price');
        return;
    }
    
    const createBtn = event.target;
    const originalText = createBtn.innerText;
    createBtn.innerText = 'Creating...';
    createBtn.disabled = true;
    
    try {
        const response = await fetch(`${PRODUCT_SERVICE}/products`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                name, 
                price, 
                category: category || 'uncategorized', 
                in_stock: true 
            })
        });
        
        if (response.status === 201) {
            alert('✅ Product created successfully!');
            hideCreateProductForm();
            loadProducts();
        } else {
            const error = await response.json();
            alert(`❌ Error: ${error.error}`);
        }
    } catch (error) {
        alert(`❌ Error: ${error.message}`);
    } finally {
        createBtn.innerText = originalText;
        createBtn.disabled = false;
    }
}

async function deleteProduct(productId) {
    if (!confirm('Are you sure you want to delete this product?')) return;
    
    try {
        const response = await fetch(`${PRODUCT_SERVICE}/products/${productId}`, {
            method: 'DELETE'
        });
        
        if (response.status === 200) {
            alert('✅ Product deleted successfully!');
            loadProducts();
        } else {
            alert('❌ Error deleting product');
        }
    } catch (error) {
        alert(`❌ Error: ${error.message}`);
    }
}

function showCreateProductForm() {
    document.getElementById('create-product-form').style.display = 'block';
}

function hideCreateProductForm() {
    document.getElementById('create-product-form').style.display = 'none';
    document.getElementById('product-name').value = '';
    document.getElementById('product-price').value = '';
    document.getElementById('product-category').value = '';
}

// =========================
// ORDER SERVICE
// =========================

function updateProductDropdown() {
    const select = document.getElementById('product-select');
    if (!select) return;
    
    if (availableProducts.length === 0) {
        select.innerHTML = '<option value="">No products available. Create one first!</option>';
        return;
    }
    
    select.innerHTML = '<option value="">-- Select a product --</option>';
    availableProducts.forEach(product => {
        select.innerHTML += `<option value="${product._id}">${product.name} - $${product.price.toFixed(2)} (${product.category})</option>`;
    });
    
    select.onchange = function() {
        const selectedProduct = availableProducts.find(p => p._id === select.value);
        if (selectedProduct) {
            const quantity = document.getElementById('order-quantity').value || 1;
            const total = selectedProduct.price * quantity;
            document.getElementById('order-total').value = total.toFixed(2);
        }
    };
}

async function loadOrders() {
    const container = document.getElementById('orders-list');
    if (createdOrders.length === 0) {
        container.innerHTML = '<div class="loading">No orders created yet. Use the form above to create an order!</div>';
    } else {
        displayOrders();
    }
}

function displayOrders() {
    const container = document.getElementById('orders-list');
    container.innerHTML = `
        <table>
            <thead>
                <tr>
                    <th>Order ID</th>
                    <th>User ID</th>
                    <th>Product</th>
                    <th>Quantity</th>
                    <th>Total</th>
                    <th>Status</th>
                    <th>Created At</th>
                </tr>
            </thead>
            <tbody>
                ${createdOrders.map(order => {
                    const product = availableProducts.find(p => p._id === order.items[0].productId);
                    const productName = product ? product.name : order.items[0].productId.substring(0, 16) + '...';
                    return `
                        <tr>
                            <td><code>${escapeHtml(order.id)}</code></td>
                            <td>${escapeHtml(order.userId)}</span>
                            <td>${escapeHtml(productName)}</span>
                            <td>${order.items[0].quantity}</span>
                            <td>$${order.total.toFixed(2)}</span>
                            <td><span style="background:#d4edda;padding:2px 8px;border-radius:12px;">${escapeHtml(order.status)}</span></span>
                            <td>${new Date(order.createdAt).toLocaleTimeString()}</span>
                        </tr>
                    `;
                }).join('')}
            </tbody>
        </table>
    `;
}

async function createOrder() {
    const orderId = document.getElementById('order-id').value;
    const userId = document.getElementById('user-id').value;
    const productSelect = document.getElementById('product-select');
    const productId = productSelect.value;
    const quantity = parseInt(document.getElementById('order-quantity').value);
    let total = parseFloat(document.getElementById('order-total').value);
    
    if (!orderId || !userId || !productId || isNaN(quantity) || quantity <= 0) {
        alert('Please fill in all fields and select a product');
        return;
    }
    
    const selectedProduct = availableProducts.find(p => p._id === productId);
    if (selectedProduct && (isNaN(total) || total === 0)) {
        total = selectedProduct.price * quantity;
    }
    
    if (isNaN(total) || total <= 0) {
        alert('Please enter a valid total amount');
        return;
    }
    
    const orderData = {
        id: orderId,
        userId: userId,
        items: [{ productId: productId, quantity: quantity }],
        total: total,
        paymentMethod: 'credit_card'
    };
    
    const placeOrderBtn = event.target;
    const originalText = placeOrderBtn.innerText;
    placeOrderBtn.innerText = 'Processing...';
    placeOrderBtn.disabled = true;
    
    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        
        const response = await fetch(`${API_GATEWAY}/api/orders`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(orderData),
            signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        const result = await response.json();
        
        if (response.status === 201 || response.status === 200) {
            createdOrders.unshift({
                ...orderData,
                status: result.status,
                createdAt: new Date()
            });
            alert(`✅ Order created successfully!\nStatus: ${result.status}`);
            hideCreateOrderForm();
            loadOrders();
            clearOrderForm();
            setTimeout(() => loadInventory(), 1000);
        } else {
            alert(`❌ Error: ${result.error || result.message}`);
        }
    } catch (error) {
        if (error.name === 'AbortError') {
            alert('⚠️ Order is still processing. It may appear in the list shortly.');
            createdOrders.unshift({
                ...orderData,
                status: 'PROCESSING',
                createdAt: new Date()
            });
            loadOrders();
            clearOrderForm();
            hideCreateOrderForm();
        } else {
            alert(`❌ Error: ${error.message}`);
        }
    } finally {
        placeOrderBtn.innerText = originalText;
        placeOrderBtn.disabled = false;
    }
}

function clearOrderForm() {
    document.getElementById('order-id').value = '';
    document.getElementById('user-id').value = '';
    const select = document.getElementById('product-select');
    if (select) select.value = '';
    document.getElementById('order-quantity').value = '1';
    document.getElementById('order-total').value = '';
}

function setupQuantityListener() {
    const quantityInput = document.getElementById('order-quantity');
    if (quantityInput) {
        quantityInput.addEventListener('input', function() {
            const select = document.getElementById('product-select');
            const selectedProduct = availableProducts.find(p => p._id === select.value);
            if (selectedProduct) {
                const quantity = parseInt(this.value) || 0;
                const total = selectedProduct.price * quantity;
                document.getElementById('order-total').value = total.toFixed(2);
            }
        });
    }
}

function showCreateOrderForm() {
    document.getElementById('create-order-form').style.display = 'block';
    updateProductDropdown();
    setupQuantityListener();
}

function hideCreateOrderForm() {
    document.getElementById('create-order-form').style.display = 'none';
    clearOrderForm();
}

// =========================
// INVENTORY SERVICE
// =========================

async function loadInventory() {
    const container = document.getElementById('inventory-list');
    container.innerHTML = '<div class="loading">Loading inventory...</div>';
    
    try {
        const response = await fetch(`${INVENTORY_SERVICE}/inventory`);
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.length > 0) {
            displayInventory(data);
        } else {
            container.innerHTML = '<div class="loading">No inventory data found.</div>';
        }
    } catch (error) {
        container.innerHTML = `<div class="error">⚠️ Error loading inventory: ${error.message}</div>`;
    }
}

function displayInventory(inventory) {
    const container = document.getElementById('inventory-list');
    
    container.innerHTML = `
        <table>
            <thead>
                <tr>
                    <th>Product ID</th>
                    <th>Product Name</th>
                    <th>Quantity</th>
                    <th>Status</th>
                    <th>Last Updated</th>
                </tr>
            </thead>
            <tbody>
                ${inventory.map(item => {
                    const product = availableProducts.find(p => p._id === item.product_id);
                    const productName = product ? product.name : item.product_id.substring(0, 16) + '...';
                    const status = item.quantity < 10 ? '⚠️ Low Stock' : '✅ In Stock';
                    const statusClass = item.quantity < 10 ? 'low-stock' : 'in-stock';
                    
                    return `
                        <tr>
                            <td><code>${item.product_id.substring(0, 16)}...</code></td>
                            <td><strong>${escapeHtml(productName)}</strong></td>
                            <td><strong>${item.quantity}</strong></td>
                            <td><span class="${statusClass}">${status}</span></td>
                            <td>${new Date(item.last_updated).toLocaleString()}</td>
                        </tr>
                    `;
                }).join('')}
            </tbody>
        </table>
    `;
}

function updateStockProductDropdown() {
    const select = document.getElementById('stock-product-select');
    if (!select) return;
    
    if (availableProducts.length === 0) {
        select.innerHTML = '<option value="">No products available</option>';
        return;
    }
    
    select.innerHTML = '<option value="">-- Select a product --</option>';
    availableProducts.forEach(product => {
        select.innerHTML += `<option value="${product._id}">${product.name} - $${product.price.toFixed(2)}</option>`;
    });
    
    select.onchange = function() {
        if (select.value) {
            document.getElementById('stock-product-id').value = select.value;
        }
    };
}

async function addStock() {
    const productId = document.getElementById('stock-product-id').value;
    const quantity = parseInt(document.getElementById('stock-quantity').value);
    
    if (!productId) {
        alert('Please enter or select a Product ID');
        return;
    }
    
    if (isNaN(quantity) || quantity <= 0) {
        alert('Please enter a valid quantity');
        return;
    }
    
    const addBtn = event.target;
    const originalText = addBtn.innerText;
    addBtn.innerText = 'Adding...';
    addBtn.disabled = true;
    
    try {
        const response = await fetch(`${INVENTORY_SERVICE}/inventory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                product_id: productId,
                quantity: quantity
            })
        });
        
        const result = await response.json();
        
        if (response.status === 201 || response.status === 200) {
            alert(`✅ Added ${quantity} stock for product ${productId}`);
            loadInventory();
            clearStockForm();
        } else {
            alert(`❌ Error: ${result.error || 'Failed to add stock'}`);
        }
    } catch (error) {
        alert(`❌ Error: ${error.message}`);
    } finally {
        addBtn.innerText = originalText;
        addBtn.disabled = false;
    }
}

function clearStockForm() {
    document.getElementById('stock-product-id').value = '';
    const select = document.getElementById('stock-product-select');
    if (select) select.value = '';
    document.getElementById('stock-quantity').value = '100';
}

// =========================
// HELPER FUNCTIONS
// =========================

function copyToClipboard(text) {
    navigator.clipboard.writeText(text);
    alert('✅ Product ID copied to clipboard:\n' + text);
}

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// =========================
// INITIALIZATION
// =========================

function init() {
    console.log('Admin UI starting...');
    checkServiceHealth();
    loadProducts();
    loadOrders();
    loadInventory();
    
    setInterval(checkServiceHealth, 30000);
    setInterval(loadProducts, 60000);
    setInterval(loadInventory, 10000);
}

window.addEventListener('DOMContentLoaded', init);