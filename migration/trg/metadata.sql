-- Count major object types in the current schema (tables, sequences, columns, PKs, FKs, indexes).
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