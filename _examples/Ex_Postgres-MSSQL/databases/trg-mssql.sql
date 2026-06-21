/* =========================================================
   DATABASE
   ========================================================= */
IF DB_ID('purchase') IS NULL
    CREATE DATABASE purchase;
GO

USE purchase;
GO

/* =========================================================
   TABLES (dbo ONLY)
   ========================================================= */

-- CLIENTS
CREATE TABLE dbo.clients (
    client_id     BIGINT IDENTITY(1,1) NOT NULL,
    client_name   NVARCHAR(200) NOT NULL,
    contact_email NVARCHAR(200),
    phone         NVARCHAR(50),
    address       NVARCHAR(MAX),
    created_at    DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_clients PRIMARY KEY CLUSTERED (client_id)
);
GO

ALTER TABLE dbo.clients
ADD CONSTRAINT chk_clients_phone
CHECK (
    phone IS NULL
    OR
    LTRIM(RTRIM(
        TRANSLATE(
            phone,
            '+0123456789-() ',
            '               ' -- ТОЧНО столько же пробелов
        )
    )) = ''
);
GO

-- SUPPLIERS
CREATE TABLE dbo.suppliers (
    supplier_id   BIGINT IDENTITY(1,1) NOT NULL,
    supplier_name NVARCHAR(200) NOT NULL,
    contact_email NVARCHAR(200),
    phone         NVARCHAR(50),
    address       NVARCHAR(MAX),
    created_at    DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_suppliers PRIMARY KEY CLUSTERED (supplier_id)
);
GO

-- PRODUCTS
CREATE TABLE dbo.products (
    product_id   BIGINT IDENTITY(1,1) NOT NULL,
    product_name NVARCHAR(200) NOT NULL,
    sku          NVARCHAR(100) NOT NULL,
    unit_price   DECIMAL(12,2) NOT NULL,
    description  NVARCHAR(MAX),
    created_at   DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_products PRIMARY KEY CLUSTERED (product_id)
);
GO

-- PURCHASE ORDERS
CREATE TABLE dbo.purchase_orders (
    po_id        BIGINT IDENTITY(1,1) NOT NULL,
    supplier_id  BIGINT NOT NULL,
    client_id    BIGINT NOT NULL,
    po_date      DATE NOT NULL,
    status       NVARCHAR(50) NOT NULL DEFAULT 'Created',
    total_amount DECIMAL(12,2),
    is_active    CHAR(1) NOT NULL DEFAULT 'Y',
    created_at   DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT pk_purchase_orders PRIMARY KEY CLUSTERED (po_id),
    CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id)
        REFERENCES dbo.suppliers(supplier_id),
    CONSTRAINT fk_po_client FOREIGN KEY (client_id)
        REFERENCES dbo.clients(client_id),
    CONSTRAINT chk_po_is_active CHECK (is_active IN ('Y','N'))
);
GO

