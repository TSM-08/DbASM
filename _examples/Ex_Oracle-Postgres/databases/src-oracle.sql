-- Oracle database schema and sample data (Source)
-- =====================================================================
-- CREATE USER/SCHEMA (optional, adjust username/password as needed)
-- =====================================================================
CREATE USER PURCHASE IDENTIFIED BY purchase_s DEFAULT TABLESPACE USERS TEMPORARY TABLESPACE TEMP;
GRANT CONNECT, RESOURCE TO PURCHASE;
ALTER USER PURCHASE QUOTA UNLIMITED ON USERS;

-- Connect as PURCHASE
-- ALTER SESSION SET CURRENT_SCHEMA=PURCHASE;

DROP TABLE purchase_order_items CASCADE CONSTRAINTS;
DROP TABLE purchase_orders CASCADE CONSTRAINTS;
DROP TABLE products CASCADE CONSTRAINTS;
DROP TABLE suppliers CASCADE CONSTRAINTS;
DROP TABLE clients CASCADE CONSTRAINTS;

-- =====================================================================
-- TABLE: Clients
-- =====================================================================
CREATE TABLE clients (
		client_id      NUMBER(19) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		client_name    VARCHAR2(200) NOT NULL,
		contact_email  VARCHAR2(200),
		phone          VARCHAR2(50),
		address        CLOB,
		created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

ALTER TABLE clients ADD CONSTRAINT chk_clients_phone 
CHECK (phone IS NULL OR REGEXP_LIKE(phone, '^\+?[0-9()\s-]+$'));


-- =====================================================================
-- TABLE: Suppliers
-- =====================================================================
CREATE TABLE suppliers (
		supplier_id    NUMBER(19) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		supplier_name  VARCHAR2(200) NOT NULL,
		contact_email  VARCHAR2(200),
		phone          VARCHAR2(50),
		address        CLOB,
		created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);



-- =====================================================================
-- TABLE: Products
-- =====================================================================
CREATE TABLE products (
		product_id     NUMBER(19) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		product_name   VARCHAR2(200) NOT NULL,
		sku            VARCHAR2(100) NOT NULL,
		unit_price     NUMBER(12,2) NOT NULL,
		description    CLOB,
		created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);



-- =====================================================================
-- TABLE: Purchase Orders
-- =====================================================================
CREATE TABLE purchase_orders (
		po_id          NUMBER(19) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		supplier_id    NUMBER(19) NOT NULL,
		client_id      NUMBER(19) NOT NULL,
		po_date        DATE NOT NULL,
		status         VARCHAR2(50) DEFAULT 'Created' NOT NULL,
		total_amount   NUMBER(12,2),
		is_active      CHAR(1) DEFAULT 'Y' NOT NULL,
		created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
		CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
		CONSTRAINT fk_po_client FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

ALTER TABLE purchase_orders ADD CONSTRAINT chk_purchase_orders_is_active 
		CHECK (is_active IN ('Y', 'N'));



-- =====================================================================
-- TABLE: Purchase Order Items
-- =====================================================================
CREATE TABLE purchase_order_items (
		poi_id         NUMBER(19) GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		po_id          NUMBER(19) NOT NULL,
		product_id     NUMBER(19) NOT NULL,
		quantity       NUMBER(12,3) NOT NULL,
		unit_price     NUMBER(12,2) NOT NULL,
		created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
		CONSTRAINT fk_poi_po FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id) ON DELETE CASCADE,
		CONSTRAINT fk_poi_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);



-- =====================================================================
-- INSERT SAMPLE DATA
-- =====================================================================
-- Clients

INSERT INTO clients (client_name, contact_email, phone, address, created_at) VALUES
('Acme Retail Group', 'contact@acmeretail.com',   '+1-202-555-0145', '100 Market Street, NY',       TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO clients (client_name, contact_email, phone, address, created_at) VALUES
('Delta Wholesale', 'info@delta-wholesale.com', '+1-202-555-0170', '55 Industrial Road, Chicago', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO clients (client_name, contact_email, phone, address, created_at) VALUES
('Sunrise Stores', 'hello@sunrisestores.com', '+1-202-555-0134', '210 Lakeview Ave, Miami', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));

-- Suppliers

INSERT INTO suppliers (supplier_name, contact_email, phone, address, created_at) VALUES
('Global Supply Co.', 'sales@globalsupply.com', '+1-202-555-0101', '500 Commerce Blvd, Boston', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO suppliers (supplier_name, contact_email, phone, address, created_at) VALUES
('TechParts Ltd', 'office@techparts.co', '+1-202-555-0112', '19 Technology Park, Seattle', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO suppliers (supplier_name, contact_email, phone, address, created_at) VALUES
('GreenLeaf Packaging', 'service@greenleaf.com', '+1-202-555-0155', '78 Eco Drive, Portland', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));

-- Products

INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('USB-C Cable 1m', 'CAB-USB-1M', 5.99, 'Standard USB-C charging cable', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('27-inch Monitor', 'MON-27-4K', 249.99, '4K UHD professional display', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('Packing Box Small', 'BOX-SM-01', 0.49, 'Small cardboard box', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('Wireless Mouse', 'MOU-WL-02', 24.50, 'Ergonomic wireless mouse', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO products (product_name, sku, unit_price, description, created_at) VALUES
('Ethernet Cable 5m', 'CAB-ETH-5M', 8.20, 'CAT6 Ethernet cable', TO_TIMESTAMP('2026-04-21 16:34:12.849', 'YYYY-MM-DD HH24:MI:SS.FF3'));


-- =====================================================================
-- INSERT 30 PURCHASE ORDERS 
-- =====================================================================
-- truncate table purchase_orders;

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 1, TO_DATE('2026-04-01','YYYY-MM-DD'), 'Pending',    500.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 2, TO_DATE('2026-04-02','YYYY-MM-DD'), 'Approved',   820.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 3, TO_DATE('2026-04-03','YYYY-MM-DD'), 'Delivered', 1550.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 1, TO_DATE('2026-04-04','YYYY-MM-DD'), 'Pending',    230.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 1, TO_DATE('2026-04-05','YYYY-MM-DD'), 'Delivered',  920.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 2, TO_DATE('2026-04-06','YYYY-MM-DD'), 'Approved',  1340.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 3, TO_DATE('2026-04-07','YYYY-MM-DD'), 'Pending',    120.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 3, TO_DATE('2026-04-08','YYYY-MM-DD'), 'Cancelled',    0.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 1, TO_DATE('2026-04-09','YYYY-MM-DD'), 'Pending',    640.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 2, TO_DATE('2026-04-10','YYYY-MM-DD'), 'Delivered',  310.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 3, TO_DATE('2026-04-11','YYYY-MM-DD'), 'Approved',  2550.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 1, TO_DATE('2026-04-12','YYYY-MM-DD'), 'Delivered',  780.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 2, TO_DATE('2026-04-13','YYYY-MM-DD'), 'Pending',     95.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 2, TO_DATE('2026-04-14','YYYY-MM-DD'), 'Pending',   1425.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 3, TO_DATE('2026-04-15','YYYY-MM-DD'), 'Delivered',  360.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 1, TO_DATE('2026-04-16','YYYY-MM-DD'), 'Approved',  1080.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 1, TO_DATE('2026-04-17','YYYY-MM-DD'), 'Delivered', 1670.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 2, TO_DATE('2026-04-18','YYYY-MM-DD'), 'Pending',    240.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 3, TO_DATE('2026-04-19','YYYY-MM-DD'), 'Approved',   560.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 2, TO_DATE('2026-04-20','YYYY-MM-DD'), 'Delivered',  400.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 1, TO_DATE('2026-04-21','YYYY-MM-DD'), 'Pending',    890.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 2, TO_DATE('2026-04-22','YYYY-MM-DD'), 'Delivered',  150.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 3, TO_DATE('2026-04-23','YYYY-MM-DD'), 'Approved',  2250.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 3, TO_DATE('2026-04-24','YYYY-MM-DD'), 'Approved',   330.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 1, TO_DATE('2026-04-25','YYYY-MM-DD'), 'Delivered',  190.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 2, TO_DATE('2026-04-26','YYYY-MM-DD'), 'Pending',   1320.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 1, TO_DATE('2026-04-27','YYYY-MM-DD'), 'Pending',    870.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (3, 3, TO_DATE('2026-04-28','YYYY-MM-DD'), 'Delivered',  260.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (1, 1, TO_DATE('2026-04-29','YYYY-MM-DD'), 'Approved',  1560.00, 'Y', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_orders (supplier_id, client_id, po_date, status, total_amount, is_active, created_at)
VALUES (2, 2, TO_DATE('2026-04-30','YYYY-MM-DD'), 'Delivered',  480.00, 'N', TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));


-- =====================================================================
-- PURCHASE_ORDER_ITEMS 
-- =====================================================================

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (1,1,50,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (1,5,20,8.20,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (2,2,3,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (2,4,10,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (3,2,5,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (3,1,200,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (4,3,400,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (5,4,20,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (5,1,50,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (6,2,4,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (6,5,30,8.20,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (6,1,100,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (7,3,100,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (7,4,2,24.50,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (8,1,1,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (9,5,40,8.20, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (9,3,50,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (10,2,1,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (11,2,10,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (11,1,100,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (11,4,5,24.50,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (12,4,20,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (12,3,100,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (13,3,50,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (13,1,5,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (14,2,4,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (14,5,75,8.20,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (15,4,10,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (16,2,4,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (17,2,5,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (17,1,200,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (18,3,200,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (18,1,20,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (19,5,50,8.20, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (20,1,20,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (20,5,10,8.20, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (21,4,8,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (21,3,150,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (22,1,10,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (23,2,8,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (23,1,120,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (24,4,6,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (25,3,300,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (26,5,100,8.20, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (26,1,50,5.99,  TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (27,4,20,24.50, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (27,3,50,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (28,1,30,5.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (29,2,6,249.99, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (30,5,30,8.20, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));
INSERT INTO purchase_order_items (po_id, product_id, quantity, unit_price, created_at)
VALUES (30,3,20,0.49, TO_TIMESTAMP('2026-04-21 16:34:12.849','YYYY-MM-DD HH24:MI:SS.FF3'));

COMMIT;
