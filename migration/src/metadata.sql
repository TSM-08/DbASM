-- Count major object types in the current schema (tables, sequences, columns, PKs, FKs, indexes).
--%01S
WITH objects AS (

    -- tables
    SELECT 'tables' AS object_type,
           c.relname AS object_name,
           n.nspname AS object_owner
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'r'
       AND n.nspname = current_schema()

    UNION ALL

    -- views
    SELECT 'views',
           c.relname,
           n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'v'
       AND n.nspname = current_schema()
/* 
    UNION ALL

    -- sequences
    SELECT 'sequences',
           s.sequencename,
           s.schemaname
      FROM pg_catalog.pg_sequences s
     WHERE s.schemaname = current_schema()
*/
    UNION ALL

    -- primary key constraints
    SELECT 'pkeys_constraints',
           c.conname,
           n.nspname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE c.contype = 'p'
       AND n.nspname = current_schema()

    UNION ALL

    -- foreign key constraints
    SELECT 'fkeys_constraints',
           c.conname,
           n.nspname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE c.contype = 'f'
       AND n.nspname = current_schema()

    UNION ALL

    -- check constraints
    SELECT 'check_constraints',
           c.conname,
           n.nspname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE c.contype = 'c'
       AND n.nspname = current_schema()

    UNION ALL

    -- unique constraints
    SELECT 'unique_constraints',
           c.conname,
           n.nspname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE c.contype = 'u'
       AND n.nspname = current_schema()

    UNION ALL

    -- triggers
    SELECT 'triggers',
           t.trigger_name,
           t.trigger_schema
      FROM information_schema.triggers t
     WHERE t.trigger_schema = current_schema()

    UNION ALL

    -- indexes (exclude system)
    SELECT 'indexes',
           c.relname,
           n.nspname
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE c.relkind = 'i'
       AND n.nspname = current_schema()
       AND c.relname NOT LIKE 'pg_%'
       AND c.relname NOT LIKE 'sql_%'

    UNION ALL

    -- functions
    SELECT 'functions',
           r.routine_name,
           r.routine_schema
      FROM information_schema.routines r
     WHERE r.routine_type = 'FUNCTION'
       AND r.routine_schema = current_schema()

    UNION ALL

    -- procedures
    SELECT 'procedures',
           r.routine_name,
           r.routine_schema
      FROM information_schema.routines r
     WHERE r.routine_type = 'PROCEDURE'
       AND r.routine_schema = current_schema()
)

SELECT upper(object_owner) AS schema_name,
       object_type,
       COUNT(*) AS object_count
  FROM objects
 GROUP BY object_owner, object_type
 ORDER BY object_owner, object_type;
--%01F

-- Get table names and options (partitioning, identity) for tables.
--%02S
SELECT
  t.table_schema AS schema_name,
  t.table_name,
  t.table_name AS orig_tabname,
  CASE WHEN c.relispartition THEN 'YES' ELSE 'NO' END AS is_partitioned,
  CASE WHEN EXISTS (
      SELECT 1
      FROM information_schema.columns col
      WHERE col.table_schema = t.table_schema
        AND col.table_name = t.table_name
        AND col.is_identity = 'YES'
  ) THEN 'YES' ELSE 'NO' END AS has_identity
FROM information_schema.tables t
JOIN pg_catalog.pg_class c
  ON c.relname = t.table_name
 AND c.relnamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = t.table_schema)
WHERE t.table_schema = current_schema()
  AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;
--%02F

-- Get column count per table for the current schema.
--%03S
SELECT
    table_schema AS schema_name,
    table_name,
    COUNT(column_name) AS column_count
FROM information_schema.columns
WHERE table_schema = current_schema()
GROUP BY table_schema, table_name
ORDER BY table_name;
--%03F