-- PURCHASE ORDER ITEMS
CREATE TABLE dbo.purchase_order_items (
    poi_id     BIGINT IDENTITY(1,1) NOT NULL,
    po_id      BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity   DECIMAL(12,3) NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT pk_purchase_order_items PRIMARY KEY CLUSTERED (poi_id),
    CONSTRAINT fk_poi_po FOREIGN KEY (po_id)
        REFERENCES dbo.purchase_orders(po_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_poi_product FOREIGN KEY (product_id)
        REFERENCES dbo.products(product_id)
);
GO

/* =========================================================
   INDEXES (FK PARITY)
   ========================================================= */
CREATE NONCLUSTERED INDEX ix_po_supplier
ON dbo.purchase_orders (supplier_id);

CREATE NONCLUSTERED INDEX ix_po_client
ON dbo.purchase_orders (client_id);

CREATE NONCLUSTERED INDEX ix_poi_po
ON dbo.purchase_order_items (po_id);

CREATE NONCLUSTERED INDEX ix_poi_product
ON dbo.purchase_order_items (product_id);
GO

/* =========================================================
   DATA
   ========================================================= */

-- CLIENTS
INSERT INTO dbo.clients VALUES
('Acme Retail Group','contact@acmeretail.com','+1-202-555-0145','100 Market Street, NY','2026-04-21 16:34:12.849'),
('Delta Wholesale','info@delta-wholesale.com','+1-202-555-0170','55 Industrial Road, Chicago','2026-04-21 16:34:12.849'),
('Sunrise Stores','hello@sunrisestores.com','+1-202-555-0134','210 Lakeview Ave, Miami','2026-04-21 16:34:12.849');
GO

-- SUPPLIERS
INSERT INTO dbo.suppliers VALUES
('Global Supply Co.','sales@globalsupply.com','+1-202-555-0101','500 Commerce Blvd, Boston','2026-04-21 16:34:12.849'),
('TechParts Ltd','office@techparts.co','+1-202-555-0112','19 Technology Park, Seattle','2026-04-21 16:34:12.849'),
('GreenLeaf Packaging','service@greenleaf.com','+1-202-555-0155','78 Eco Drive, Portland','2026-04-21 16:34:12.849');
GO

-- PRODUCTS
INSERT INTO dbo.products VALUES
('USB-C Cable 1m','CAB-USB-1M',5.99,'Standard USB-C charging cable','2026-04-21 16:34:12.849'),
('27-inch Monitor','MON-27-4K',249.99,'4K UHD professional display','2026-04-21 16:34:12.849'),
('Packing Box Small','BOX-SM-01',0.49,'Small cardboard box','2026-04-21 16:34:12.849'),
('Wireless Mouse','MOU-WL-02',24.50,'Ergonomic wireless mouse','2026-04-21 16:34:12.849'),
('Ethernet Cable 5m','CAB-ETH-5M',8.20,'CAT6 Ethernet cable','2026-04-21 16:34:12.849');
GO

-- PURCHASE ORDERS (30)
INSERT INTO dbo.purchase_orders VALUES
(1,1,'2026-04-01','Pending',500,'Y','2026-04-21 16:34:12.849'),
(2,2,'2026-04-02','Approved',820,'Y','2026-04-21 16:34:12.849'),
(1,3,'2026-04-03','Delivered',1550,'N','2026-04-21 16:34:12.849'),
(3,1,'2026-04-04','Pending',230,'Y','2026-04-21 16:34:12.849'),
(2,1,'2026-04-05','Delivered',920,'N','2026-04-21 16:34:12.849'),
(1,2,'2026-04-06','Approved',1340,'Y','2026-04-21 16:34:12.849'),
(3,3,'2026-04-07','Pending',120,'Y','2026-04-21 16:34:12.849'),
(2,3,'2026-04-08','Cancelled',0,'N','2026-04-21 16:34:12.849'),
(1,1,'2026-04-09','Pending',640,'Y','2026-04-21 16:34:12.849'),
(3,2,'2026-04-10','Delivered',310,'N','2026-04-21 16:34:12.849'),
(1,3,'2026-04-11','Approved',2550,'Y','2026-04-21 16:34:12.849'),
(2,1,'2026-04-12','Delivered',780,'N','2026-04-21 16:34:12.849'),
(3,2,'2026-04-13','Pending',95,'Y','2026-04-21 16:34:12.849'),
(1,2,'2026-04-14','Pending',1425,'Y','2026-04-21 16:34:12.849'),
(2,3,'2026-04-15','Delivered',360,'N','2026-04-21 16:34:12.849'),
(3,1,'2026-04-16','Approved',1080,'Y','2026-04-21 16:34:12.849'),
(1,1,'2026-04-17','Delivered',1670,'N','2026-04-21 16:34:12.849'),
(2,2,'2026-04-18','Pending',240,'Y','2026-04-21 16:34:12.849'),
(3,3,'2026-04-19','Approved',560,'Y','2026-04-21 16:34:12.849'),
(1,2,'2026-04-20','Delivered',400,'N','2026-04-21 16:34:12.849'),
(2,1,'2026-04-21','Pending',890,'Y','2026-04-21 16:34:12.849'),
(3,2,'2026-04-22','Delivered',150,'N','2026-04-21 16:34:12.849'),
(1,3,'2026-04-23','Approved',2250,'Y','2026-04-21 16:34:12.849'),
(2,3,'2026-04-24','Approved',330,'Y','2026-04-21 16:34:12.849'),
(3,1,'2026-04-25','Delivered',190,'N','2026-04-21 16:34:12.849'),
(1,2,'2026-04-26','Pending',1320,'Y','2026-04-21 16:34:12.849'),
(2,1,'2026-04-27','Pending',870,'Y','2026-04-21 16:34:12.849'),
(3,3,'2026-04-28','Delivered',260,'N','2026-04-21 16:34:12.849'),
(1,1,'2026-04-29','Approved',1560,'Y','2026-04-21 16:34:12.849'),
(2,2,'2026-04-30','Delivered',480,'N','2026-04-21 16:34:12.849');
GO

-- PURCHASE ORDER ITEMS
INSERT INTO dbo.purchase_order_items VALUES
(1,1,50,5.99,'2026-04-21 16:34:12.849'),(1,5,20,8.20,'2026-04-21 16:34:12.849'),
(2,2,3,249.99,'2026-04-21 16:34:12.849'),(2,4,10,24.50,'2026-04-21 16:34:12.849'),
(3,2,5,249.99,'2026-04-21 16:34:12.849'),(3,1,200,5.99,'2026-04-21 16:34:12.849'),
(4,3,400,0.49,'2026-04-21 16:34:12.849'),
(5,4,20,24.50,'2026-04-21 16:34:12.849'),(5,1,50,5.99,'2026-04-21 16:34:12.849'),
(6,2,4,249.99,'2026-04-21 16:34:12.849'),(6,5,30,8.20,'2026-04-21 16:34:12.849'),(6,1,100,5.99,'2026-04-21 16:34:12.849'),
(7,3,100,0.49,'2026-04-21 16:34:12.849'),(7,4,2,24.50,'2026-04-21 16:34:12.849'),
(8,1,1,5.99,'2026-04-21 16:34:12.849'),
(9,5,40,8.20,'2026-04-21 16:34:12.849'),(9,3,50,0.49,'2026-04-21 16:34:12.849'),
(10,2,1,249.99,'2026-04-21 16:34:12.849'),
(11,2,10,249.99,'2026-04-21 16:34:12.849'),(11,1,100,5.99,'2026-04-21 16:34:12.849'),(11,4,5,24.50,'2026-04-21 16:34:12.849'),
(12,4,20,24.50,'2026-04-21 16:34:12.849'),(12,3,100,0.49,'2026-04-21 16:34:12.849'),
(13,3,50,0.49,'2026-04-21 16:34:12.849'),(13,1,5,5.99,'2026-04-21 16:34:12.849'),
(14,2,4,249.99,'2026-04-21 16:34:12.849'),(14,5,75,8.20,'2026-04-21 16:34:12.849'),
(15,4,10,24.50,'2026-04-21 16:34:12.849'),
(16,2,4,249.99,'2026-04-21 16:34:12.849'),
(17,2,5,249.99,'2026-04-21 16:34:12.849'),(17,1,200,5.99,'2026-04-21 16:34:12.849'),
(18,3,200,0.49,'2026-04-21 16:34:12.849'),(18,1,20,5.99,'2026-04-21 16:34:12.849'),
(19,5,50,8.20,'2026-04-21 16:34:12.849'),
(20,1,20,5.99,'2026-04-21 16:34:12.849'),(20,5,10,8.20,'2026-04-21 16:34:12.849'),
(21,4,8,24.50,'2026-04-21 16:34:12.849'),(21,3,150,0.49,'2026-04-21 16:34:12.849'),
(22,1,10,5.99,'2026-04-21 16:34:12.849'),
(23,2,8,249.99,'2026-04-21 16:34:12.849'),(23,1,120,5.99,'2026-04-21 16:34:12.849'),
(24,4,6,24.50,'2026-04-21 16:34:12.849'),
(25,3,300,0.49,'2026-04-21 16:34:12.849'),
(26,5,100,8.20,'2026-04-21 16:34:12.849'),(26,1,50,5.99,'2026-04-21 16:34:12.849'),
(27,4,20,24.50,'2026-04-21 16:34:12.849'),(27,3,50,0.49,'2026-04-21 16:34:12.849'),
(28,1,30,5.99,'2026-04-21 16:34:12.849'),
(29,2,6,249.99,'2026-04-21 16:34:12.849'),
(30,5,30,8.20,'2026-04-21 16:34:12.849'),(30,3,20,0.49,'2026-04-21 16:34:12.849');
GO