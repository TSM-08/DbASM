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

    UNION ALL

    -- sequences
    SELECT 'sequences',
           s.sequencename,
           s.schemaname
      FROM pg_catalog.pg_sequences s
     WHERE s.schemaname = current_schema()

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

-- List tables with identity and partitioning flags.
--%02S
SELECT
  upper(t.table_schema) AS schema_name,
  upper(t.table_name) AS table_name,
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

-- Describe all columns in the schema, including data types, lengths, nullability, and defaults.
--%03S
SELECT
  upper(c.table_schema) AS schema_name,
  upper(c.table_name) AS table_name,
  upper(c.column_name) AS column_name,
  c.column_name AS orig_colname,
  c.ordinal_position AS column_pos,
  upper(c.data_type) AS data_type,
  c.character_maximum_length AS data_length,
  c.numeric_precision AS data_precision,
  c.numeric_scale AS data_scale,
  CASE
    WHEN c.character_maximum_length IS NOT NULL THEN upper(c.data_type) || '(' || c.character_maximum_length || ')'
    WHEN c.numeric_precision IS NOT NULL AND c.numeric_scale IS NOT NULL THEN upper(c.data_type) || '(' || c.numeric_precision || ',' || c.numeric_scale || ')'
    ELSE upper(c.data_type)
  END AS type_formatted,
  c.is_nullable,
  c.column_default AS data_default
FROM information_schema.columns c
WHERE c.table_schema = current_schema()
ORDER BY c.table_name, c.ordinal_position;
--%03F

-- List all identity columns and their associated sequences for the current schema.
--%04S
--#SQL#
SELECT format(
       'SELECT %L AS schema_name, %L AS table_name, %L AS column_name, %L AS sequence_name, ' ||
       'COALESCE(MAX(%I), 0) AS max_value FROM %I.%I',
          upper(n.nspname),          -- schema_name
          upper(t.relname),          -- table_name
          upper(a.attname),          -- column_name
          s.relname,                 -- sequence_name
          a.attname,                 -- MAX(column)
          n.nspname,                 -- schema
          t.relname                  -- table
       ) AS sql
  FROM pg_class s
  JOIN pg_namespace n
    ON n.oid = s.relnamespace
  JOIN pg_depend d
    ON d.objid = s.oid
  JOIN pg_class t
    ON d.refobjid = t.oid
JOIN pg_attribute a
    ON a.attrelid = t.oid
   AND a.attnum = d.refobjsubid
 WHERE s.relkind = 'S'
   AND n.nspname = current_schema()
 ORDER BY t.relname ASC, a.attname ASC;
--%04F

-- List all sequences with their current value and properties.
--%05S
SELECT
  upper(s.schemaname) AS schema_name,
  s.sequencename AS sequence_name,
  s.last_value::BIGINT AS current_value,
  s.start_value::BIGINT AS start_value,
  s.min_value::NUMERIC AS min_value,
  s.max_value::NUMERIC AS max_value,
  s.increment_by::BIGINT AS increment_by,
  CASE WHEN s.cycle THEN 'YES' ELSE 'NO' END AS cycle_flag,
  s.cache_size::BIGINT AS cache_size
FROM pg_catalog.pg_sequences s
WHERE s.schemaname = current_schema()
ORDER BY s.sequencename;
--%05F

-- List all primary key constraints and their columns.
--%06S
SELECT
  upper(tc.constraint_schema) AS schema_name,
  upper(tc.table_name) AS table_name,
  tc.constraint_name,
  string_agg(upper(kcu.column_name), ', ' ORDER BY kcu.ordinal_position) AS pk_column,
  tc.is_deferrable || '_' ||
  tc.initially_deferred || '_' ||
  tc.enforced AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name
 AND kcu.constraint_schema = tc.constraint_schema
 AND kcu.table_name = tc.table_name
WHERE tc.constraint_schema = current_schema()
  AND tc.constraint_type = 'PRIMARY KEY'
GROUP BY tc.constraint_schema, tc.table_name, tc.constraint_name, 
    tc.is_deferrable, tc.initially_deferred, tc.enforced, tc.nulls_distinct
ORDER BY tc.table_name, tc.constraint_name; 
--%06F

-- List all check constraints and their definitions.
--%07S
SELECT
  tc.constraint_schema AS schema_name,
  upper(tc.table_name) AS table_name,
  tc.constraint_name,
  pg_get_constraintdef(con.oid) AS definition
