-- PostgreSQL database schema and sample data (Target)
-- =====================================================================
-- CREATE DATABASE
-- =====================================================================
-- CREATE DATABASE purchase_t;

-- In psql run:
-- \c purchase_t

-- =====================================================================
-- CREATE SCHEMA
-- =====================================================================
CREATE SCHEMA purchase AUTHORIZATION CURRENT_USER;
SET search_path TO purchase;

-- =====================================================================
-- TABLE: Clients
-- =====================================================================
CREATE TABLE clients (
    client_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_name    VARCHAR(200) NOT NULL,
    contact_email  VARCHAR(200),
    phone          VARCHAR(50),
    address        TEXT,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE clients ADD CONSTRAINT chk_clients_phone 
    CHECK (phone IS NULL OR phone ~ '^\+?[0-9\-\(\)\s]+$');

-- =====================================================================
-- TABLE: Suppliers
-- =====================================================================
CREATE TABLE suppliers (
    supplier_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name  VARCHAR(200) NOT NULL,
    contact_email  VARCHAR(200),
    phone          VARCHAR(50),
    address        TEXT,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================
-- TABLE: Products
-- =====================================================================
CREATE TABLE products (
    product_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name   VARCHAR(200) NOT NULL,
    sku            VARCHAR(100),
    unit_price     DECIMAL(12,2) NOT NULL,
    description    TEXT,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================================
-- TABLE: Purchase Orders
-- =====================================================================
CREATE TABLE purchase_orders (
    po_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id    BIGINT NOT NULL,
    client_id      BIGINT NOT NULL,
    po_date        DATE NOT NULL,
    status         VARCHAR(50) NOT NULL DEFAULT 'Created',
    total_amount   DECIMAL(12,2),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_po_supplier
        FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),

    CONSTRAINT fk_po_client
        FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

ALTER TABLE purchase_orders ADD CONSTRAINT chk_purchase_orders_is_active 
    CHECK (is_active IN ('t', 'f'));

-- =====================================================================
-- TABLE: Purchase Order Items
-- =====================================================================
CREATE TABLE purchase_order_items (
    poi_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    po_id          BIGINT NOT NULL,
    product_id     BIGINT NOT NULL,
    quantity       DECIMAL(12,3) NOT NULL,
    unit_price     DECIMAL(12,2) NOT NULL,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_poi_po
        FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_poi_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- =====================================================================
-- INSERT SAMPLE DATA
-- =====================================================================

-- Clients
INSERT INTO clients (client_name, contact_email, phone, address, created_at) VALUES
('Acme Retail Group', 'contact@acmeretail.com',   '+1-202-555-0145', '100 Market Street, NY',       '2026-04-21 16:34:12.849'),
('Delta Wholesale'  , 'info@delta-wholesale.com', '+1-202-555-0170', '55 Industrial Road, Chicago', '2026-04-21 16:34:12.849'),
('Sunrise Stores'   , 'hello@sunrisestores.com',  '+1-202-555-0134', '210 Lakeview Ave, Miami',     '2026-04-21 16:34:12.849');


-- Suppliers
INSERT INTO suppliers (supplier_name, contact_email, phone, address, created_at) VALUES
('Global Supply Co.',   'sales@globalsupply.com', '+1-202-555-0101', '500 Commerce Blvd, Boston',   '2026-04-21 16:34:12.849'),
('TechParts Ltd',       'office@techparts.co',    '+1-202-555-0112', '19 Technology Park, Seattle', '2026-04-21 16:34:12.849'),
('GreenLeaf Packaging', 'service@greenleaf.com',  '+1-202-555-0155', '78 Eco Drive, Portland',      '2026-04-21 16:34:12.849');

-- Products
INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('USB-C Cable 1m',    'CAB-USB-1M',  5.99, 'Standard USB-C charging cable', '2026-04-21 16:34:12.849'),
('27-inch Monitor',   'MON-27-4K', 249.99, '4K UHD professional display',   '2026-04-21 16:34:12.849'),
('Packing Box Small', 'BOX-SM-01',   0.49, 'Small cardboard box',           '2026-04-21 16:34:12.849'),
('Wireless Mouse',    'MOU-WL-02',  24.50, 'Ergonomic wireless mouse',      '2026-04-21 16:34:12.849'),
('Ethernet Cable 5m', 'CAB-ETH-5M',  8.20, 'CAT6 Ethernet cable',           '2026-04-21 16:34:12.849');

-- =====================================================================
-- INSERT 30 PURCHASE ORDERS
-- =====================================================================

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at) VALUES
(1, 1, '2026-04-01', 'Pending',    500.00, 't', '2026-04-21 16:34:12.849'),
(2, 2, '2026-04-02', 'Approved',   820.00, 't', '2026-04-21 16:34:12.849'),
(1, 3, '2026-04-03', 'Delivered', 1550.00, 'f', '2026-04-21 16:34:12.849'),
(3, 1, '2026-04-04', 'Pending',    230.00, 't', '2026-04-21 16:34:12.849'),
(2, 1, '2026-04-05', 'Delivered',  920.00, 'f', '2026-04-21 16:34:12.849'),
(1, 2, '2026-04-06', 'Approved',  1340.00, 't', '2026-04-21 16:34:12.849'),
(3, 3, '2026-04-07', 'Pending',    120.00, 't', '2026-04-21 16:34:12.849'),
(2, 3, '2026-04-08', 'Cancelled',    0.00, 'f', '2026-04-21 16:34:12.849'),
(1, 1, '2026-04-09', 'Pending',    640.00, 't', '2026-04-21 16:34:12.849'),
(3, 2, '2026-04-10', 'Delivered',  310.00, 'f', '2026-04-21 16:34:12.849'),
(1, 3, '2026-04-11', 'Approved',  2550.00, 't', '2026-04-21 16:34:12.849'),
(2, 1, '2026-04-12', 'Delivered',  780.00, 'f', '2026-04-21 16:34:12.849'),
(3, 2, '2026-04-13', 'Pending',     95.00, 't', '2026-04-21 16:34:12.849'),
(1, 2, '2026-04-14', 'Pending',   1425.00, 't', '2026-04-21 16:34:12.849'),
(2, 3, '2026-04-15', 'Delivered',  360.00, 'f', '2026-04-21 16:34:12.849'),
(3, 1, '2026-04-16', 'Approved',  1080.00, 't', '2026-04-21 16:34:12.849'),
(1, 1, '2026-04-17', 'Delivered', 1670.00, 'f', '2026-04-21 16:34:12.849'),
(2, 2, '2026-04-18', 'Pending',    240.00, 't', '2026-04-21 16:34:12.849'),
(3, 3, '2026-04-19', 'Approved',   560.00, 't', '2026-04-21 16:34:12.849'),
(1, 2, '2026-04-20', 'Delivered',  400.00, 'f', '2026-04-21 16:34:12.849'),
(2, 1, '2026-04-21', 'Pending',    890.00, 't', '2026-04-21 16:34:12.849'),
(3, 2, '2026-04-22', 'Delivered',  150.00, 'f', '2026-04-21 16:34:12.849'),
(1, 3, '2026-04-23', 'Approved',  2250.00, 't', '2026-04-21 16:34:12.849'),
(2, 3, '2026-04-24', 'Approved',   330.00, 't', '2026-04-21 16:34:12.849'),
(3, 1, '2026-04-25', 'Delivered',  190.00, 'f', '2026-04-21 16:34:12.849'),
(1, 2, '2026-04-26', 'Pending',   1320.00, 't', '2026-04-21 16:34:12.849'),
(2, 1, '2026-04-27', 'Pending',    870.00, 't', '2026-04-21 16:34:12.849'),
(3, 3, '2026-04-28', 'Delivered',  260.00, 'f', '2026-04-21 16:34:12.849'),
(1, 1, '2026-04-29', 'Approved',  1560.00, 't', '2026-04-21 16:34:12.849'),
(2, 2, '2026-04-30', 'Delivered',  480.00, 'f', '2026-04-21 16:34:12.849');


-- =====================================================================
-- INSERT PURCHASE ORDER ITEMS (aligned to PO IDs 1–30)
-- =====================================================================

-- PO 1
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (1,1,50,5.99,'2026-04-21 16:34:12.849'), (1,5,20,8.20,'2026-04-21 16:34:12.849');

-- PO 2
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (2,2,3,249.99,'2026-04-21 16:34:12.849'), (2,4,10,24.50,'2026-04-21 16:34:12.849');

-- PO 3
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (3,2,5,249.99,'2026-04-21 16:34:12.849'), (3,1,200,5.99,'2026-04-21 16:34:12.849');

-- PO 4
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (4,3,400,0.49,'2026-04-21 16:34:12.849');

-- PO 5
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (5,4,20,24.50,'2026-04-21 16:34:12.849'), (5,1,50,5.99,'2026-04-21 16:34:12.849');

-- PO 6
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (6,2,4,249.99,'2026-04-21 16:34:12.849'), (6,5,30,8.20,'2026-04-21 16:34:12.849'), (6,1,100,5.99,'2026-04-21 16:34:12.849');

-- PO 7
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (7,3,100,0.49,'2026-04-21 16:34:12.849'), (7,4,2,24.50,'2026-04-21 16:34:12.849');

-- PO 8
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (8,1,1,5.99,'2026-04-21 16:34:12.849');

-- PO 9
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (9,5,40,8.20,'2026-04-21 16:34:12.849'), (9,3,50,0.49,'2026-04-21 16:34:12.849');

-- PO 10
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (10,2,1,249.99,'2026-04-21 16:34:12.849');

-- PO 11
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (11,2,10,249.99,'2026-04-21 16:34:12.849'), (11,1,100,5.99,'2026-04-21 16:34:12.849'), (11,4,5,24.50,'2026-04-21 16:34:12.849');

-- PO 12
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (12,4,20,24.50,'2026-04-21 16:34:12.849'), (12,3,100,0.49,'2026-04-21 16:34:12.849');

-- PO 13
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (13,3,50,0.49,'2026-04-21 16:34:12.849'), (13,1,5,5.99,'2026-04-21 16:34:12.849');

-- PO 14
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (14,2,4,249.99,'2026-04-21 16:34:12.849'), (14,5,75,8.20,'2026-04-21 16:34:12.849');

-- PO 15
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (15,4,10,24.50,'2026-04-21 16:34:12.849');

-- PO 16
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (16,2,4,249.99,'2026-04-21 16:34:12.849');

-- PO 17
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (17,2,5,249.99,'2026-04-21 16:34:12.849'), (17,1,200,5.99,'2026-04-21 16:34:12.849');

-- PO 18
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (18,3,200,0.49,'2026-04-21 16:34:12.849'), (18,1,20,5.99,'2026-04-21 16:34:12.849');

-- PO 19
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (19,5,50,8.20,'2026-04-21 16:34:12.849');

-- PO 20
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (20,1,20,5.99,'2026-04-21 16:34:12.849'), (20,5,10,8.20,'2026-04-21 16:34:12.849');

-- PO 21
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (21,4,8,24.50,'2026-04-21 16:34:12.849'), (21,3,150,0.49,'2026-04-21 16:34:12.849');

-- PO 22
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (22,1,10,5.99,'2026-04-21 16:34:12.849');

-- PO 23
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (23,2,8,249.99,'2026-04-21 16:34:12.849'), (23,1,120,5.99,'2026-04-21 16:34:12.849');

-- PO 24
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (24,4,6,24.50,'2026-04-21 16:34:12.849');

-- PO 25
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (25,3,300,0.49,'2026-04-21 16:34:12.849');

-- PO 26
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (26,5,100,8.20,'2026-04-21 16:34:12.849'), (26,1,50,5.99,'2026-04-21 16:34:12.849');

-- PO 27
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (27,4,20,24.50,'2026-04-21 16:34:12.849'), (27,3,50,0.49,'2026-04-21 16:34:12.849');

-- PO 28
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (28,1,30,5.99,'2026-04-21 16:34:12.849');

-- PO 29
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (29,2,6,249.99,'2026-04-21 16:34:12.849');

-- PO 30
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at) 
VALUES (30,5,30,8.20,'2026-04-21 16:34:12.849'), (30,3,20,0.49,'2026-04-21 16:34:12.849');