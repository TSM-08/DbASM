-- Count major object types in the current schema (tables, sequences, columns, PKs, FKs, indexes).
--%01S
SELECT current_schema() AS schema_name, 'tables' AS object_type,
       COUNT(*) AS object_count
  FROM pg_class t
  JOIN pg_namespace n
    ON n.oid = t.relnamespace
 WHERE n.nspname = current_schema()
   AND t.relkind = 'r'     -- ordinary tables
 UNION ALL
SELECT current_schema(), 'views', COUNT(*)
  FROM pg_class v
  JOIN pg_namespace n
    ON n.oid = v.relnamespace
 WHERE n.nspname = current_schema()
   AND v.relkind = 'v'   
 UNION ALL
SELECT current_schema(), 'sequences', COUNT(*)
  FROM pg_catalog.pg_sequences s
 WHERE schemaname = current_schema()
 UNION ALL
SELECT current_schema(), 'pkeys_constraints', COUNT(*)
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
 WHERE c.contype = 'p'
   AND n.nspname = current_schema()
 UNION ALL
SELECT current_schema(), 'fkeys_constraints', COUNT(*)
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
 WHERE c.contype = 'f'
   AND n.nspname = current_schema()
 UNION ALL
SELECT current_schema(), 'check_constraints',  COUNT(*)
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
 WHERE c.contype = 'c'
   AND n.nspname = current_schema()
 UNION ALL
SELECT current_schema(), 'unique_constraints', COUNT(*)
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
 WHERE c.contype = 'u'
   AND n.nspname = current_schema()
 UNION ALL
SELECT current_schema(), 'triggers', COUNT(*)
  FROM information_schema.triggers t
 WHERE t.trigger_schema = current_schema()
 UNION ALL
SELECT current_schema(), 'indexes', COUNT(*)
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = current_schema()
   AND c.relkind = 'i'
   AND c.relname NOT LIKE 'pg_%'
   AND c.relname NOT LIKE 'sql_%'
 UNION ALL
SELECT current_schema(), 'functions', COUNT(*)
  FROM information_schema.routines
 WHERE routine_schema = current_schema()
   AND routine_type = 'FUNCTION'
 UNION ALL
SELECT current_schema(), 'procedures', COUNT(*)
  FROM information_schema.routines
 WHERE routine_schema = current_schema()
   AND routine_type = 'PROCEDURE';
--%01F

-- List tables with identity and partitioning flags.
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

-- Describe all columns in the schema, including data types, lengths, nullability, and defaults.
--%03S
SELECT
  c.table_schema AS schema_name,
  c.table_name,
  c.column_name,
  c.column_name AS orig_colname,
  c.ordinal_position AS column_pos,
  c.data_type,
  c.character_maximum_length AS data_length,
  c.numeric_precision AS data_precision,
  c.numeric_scale AS data_scale,
  CASE
    WHEN c.character_maximum_length IS NOT NULL THEN c.data_type || '(' || c.character_maximum_length || ')'
    WHEN c.numeric_precision IS NOT NULL AND c.numeric_scale IS NOT NULL THEN c.data_type || '(' || c.numeric_precision || ',' || c.numeric_scale || ')'
    ELSE c.data_type
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
SELECT
  format(
    'SELECT %L AS schema_name, %L AS table_name, %L AS column_name, %L AS sequence_name, MAX(%I) AS max_value
     FROM %I.%I;',
    c.table_schema,
    c.table_name,
    c.column_name,
    pg_get_serial_sequence(
        quote_ident(c.table_schema) || '.' || quote_ident(c.table_name),
        c.column_name),
    c.column_name,
    c.table_schema,
    c.table_name
  ) AS sql
FROM information_schema.columns c
WHERE c.table_schema = current_schema()
  AND c.is_identity = 'YES'
ORDER BY c.table_name ASC, c.ordinal_position ASC;
--%04F

-- List all sequences with their current value and properties.
--%05S
SELECT
  s.schemaname AS schema_name,
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
  tc.constraint_schema AS schema_name,
  tc.table_name,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS pk_column,
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
  tc.table_name,
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
  kcu.table_schema AS schema_name,
  kcu.table_name,
  kcu.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS child_columns,
  ccu.table_schema AS parent_schema,
  ccu.table_name AS parent_table,
  string_agg(pkcu.column_name, ', ' ORDER BY pkcu.ordinal_position) AS parent_columns,
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
  n.nspname AS schema_name,
  t.relname AS table_name,
  i.relname AS index_name,
  CASE WHEN ix.indisunique THEN 'YES' ELSE 'NO' END AS is_unique,
  CASE WHEN ix.indisprimary THEN 'YES' ELSE 'NO' END AS is_primary,
  (SELECT string_agg(a.attname || ' ' || 
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
    || quote_literal(n.nspname) || ' AS schema_name, '
    || quote_literal(c.relname) || ' AS table_name, '
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
    tc.constraint_schema AS schema_name,
    tc.table_name AS table_name,
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