FROM information_schema.table_constraints tc
JOIN pg_catalog.pg_constraint con
  ON con.conname = tc.constraint_name
 AND con.connamespace = (SELECT oid FROM pg_catalog.pg_namespace WHERE nspname = tc.constraint_schema)
WHERE tc.constraint_schema = current_schema()
  AND tc.constraint_type = 'CHECK'
ORDER BY table_name, constraint_name;
--%07F

-- List all foreign key constraints, their columns, referenced tables, and delete rules.
--%08S
SELECT
  upper(kcu.table_schema) AS schema_name,
  upper(kcu.table_name) AS table_name,
  kcu.constraint_name,
  string_agg(upper(kcu.column_name), ', ' ORDER BY kcu.ordinal_position) AS child_columns,
  upper(ccu.table_schema) AS parent_schema,
  upper(ccu.table_name) AS parent_table,
  string_agg(upper(pkcu.column_name), ', ' ORDER BY pkcu.ordinal_position) AS parent_columns,
  rc.delete_rule
FROM information_schema.key_column_usage kcu
JOIN information_schema.referential_constraints rc
  ON kcu.constraint_name = rc.constraint_name
 AND kcu.constraint_schema = rc.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON rc.unique_constraint_name = ccu.constraint_name
 AND rc.unique_constraint_schema = ccu.constraint_schema
JOIN information_schema.key_column_usage pkcu
  ON pkcu.constraint_name = rc.unique_constraint_name
 AND pkcu.constraint_schema = rc.unique_constraint_schema
WHERE kcu.table_schema = current_schema()
GROUP BY kcu.table_schema, kcu.table_name, kcu.constraint_name, ccu.table_schema, ccu.table_name, rc.delete_rule
ORDER BY kcu.table_name, kcu.constraint_name;
--%08F

-- List all indexes, their uniqueness, primary key status, columns, and index type.
--%09S
SELECT
  upper(n.nspname) AS schema_name,
  upper(t.relname) AS table_name,
  upper(i.relname) AS index_name,
  CASE WHEN ix.indisunique THEN 'YES' ELSE 'NO' END AS is_unique,
  CASE WHEN ix.indisprimary THEN 'YES' ELSE 'NO' END AS is_primary,
  (SELECT string_agg(upper(a.attname) || ' ' || 
          CASE WHEN (ix.indoption[array_position(ix.indkey, a.attnum)-1] & 1) = 1 THEN 'DESC' 
               ELSE 'ASC' END, ', ' ORDER BY array_position(ix.indkey, a.attnum))
   FROM pg_attribute a
   WHERE a.attrelid = ix.indrelid AND a.attnum = ANY(ix.indkey)) AS index_columns,
  am.amname AS index_type
FROM pg_catalog.pg_index ix
JOIN pg_catalog.pg_class i ON i.oid = ix.indexrelid
JOIN pg_catalog.pg_class t ON t.oid = ix.indrelid
JOIN pg_catalog.pg_namespace n ON n.oid = t.relnamespace
JOIN pg_catalog.pg_am am ON am.oid = i.relam
WHERE n.nspname = current_schema()
ORDER BY t.relname, i.relname;
--%09F

-- Dynamically build SQL to calculate row counts for every table in the current schema.
--%10S
--#SQL#
SELECT
  'SELECT '
    || upper(quote_literal(n.nspname)) || ' AS schema_name, '
    || upper(quote_literal(c.relname)) || ' AS table_name, '
    || 'count(*)::BIGINT AS row_count '
    || 'FROM ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname)
    AS SQL
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = current_schema()
  AND c.relkind = 'r'
ORDER BY c.relname;
--%10F

-- Generate SQL query to get rows for all tables in the IDC schema
--%11S
--#HASH#
SELECT
    upper(tc.constraint_schema) AS schema_name,
    upper(tc.table_name) AS table_name,
    format(
      'SELECT %s AS pk_col, %s AS pk_value, t.* FROM %s.%s t ORDER BY 2',
      quote_literal(string_agg(kcu.column_name, '|' ORDER BY kcu.ordinal_position)),
      string_agg('t.' || quote_ident(kcu.column_name), ' || ''|'' || ' ORDER BY kcu.ordinal_position),
      quote_ident(tc.constraint_schema),
      quote_ident(tc.table_name)
    ) AS sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  USING (constraint_schema, constraint_name)
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.constraint_schema = current_schema()
GROUP BY tc.constraint_schema, tc.table_name
ORDER BY tc.table_name;
--%11F