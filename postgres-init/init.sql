-- This script runs automatically when the PostgreSQL container first starts.
-- It creates the two databases needed by order-service and inventory-service.

CREATE DATABASE orders;
CREATE DATABASE inventory;
