-- Count major object types in the current schema (tables, sequences, columns, PKs, FKs, indexes).
--%01S
WITH objects AS (

    -- tables
    SELECT 'tables' AS object_type,
           t.table_name AS object_name,
           t.owner AS object_owner
      FROM all_tables t
     WHERE t.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
       AND t.dropped = 'NO'

    UNION ALL

    -- views
    SELECT 'views',
           v.view_name,
           v.owner
      FROM all_views v
     WHERE v.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- identity sequences (only linked to existing tables)
    SELECT 'sequences',
           s.sequence_name,
           s.sequence_owner
      FROM all_sequences s
      JOIN all_tab_identity_cols ic
        ON ic.sequence_name = s.sequence_name
       AND ic.owner = s.sequence_owner
      JOIN all_tables t
        ON t.owner = ic.owner
       AND t.table_name = ic.table_name
       AND t.dropped = 'NO'
     WHERE s.sequence_owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- primary key constraints
    SELECT 'pkeys_constraints',
           c.constraint_name,
           c.owner
      FROM all_constraints c
      JOIN all_tables t
        ON t.owner = c.owner
       AND t.table_name = c.table_name
       AND t.dropped = 'NO'
     WHERE c.constraint_type = 'P'
       AND c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- foreign key constraints
    SELECT 'fkeys_constraints',
           c.constraint_name,
           c.owner
      FROM all_constraints c
      JOIN all_tables t
        ON t.owner = c.owner
       AND t.table_name = c.table_name
       AND t.dropped = 'NO'
     WHERE c.constraint_type = 'R'
       AND c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- check constraints (user-defined only)
    SELECT 'check_constraints',
           c.constraint_name,
           c.owner
      FROM all_constraints c
      JOIN all_tables t
        ON t.owner = c.owner
       AND t.table_name = c.table_name
       AND t.dropped = 'NO'
     WHERE c.constraint_type = 'C'
       AND c.generated != 'GENERATED NAME'
       AND c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- unique constraints
    SELECT 'unique_constraints',
           c.constraint_name,
           c.owner
      FROM all_constraints c
      JOIN all_tables t
        ON t.owner = c.owner
       AND t.table_name = c.table_name
       AND t.dropped = 'NO'
     WHERE c.constraint_type = 'U'
       AND c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- triggers
    SELECT 'triggers',
           trg.trigger_name,
           trg.owner
      FROM all_triggers trg
      JOIN all_tables t
        ON t.owner = trg.owner
       AND t.table_name = trg.table_name
       AND t.dropped = 'NO'
     WHERE trg.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- indexes (exclude LOB)
    SELECT 'indexes',
           i.index_name,
           i.owner
      FROM all_indexes i
      JOIN all_tables t
        ON t.owner = i.owner
       AND t.table_name = i.table_name
       AND t.dropped = 'NO'
     WHERE i.index_type <> 'LOB'
       AND i.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- functions
    SELECT 'functions',
           o.object_name,
           o.owner
      FROM all_objects o
     WHERE o.object_type = 'FUNCTION'
       AND o.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')

    UNION ALL

    -- procedures
    SELECT 'procedures',
           o.object_name,
           o.owner
      FROM all_objects o
     WHERE o.object_type = 'PROCEDURE'
       AND o.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
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
SELECT t.owner AS schema_name,
       t.table_name,
       t.table_name AS orig_tabname,
       CASE
       WHEN p.table_name IS NOT NULL THEN 'YES' ELSE 'NO'
       END AS is_partitioned,
       CASE
       WHEN EXISTS (
            SELECT 1
              FROM all_tab_identity_cols ic
             WHERE ic.table_name = t.table_name
       ) THEN 'YES' ELSE 'NO'
       END AS has_identity
  FROM all_tables t
  LEFT JOIN all_part_tables p
    ON p.table_name = t.table_name
 WHERE t.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 ORDER BY 
       t.table_name;
--%02F

-- Describe all columns in the schema, including data types, lengths, nullability, and defaults.
--%03S
SELECT c.owner AS schema_name,
       c.table_name,
       c.column_name,
       c.column_name AS orig_colname,
       c.column_id AS column_pos,
       c.data_type,
       c.char_length AS data_length,
       c.data_precision AS data_precision,
       c.data_scale AS data_scale,
       CASE 
       WHEN c.data_type IN ('VARCHAR2', 'CHAR') AND c.char_length IS NOT NULL 
            THEN data_type || '(' || char_length || ')'
       WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL AND data_scale IS NOT NULL 
            THEN data_type || '(' || data_precision || ',' || data_scale || ')'
       WHEN data_type = 'NUMBER' AND data_precision IS NOT NULL 
            THEN data_type || '(' || data_precision || ')'
       ELSE data_type
       END AS type_formatted,
       CASE 
       WHEN nullable = 'Y' THEN 'YES' ELSE 'NO' 
       END AS is_nullable,
       CASE
       WHEN c.identity_column = 'YES' THEN NULL ELSE c.data_default
       END AS data_default
  FROM all_tab_columns c
  JOIN all_tables t
    ON t.owner = c.owner
   AND t.table_name = c.table_name
 WHERE c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 ORDER BY 
       c.table_name, c.column_id;
--%03F

-- List all identity columns and their associated sequences for the current schema.
--%04S
--#SQL#
SELECT 'SELECT '''
       || c.owner || ''' AS schema_name, '''
       || c.table_name || ''' AS table_name, '''
       || c.column_name || ''' AS column_name, '''
       || ic.sequence_name || ''' AS sequence_name, '
       || 'MAX("' || c.column_name || '") AS max_value '
       || 'FROM "' || c.owner || '"."' || c.table_name || '";'
       AS sql
  FROM all_tab_columns c
  JOIN all_tab_identity_cols ic
    ON ic.owner       = c.owner
   AND ic.table_name  = c.table_name
   AND ic.column_name = c.column_name
 WHERE c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 ORDER BY 
       c.table_name, c.column_id;
--%04F

-- List all sequences with their current value and properties.
--%05S
SELECT s.sequence_owner AS schema_name,
       s.sequence_name,
       (s.last_number - s.increment_by) AS current_value,
       s.min_value AS start_value,
       s.min_value,
       s.max_value,
       s.increment_by,
       CASE WHEN s.cycle_flag = 'Y' THEN 'YES' ELSE 'NO' END AS cycle_flag,
       s.cache_size
  FROM all_sequences s
  JOIN all_tab_identity_cols ic
    ON s.sequence_owner = ic.owner
   AND s.sequence_name  = ic.sequence_name
  JOIN all_tables t
    ON t.owner = ic.owner
   AND t.table_name = ic.table_name
 WHERE s.sequence_owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 ORDER BY
       s.sequence_name;
--%05F

-- List all primary key constraints and their columns.
--%06S
SELECT c.owner AS schema_name,
       c.table_name,
       c.constraint_name,
       LISTAGG(cc.column_name, ', ')
       WITHIN GROUP (ORDER BY cc.position) AS pk_column,
       CASE WHEN c.deferrable = 'DEFERRABLE' THEN 'YES' ELSE 'NO' END || '_' ||
       CASE WHEN c.deferred   = 'DEFERRED'   THEN 'YES' ELSE 'NO' END || '_' ||
       CASE WHEN c.validated  = 'VALIDATED'  THEN 'YES' ELSE 'NO' END
       AS status
  FROM all_constraints c
  JOIN all_cons_columns cc
    ON cc.owner           = c.owner
   AND cc.constraint_name = c.constraint_name
   AND cc.table_name      = c.table_name
  JOIN all_tables t
    ON t.owner      = c.owner
   AND t.table_name = c.table_name
 WHERE c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
   AND c.constraint_type = 'P'
 GROUP BY
       c.owner,
       c.table_name,
       c.constraint_name,
       c.deferrable,
       c.deferred,
       c.validated
ORDER BY 
       c.table_name, c.constraint_name;
--%06F

-- List all check constraints and their definitions.
--%07S
SELECT c.owner AS schema_name,
       c.table_name,
       c.constraint_name,
       c.search_condition_vc AS definition
  FROM all_constraints c
  JOIN all_tables t
    ON t.owner = c.owner
   AND t.table_name = c.table_name
 WHERE c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
   AND c.constraint_type = 'C'
   AND c.generated != 'GENERATED NAME'
 ORDER BY 
       c.table_name, c.constraint_name;
--%07F

-- List all foreign key constraints, their columns, referenced tables, and delete rules.
--%08S
SELECT fk.owner AS schema_name,
       fk.table_name,
       fk.constraint_name,
       LISTAGG(fkc.column_name, ', ')
          WITHIN GROUP (ORDER BY fkc.position) AS child_columns,
       pk.owner AS parent_schema,
       pk.table_name AS parent_table,
       LISTAGG(pkc.column_name, ', ')
          WITHIN GROUP (ORDER BY pkc.position) AS parent_columns,
       fk.delete_rule
  FROM all_constraints fk
  JOIN all_cons_columns fkc
    ON fk.owner = fkc.owner
   AND fk.constraint_name = fkc.constraint_name
  JOIN all_constraints pk
    ON fk.r_owner = pk.owner
   AND fk.r_constraint_name = pk.constraint_name
  JOIN all_cons_columns pkc
    ON pk.owner = pkc.owner
   AND pk.constraint_name = pkc.constraint_name
   AND fkc.position = pkc.position
 WHERE fk.constraint_type = 'R'   -- Foreign keys
   AND fk.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 GROUP BY
       fk.owner,
       fk.table_name,
       fk.constraint_name,
       pk.owner,
       pk.table_name,
       fk.delete_rule
 ORDER BY
       fk.table_name,
       fk.constraint_name;
--%08F

-- List all indexes, their uniqueness, primary key status, columns, and index type.
--%09S
SELECT upper(idx.owner) AS schema_name,
       upper(idx.table_name) AS table_name,
       upper(idx.index_name) AS index_name,
       CASE WHEN idx.uniqueness = 'UNIQUE'
            THEN 'YES' ELSE 'NO' END AS is_unique,
       CASE WHEN pk.constraint_name IS NOT NULL
            THEN 'YES' ELSE 'NO' END AS is_primary,
       LISTAGG(upper(ic.column_name) || ' ' ||
               CASE ic.descend WHEN 'DESC' THEN 'DESC'
               ELSE 'ASC' END, ', ') 
       WITHIN GROUP (ORDER BY ic.column_position) AS index_columns,
       idx.index_type
  FROM all_indexes idx
  JOIN all_ind_columns ic
    ON idx.owner      = ic.index_owner
   AND idx.index_name = ic.index_name
  LEFT JOIN all_constraints pk
    ON pk.owner       = idx.owner
   AND pk.index_name  = idx.index_name
   AND pk.constraint_type = 'P'
 WHERE idx.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 GROUP BY
       idx.owner,
       idx.table_name,
       idx.index_name,
       idx.uniqueness,
       idx.index_type,
       pk.constraint_name
 ORDER BY
       idx.table_name,
       idx.index_name;
--%09F

-- Dynamically build SQL to calculate row counts for every table in the current schema.
--%10S
--#SQL#
SELECT 'SELECT '
       || '''' || t.owner || ''' AS schema_name, '
       || '''' || t.table_name || ''' AS table_name, '
       || 'COUNT(*) AS row_count '
       || 'FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(t.owner)
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(t.table_name)
       AS SQL
  FROM all_tables t
 WHERE t.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 ORDER BY 
       upper(t.table_name);
--%10F

-- Generate SQL query to get rows for all tables in the IDC schema
--%11S
--#HASH#
SELECT ac.owner AS schema_name,
       upper(ac.table_name) AS table_name,
       'SELECT '
       || ''''
       || LISTAGG(upper(acc.column_name), '|' )
            WITHIN GROUP (ORDER BY acc.position)
       || ''' AS pk_col, '
       || LISTAGG('t.' || DBMS_ASSERT.ENQUOTE_NAME(upper(acc.column_name)),
           ' || ''|'' || '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ' AS pk_value, '
       || 't.* FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(upper(ac.owner))
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(upper(ac.table_name))
       || ' t ORDER BY 2'
       AS sql
  FROM all_constraints ac
  JOIN all_cons_columns acc
    ON ac.owner = acc.owner
   AND ac.constraint_name = acc.constraint_name
  JOIN all_tables t
    ON t.owner = ac.owner
   AND t.table_name = ac.table_name
 WHERE ac.constraint_type = 'P'
   AND ac.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 GROUP BY
       ac.owner,
       ac.table_name
 ORDER BY
       ac.table_name;
--%11F
