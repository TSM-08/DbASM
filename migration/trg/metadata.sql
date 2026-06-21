-- Count major object types in the current schema (tables, sequences, columns, PKs, FKs, indexes).
-- Data will be stored in trg/metadata_01.csv (table trg.metadata_01).
--%01S
WITH objects AS (
    -- tables
    SELECT 'tables' AS object_type,
           t.name AS object_name,
           s.name AS object_owner
      FROM sys.tables t
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE s.name = 'dbo'
    UNION ALL
    -- views
    SELECT 'views',
           v.name,
           s.name
      FROM sys.views v
      JOIN sys.schemas s ON v.schema_id = s.schema_id
     WHERE s.name = 'dbo'
    UNION ALL
/* 
    -- sequences
    SELECT 'sequences',
           seq.name,
           s.name
      FROM sys.sequences seq
      JOIN sys.schemas s ON seq.schema_id = s.schema_id
     WHERE s.name = 'dbo'

    UNION ALL
*/
    -- primary key constraints
    SELECT 'pkeys_constraints',
           kc.name,
           s.name
      FROM sys.key_constraints kc
      JOIN sys.tables t ON kc.parent_object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE kc.type = 'PK'
       AND s.name = 'dbo'
    UNION ALL
    -- foreign key constraints
    SELECT 'fkeys_constraints',
           fk.name,
           s.name
      FROM sys.foreign_keys fk
      JOIN sys.tables t ON fk.parent_object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE s.name = 'dbo'
    UNION ALL
    -- check constraints
    SELECT 'check_constraints',
           cc.name,
           s.name
      FROM sys.check_constraints cc
      JOIN sys.tables t ON cc.parent_object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE s.name = 'dbo'
    UNION ALL
    -- unique constraints
    SELECT 'unique_constraints',
           kc.name,
           s.name
      FROM sys.key_constraints kc
      JOIN sys.tables t ON kc.parent_object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE kc.type = 'UQ'
       AND s.name = 'dbo'
    UNION ALL
    -- triggers
    SELECT 'triggers',
           tr.name,
           s.name
      FROM sys.triggers tr
      JOIN sys.tables t ON tr.parent_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE tr.parent_class_desc = 'OBJECT_OR_COLUMN'
       AND s.name = 'dbo'
    UNION ALL
    -- indexes
    SELECT 'indexes',
           i.name,
           s.name
      FROM sys.indexes i
      JOIN sys.tables t ON i.object_id = t.object_id
      JOIN sys.schemas s ON t.schema_id = s.schema_id
     WHERE i.is_hypothetical = 0
       AND i.name IS NOT NULL
       AND s.name = 'dbo'
    UNION ALL
    -- functions
    SELECT 'functions',
           o.name,
           s.name
      FROM sys.objects o
      JOIN sys.schemas s ON o.schema_id = s.schema_id
     WHERE o.type IN ('FN','IF','TF')  -- scalar, inline, table-valued
       AND s.name = 'dbo'
    UNION ALL
    -- procedures
    SELECT 'procedures',
           p.name,
           s.name
      FROM sys.procedures p
      JOIN sys.schemas s ON p.schema_id = s.schema_id
     WHERE s.name = 'dbo'
)
SELECT UPPER(object_owner) AS schema_name,
       object_type,
       COUNT(*) AS object_count
  FROM objects
 GROUP BY object_owner, object_type
 ORDER BY object_owner, object_type;
 --%01F

-- Get table names and options (partitioning, identity) for tables.
-- Data will be stored in trg/metadata_02.csv (table trg.metadata_02).
--%02S
 SELECT
    s.name  AS schema_name,
    t.name  AS table_name,
    t.name  AS orig_tabname,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM sys.indexes i
            JOIN sys.partition_schemes ps
                ON i.data_space_id = ps.data_space_id
            WHERE i.object_id = t.object_id
              AND i.index_id IN (0, 1)   -- heap or clustered index
        )
        THEN 'YES' ELSE 'NO'
    END AS is_partitioned,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM sys.identity_columns ic
            WHERE ic.object_id = t.object_id
        )
        THEN 'YES' ELSE 'NO'
    END AS has_identity
