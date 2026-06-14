# E-Commerce Microservices Platform

This exercise is designed for **local deployment only**

## What is this?
A 6-service e-commerce application for learning DevOps.

**Services:**
1. API Gateway (Node.js)
2. Product Service (Python)
3. Order Service (Node.js)
4. Payment Service (Go)
5. Inventory Service (Python)
6. Email Service (Ruby)

**Databases:**
- PostgreSQL
- MongoDB
- Redis
- RabbitMQ

---

Here is the complete list of DNS names with external/internal classification.

---

## External Access (Exposed via Load Balancer)

| Service     | DNS Name                | Port |
| ----------- | ----------------------- | ---- |
| Admin UI    | ui.devops.local         | 80   |
| API Gateway | api.devops.local        | 80   |
| Grafana     | monitoring.devops.local | 80   |

---

## Internal Access (Not Exposed Externally)

| Service                | DNS Name                   | Port  |
| ---------------------- | -------------------------- | ----- |
| API Gateway (internal) | api-gateway.internal       | 3000  |
| Product Service        | product-service.internal   | 3001  |
| Order Service          | order-service.internal     | 3002  |
| Payment Service        | payment-service.internal   | 3003  |
| Inventory Service      | inventory-service.internal | 3004  |
| Email Service          | email-service.internal     | 3005  |
| PostgreSQL             | postgres.internal          | 5432  |
| MongoDB                | mongodb.internal           | 27017 |
| Redis                  | redis.internal             | 6379  |
| RabbitMQ               | rabbitmq.internal          | 5672  |
| Prometheus             | prometheus.internal        | 9090  |
| Jaeger                 | jaeger.internal            | 16686 |
| Loki                   | loki.internal              | 3100  |

---

## Summary

| Type | Count | DNS Pattern |
|------|-------|-------------|
| External (via Load Balancer) | 3 | *.devops.local |
| Internal (service to service) | 13 | *.internal |
| **Total** | **16** | |

---


**Note:** Only Admin UI, API Gateway, and Grafana are exposed externally via Load Balancer. All other services, databases, and monitoring tools remain internal with *.internal DNS names. The API Gateway has both an external DNS (api.devops.local) for external routing and an internal DNS (api-gateway.internal) for service-to-service communication.

---

## What Must Be Done

**1. Setup Networking**
- Create 3 isolated networks (Load Balancer, Applications, Databases)
- Applications can talk to Databases
- Host can ONLY reach Load Balancer

**2. Load Balancer**
- One Load Balancer (NGINX/HAProxy) as only entry point
- Routes: ui.devops.local → Admin UI
- Routes: api.devops.local → API Gateway
- Routes: monitoring.devops.local → Grafana

**3. Data Persistence**
- Data must survive restart (your choice how)

**4. CI/CD**
- One repository per service (6 repos)
- Stage pipeline: auto-deploy on stage branch
- Prod pipeline: manual approval on main branch

**5. Final Deployment**
- Deploy to K3s or Minikube
- All services in Kubernetes
- Ingress as Load Balancer

**6. Monitoring**
- Prometheus + Grafana
- Monitor: Service up/down
- Monitor: APM traces (Jaeger) across all 6 services when order placed
- Access Grafana via Load Balancer

**7. Logging**
- Loki + Promtail
- Centralized logs from all services
- Alert on ERROR logs

---

## DNS Names

| DNS Name | Points to | Access |
|----------|-----------|--------|
| ui.devops.local | Admin UI | External via LB |
| api.devops.local | API Gateway | External via LB |
| monitoring.devops.local | Grafana | External via LB |
| api-gateway.internal | API Gateway | Internal only |
| product-service.internal | Product Service | Internal only |
| order-service.internal | Order Service | Internal only |
| payment-service.internal | Payment Service | Internal only |
| inventory-service.internal | Inventory Service | Internal only |
| email-service.internal | Email Service | Internal only |
| postgres.internal | PostgreSQL | Internal only |
| mongodb.internal | MongoDB | Internal only |
| redis.internal | Redis | Internal only |
| rabbitmq.internal | RabbitMQ | Internal only |
| prometheus.internal | Prometheus | Internal only |
| jaeger.internal | Jaeger | Internal only |
| loki.internal | Loki | Internal only |

---

## Deliverables

1. 6 GitHub repositories with CI/CD pipelines
2. Deployed application on K3s/Minikube
3. host cannot access services directly
4.  Load Balancer is the only entry point
5. Grafana dashboard showing service health and Alerts
6. Jaeger trace showing order flow across 6 services
7. Loki showing logs and ERROR alert


# Phase 2: Scaling & Disaster Recovery

After successful deployment, the next phase focuses on **scaling the application** and **implementing disaster recovery**.