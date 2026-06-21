-- This script creates the necessary tables to store validation results for various checks 
-- performed during database migration assessment. 
-- Each table corresponds to a specific validation check.

-- Create schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '<schema_name>')
BEGIN
    EXEC('CREATE SCHEMA <schema_name>');
END;
/
