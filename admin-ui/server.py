#!/usr/bin/env python3
"""
Admin UI Server with Proxy - Runs on port 8080
Proxies API requests to backend services to avoid CORS issues
"""

import http.server
import socketserver
import os
import urllib.request
import urllib.error
import json
from urllib.parse import urlparse, parse_qs

PORT = 8080

# Maps port numbers (used in /api/<port>/... URLs) to container hostnames.
# Defaults to 'localhost' so the server works outside Docker without changes.
SERVICE_HOSTS = {
    '3000': os.getenv('API_GATEWAY_HOST',       'localhost'),
    '3001': os.getenv('PRODUCT_SERVICE_HOST',   'localhost'),
    '3002': os.getenv('ORDER_SERVICE_HOST',     'localhost'),
    '3003': os.getenv('PAYMENT_SERVICE_HOST',   'localhost'),
    '3004': os.getenv('INVENTORY_SERVICE_HOST', 'localhost'),
    '3005': os.getenv('EMAIL_SERVICE_HOST',     'localhost'),
}

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    
    def do_GET(self):
        # Handle API proxy requests
        if self.path.startswith('/api/'):
            self.handle_proxy('GET')
        else:
            # Serve static files
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/api/'):
            self.handle_proxy('POST')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_PUT(self):
        if self.path.startswith('/api/'):
            self.handle_proxy('PUT')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_DELETE(self):
        if self.path.startswith('/api/'):
            self.handle_proxy('DELETE')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_OPTIONS(self):
        # Handle preflight requests
        self.send_response(200)
        self.end_headers()
    
    def handle_proxy(self, method):
        try:
            # Parse path: /api/3001/products -> http://localhost:3001/products
            parts = self.path.split('/')
            if len(parts) >= 3:
                port = parts[2]
                remaining_path = '/' + '/'.join(parts[3:])
                host = SERVICE_HOSTS.get(port, 'localhost')
                target_url = f"http://{host}:{port}{remaining_path}"
                
                # Add query string if present
                if self.path.find('?') > 0:
                    target_url += self.path[self.path.find('?'):]
                
                print(f"Proxying {method} request to: {target_url}")
                
                # Prepare request
                req = urllib.request.Request(target_url, method=method)
                req.add_header('Content-Type', 'application/json')
                
                # For POST/PUT, read body
                data = None
                if method in ['POST', 'PUT']:
                    content_length = self.headers.get('Content-Length')
                    if content_length:
                        data = self.rfile.read(int(content_length))
                
                # Make the request
                with urllib.request.urlopen(req, data=data, timeout=5) as response:
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(response.read())
                    
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())
        except urllib.error.URLError as e:
            self.send_response(503)
            self.end_headers()
            self.wfile.write(json.dumps({'error': f'Service unavailable: {str(e)}'}).encode())
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

# Change to the directory containing this script
os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("=" * 50)
print("Admin UI Server with Proxy")
print("=" * 50)
print(f"UI URL: http://localhost:{PORT}")
print("")
print("API Proxy Mapping:")
print("  /api/3000/* -> http://localhost:3000/*")
print("  /api/3001/* -> http://localhost:3001/*")
print("  /api/3002/* -> http://localhost:3002/*")
print("  /api/3003/* -> http://localhost:3003/*")
print("  /api/3005/* -> http://localhost:3005/*")
print("=" * 50)
print("Press Ctrl+C to stop")
print("")

with socketserver.TCPServer(("", PORT), ProxyHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")