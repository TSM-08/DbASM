-- This script is used to clean up the database by dropping the schemas used for source and target metadata and validation results.
-- It ensures that any existing schemas and their contents are removed before a new assessment is performed.

-- Drop all objects in a schema dynamically
DECLARE @schema SYSNAME, @sql NVARCHAR(MAX);

-- Loop through the schemas you want to drop
DECLARE schema_cursor CURSOR FOR
    SELECT name FROM sys.schemas WHERE name IN ('src','trg');

OPEN schema_cursor;
FETCH NEXT FROM schema_cursor INTO @schema;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'';

    -- Drop tables
    SELECT @sql += 'DROP TABLE ' + QUOTENAME(@schema) + '.' + QUOTENAME(t.name) + ';'
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = @schema;

    -- Drop views
    SELECT @sql += 'DROP VIEW ' + QUOTENAME(@schema) + '.' + QUOTENAME(v.name) + ';'
    FROM sys.views v
    JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE s.name = @schema;

    -- Drop procedures
    SELECT @sql += 'DROP PROCEDURE ' + QUOTENAME(@schema) + '.' + QUOTENAME(p.name) + ';'
    FROM sys.procedures p
    JOIN sys.schemas s ON p.schema_id = s.schema_id
    WHERE s.name = @schema;

    -- Drop functions
    SELECT @sql += 'DROP FUNCTION ' + QUOTENAME(@schema) + '.' + QUOTENAME(o.name) + ';'
    FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = @schema AND o.type IN ('FN','IF','TF');

    -- Drop sequences
    SELECT @sql += 'DROP SEQUENCE ' + QUOTENAME(@schema) + '.' + QUOTENAME(seq.name) + ';'
    FROM sys.sequences seq
    JOIN sys.schemas s ON seq.schema_id = s.schema_id
    WHERE s.name = @schema;

    -- Execute all drops
    IF LEN(@sql) > 0
        EXEC sp_executesql @sql;

    -- Finally drop the schema itself
    SET @sql = 'DROP SCHEMA ' + QUOTENAME(@schema) + ';';
    EXEC sp_executesql @sql;

    FETCH NEXT FROM schema_cursor INTO @schema;
END

CLOSE schema_cursor;
DEALLOCATE schema_cursor;
/