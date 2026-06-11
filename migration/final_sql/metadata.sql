-- This script creates the necessary tables to store metadata and cross-checking results 
-- for database migration assessment.
-- Each table corresponds to a specific aspect of the database metadata or cross-checking results.

-- Create schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '<schema_name>')
BEGIN
    EXEC('CREATE SCHEMA <schema_name>');
END;
/

-- Drop and recreate cross_checking table
DROP TABLE IF EXISTS <schema_name>.cross_checking;
CREATE TABLE <schema_name>.cross_checking (
    issue_code     NVARCHAR(MAX),
    issue_type     NVARCHAR(MAX),
    title          NVARCHAR(MAX),
    message        NVARCHAR(MAX),
    direction      NVARCHAR(MAX)
);

-- Drop and recreate metadata_01 table
DROP TABLE IF EXISTS <schema_name>.metadata_01;
CREATE TABLE <schema_name>.metadata_01 (
    schema_name     NVARCHAR(128),
    object_type     NVARCHAR(128),
    object_count    BIGINT
);

DROP TABLE IF EXISTS <schema_name>.metadata_02;
CREATE TABLE <schema_name>.metadata_02 (
    schema_name     NVARCHAR(128),
    table_name      NVARCHAR(256),
    orig_tabname    NVARCHAR(256),
    is_partitioned  NVARCHAR(3),
    has_identity    NVARCHAR(3)
);

DROP TABLE IF EXISTS <schema_name>.metadata_03;
CREATE TABLE <schema_name>.metadata_03 (
    schema_name     NVARCHAR(128),
    table_name      NVARCHAR(256),
    column_count    BIGINT
);
/