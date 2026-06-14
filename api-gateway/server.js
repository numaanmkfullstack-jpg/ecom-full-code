const express = require('express');
const cors = require('cors');
const http = require('http');

const ORDER_SERVICE_HOST    = process.env.ORDER_SERVICE_HOST    || 'localhost';
const PRODUCT_SERVICE_HOST  = process.env.PRODUCT_SERVICE_HOST  || 'localhost';
const PAYMENT_SERVICE_HOST  = process.env.PAYMENT_SERVICE_HOST  || 'localhost';

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Log all requests
app.use((req, res, next) => {
    console.log(`📨 ${req.method} ${req.url}`);
    console.log(`   Body:`, req.body);
    next();
});

// =========================
// ORDER SERVICE PROXY
// =========================
app.post('/api/orders', (req, res) => {
    console.log(`🔄 Forwarding to order service`);
    console.log(`   Body:`, req.body);
    
    const postData = JSON.stringify(req.body);
    
    const options = {
        hostname: ORDER_SERVICE_HOST,
        port: 3002,
        path: '/orders',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };
    
    const proxyReq = http.request(options, (proxyRes) => {
        let responseData = '';
        proxyRes.on('data', chunk => {
            responseData += chunk.toString();
        });
        proxyRes.on('end', () => {
            console.log(`   Response: ${responseData}`);
            res.writeHead(proxyRes.statusCode, { 'Content-Type': 'application/json' });
            res.end(responseData);
        });
    });
    
    proxyReq.on('error', (err) => {
        console.error(`❌ Order service error: ${err.message}`);
        res.status(503).json({ error: 'Order service unavailable' });
    });
    
    proxyReq.write(postData);
    proxyReq.end();
});

// =========================
// PRODUCT SERVICE PROXY
// =========================
app.use('/api/products', (req, res) => {
    let bodyData = '';
    req.on('data', chunk => {
        bodyData += chunk.toString();
    });
    
    req.on('end', () => {
        const options = {
            hostname: PRODUCT_SERVICE_HOST,
            port: 3001,
            path: `/products${req.url}`,
            method: req.method,
            headers: {
                'Content-Type': req.headers['content-type'] || 'application/json',
                'Content-Length': Buffer.byteLength(bodyData)
            }
        };
        
        const proxyReq = http.request(options, (proxyRes) => {
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            proxyRes.pipe(res);
        });
        
        proxyReq.on('error', (err) => {
            console.error(`❌ Product service error: ${err.message}`);
            res.status(503).json({ error: 'Product service unavailable' });
        });
        
        if (bodyData) {
            proxyReq.write(bodyData);
        }
        proxyReq.end();
    });
});

// =========================
// PAYMENT SERVICE PROXY
// =========================
app.use('/api/payments', (req, res) => {
    let bodyData = '';
    req.on('data', chunk => {
        bodyData += chunk.toString();
    });
    
    req.on('end', () => {
        const options = {
            hostname: PAYMENT_SERVICE_HOST,
            port: 3003,
            path: req.url,
            method: req.method,
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(bodyData)
            }
        };
        
        const proxyReq = http.request(options, (proxyRes) => {
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            proxyRes.pipe(res);
        });
        
        proxyReq.on('error', (err) => {
            console.error(`❌ Payment service error: ${err.message}`);
            res.status(503).json({ error: 'Payment service unavailable' });
        });
        
        if (bodyData) {
            proxyReq.write(bodyData);
        }
        proxyReq.end();
    });
});

// =========================
// HEALTH AND ROOT
// =========================

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'healthy', service: 'api-gateway' });
});

app.get('/', (req, res) => {
    res.status(200).json({ 
        message: 'API Gateway Running',
        endpoints: [
            'POST /api/orders - Create order',
            'GET /api/products - List products',
            'POST /api/products/:id/image - Upload image'
        ]
    });
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`✅ API Gateway running on port ${PORT}`);
});