FROM sys.tables t
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE s.name = 'dbo'
ORDER BY t.name;
--%02F

-- Get column count per table for the current schema.
-- Data will be stored in trg/metadata_03.csv (table trg.metadata_03).
--%03S
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    COUNT(c.column_id) AS column_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
WHERE s.name = 'dbo'
GROUP BY s.name, t.name
ORDER BY t.name;
--%03F

-- Describe all columns in the schema, including data types, lengths, nullability, and defaults.
-- Data will be stored in trg/metadata_04.csv (table trg.metadata_04).
--%04S
SELECT
    c.TABLE_SCHEMA AS schema_name,
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.COLUMN_NAME AS orig_colname,
    c.ORDINAL_POSITION AS column_pos,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH AS data_length,
    c.NUMERIC_PRECISION AS data_precision,
    c.NUMERIC_SCALE AS data_scale,
    CASE
        WHEN c.CHARACTER_MAXIMUM_LENGTH IS NOT NULL 
            THEN c.DATA_TYPE + '(' + 
                 CASE 
                     WHEN c.CHARACTER_MAXIMUM_LENGTH = -1 THEN 'MAX' 
                     ELSE CAST(c.CHARACTER_MAXIMUM_LENGTH AS VARCHAR(20)) 
                 END + ')'
        WHEN c.NUMERIC_PRECISION IS NOT NULL AND c.NUMERIC_SCALE IS NOT NULL 
            THEN c.DATA_TYPE + '(' + 
                 CAST(c.NUMERIC_PRECISION AS VARCHAR(20)) + ',' + 
                 CAST(c.NUMERIC_SCALE AS VARCHAR(20)) + ')'
        ELSE c.DATA_TYPE
    END AS type_formatted,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT AS data_default
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'dbo'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
--%04F

-- Dynamically build SQL to calculate row counts for every table in the current schema.
-- Data will be stored in trg/metadata_10.csv (table trg.metadata_10).
--%10S
--#SQL#
SELECT
    'SELECT '
    + QUOTENAME(s.name, '''') + ' AS schema_name, '
    + QUOTENAME(t.name, '''') + ' AS table_name, '
    + 'COUNT(*) AS row_count '
    + 'FROM ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) AS SQL
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'dbo'
ORDER BY t.name;
--%10F

-- Generate SQL query to get rows for all tables in the IDC schema
-- Data will be stored in trg/metadata_11.csv (table trg.metadata_11).
--%11S
--#HASH#
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    'SELECT '
    + QUOTENAME(STRING_AGG(c.name, '|' ) WITHIN GROUP (ORDER BY ic.key_ordinal), '''')
    + ' AS pk_col, '
    + STRING_AGG('CAST(t.' + QUOTENAME(c.name) + ' AS NVARCHAR(MAX))'
                 , ' + ''|'' + ') WITHIN GROUP (ORDER BY ic.key_ordinal)
    + ' AS pk_value, t.* FROM '
    + QUOTENAME(s.name) + '.' + QUOTENAME(t.name)
    + ' t ORDER BY 2' AS sql
FROM sys.tables t
JOIN sys.schemas s 
    ON t.schema_id = s.schema_id
JOIN sys.key_constraints kc 
    ON kc.parent_object_id = t.object_id
    AND kc.type = 'PK'
JOIN sys.index_columns ic 
    ON ic.object_id = t.object_id 
    AND ic.index_id = kc.unique_index_id
JOIN sys.columns c 
    ON c.object_id = t.object_id 
    AND c.column_id = ic.column_id
WHERE s.name = 'dbo'
GROUP BY s.name, t.name
ORDER BY t.name;
--%11F