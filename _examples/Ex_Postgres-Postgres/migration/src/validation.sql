-- Script to check if all tables in the IDC schema have a primary key
--%12S
SELECT 
    t.schemaname AS schema_name,
    t.tablename AS table_name,
    CASE 
        WHEN pk.constraint_name IS NOT NULL THEN 'YES'
        ELSE 'NO'
    END AS has_primary_key
FROM pg_tables t
LEFT JOIN (
    SELECT 
		tc.table_schema,
        tc.table_name,
        tc.constraint_name
    FROM information_schema.table_constraints tc
    WHERE tc.constraint_type = 'PRIMARY KEY' 
) pk ON t.tablename = pk.table_name 
	AND t.schemaname = pk.table_schema
WHERE t.schemaname = current_schema()
AND pk.constraint_name IS NULL
ORDER BY t.tablename ASC;
--%12F

-- Script to generate SQL queries that check for primary key duplicates for each table in the IDC schema
--%13S
--#SQL#
SELECT
  format(
    'SELECT %L AS schema_name, %L AS table_name, %L AS pk_column, %s AS pk_value, COUNT(*) AS dup_count
     FROM %I.%I
     GROUP BY %s
     HAVING COUNT(*) > 1',
    tc.table_schema,
    tc.table_name,
    string_agg(kcu.column_name, '|' ORDER BY kcu.ordinal_position),
    string_agg(format('%I::text', kcu.column_name), ' || ''|'' || ' ORDER BY kcu.ordinal_position),
    tc.table_schema,
    tc.table_name,
    string_agg(format('%I', kcu.column_name), ', ' ORDER BY kcu.ordinal_position)
  ) AS sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema = current_schema()
GROUP BY tc.table_schema, tc.table_name;
--%13F

-- Script to generate SQL queries that check for NULLs in NOT NULL columns for each table in the IDC schema
--%14S
--#SQL#
SELECT
  format(
    'SELECT %L AS schema_name, %L AS table_name, %L AS column_name, COUNT(*) AS null_count
     FROM %I.%I
     WHERE %I IS NULL
     HAVING COUNT(*) > 1',
    cols.table_schema,
    cols.table_name,
    cols.column_name,
    cols.table_schema,
    cols.table_name,
    cols.column_name
  ) AS sql
FROM information_schema.columns cols
WHERE cols.table_schema = current_schema()
  AND cols.is_nullable = 'NO'
ORDER BY cols.table_name ASC, cols.column_name ASC;
--%14F

-- Script to generate SQL queries that check for foreign key constraints in the IDC schema
--%15S
--#SQL#
SELECT
  format(
    'SELECT %L AS schema_name, %L AS child_table, %L AS parent_table, %L AS join_condition,
            COUNT(*) AS count
     FROM %I.%I c
     WHERE %s
       AND NOT EXISTS (
         SELECT 1
         FROM %I.%I p
         WHERE %s
       )
     HAVING COUNT(*) > 1',
    tc.table_schema,
    tc.table_name,
    ccu.table_name,
    string_agg(
      format('c.%I = p.%I', kcu.column_name, ccu.column_name),
      ' AND '
      ORDER BY kcu.ordinal_position
    ),
    tc.table_schema,
    tc.table_name,
    string_agg(
      format('c.%I IS NOT NULL', kcu.column_name),
      ' AND '
      ORDER BY kcu.ordinal_position
    ),
    ccu.table_schema,
    ccu.table_name,
    string_agg(
      format('c.%I = p.%I', kcu.column_name, ccu.column_name),
      ' AND '
      ORDER BY kcu.ordinal_position
    )
  ) AS sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
 AND tc.table_schema = rc.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON rc.unique_constraint_name = ccu.constraint_name
 AND rc.unique_constraint_schema = ccu.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = current_schema()
GROUP BY
  tc.table_schema,
  tc.table_name,
  ccu.table_schema,
  ccu.table_name,
  tc.constraint_name
ORDER BY tc.table_name ASC, ccu.table_name ASC;
--%15F

-- Script to find disabled foreign key constraints in the IDC schema
--%16S
SELECT
    nsp.nspname        AS schema_name,
    rel.relname        AS table_name,
    con.conname        AS constraint_name,
    rnsp.nspname       AS referenced_schema,
    rrel.relname       AS referenced_table
FROM pg_constraint con
JOIN pg_class rel
    ON rel.oid = con.conrelid
JOIN pg_namespace nsp
    ON nsp.oid = rel.relnamespace
JOIN pg_class rrel
    ON rrel.oid = con.confrelid
JOIN pg_namespace rnsp
    ON rnsp.oid = rrel.relnamespace
WHERE con.contype = 'f'          -- foreign keys
  AND nsp.nspname = current_schema()
  AND con.convalidated = false   -- disabled (NOT VALID)
ORDER BY nsp.nspname ASC, 
      rel.relname ASC, 
      con.conname ASC;
--%16F

-- Script to generate SQL queries to find identity columns where the sequence last_value is less 
-- than the max value in the column
--%17S
--#SQL#
SELECT
  format(
    'SELECT %L AS schema_name, %L AS table_name, %L AS identity_column, %L AS sequence_name,
            (SELECT last_value FROM %I.%I) AS last_value,
            COALESCE(MAX(%I), 0) AS max_value
     FROM %I.%I
     HAVING COALESCE(MAX(%I), 0) > (SELECT last_value FROM %I.%I)',
    n.nspname,
    t.relname,
    a.attname,
    s.relname,
    n.nspname,
    s.relname,
    a.attname,
    n.nspname,
    t.relname,
    a.attname,
    n.nspname,
    s.relname
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
--%17F