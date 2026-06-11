-- Script to check if all tables in the IDC schema have a primary key
--%12S
SELECT t.owner AS schema_name,
       t.table_name  AS table_name,
       CASE
       WHEN pk.constraint_name IS NOT NULL THEN 'YES' ELSE 'NO'
       END AS has_primary_key
  FROM all_tables t
  LEFT JOIN (
       SELECT ac.owner, ac.table_name, ac.constraint_name
         FROM all_constraints ac
        WHERE ac.constraint_type = 'P') pk
    ON t.owner = pk.owner
   AND t.table_name = pk.table_name
 WHERE t.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
   AND pk.constraint_name IS NULL    -- only tables WITHOUT PK
 ORDER BY t.table_name ASC;
--%12F

-- Script to generate SQL queries that check for primary key duplicates for each table in the IDC schema
--%13S
--#SQL#
SELECT 'SELECT '
       || '''' || ac.owner || ''' AS schema_name, '
       || '''' || ac.table_name || ''' AS table_name, '
       || ''''
       || LISTAGG(acc.column_name, '|')
             WITHIN GROUP (ORDER BY acc.position)
       || ''' AS pk_column, '
       || LISTAGG('TO_CHAR(t.' || DBMS_ASSERT.ENQUOTE_NAME(acc.column_name) || ')',
               ' || ''|'' || '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ' AS pk_value, '
       || 'COUNT(*) AS dup_count '
       || 'FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(ac.owner)
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(ac.table_name)
       || ' t '
       || 'GROUP BY '
       || LISTAGG('t.' || DBMS_ASSERT.ENQUOTE_NAME(acc.column_name), ', '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ' HAVING COUNT(*) > 1'
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
 GROUP BY ac.owner, ac.table_name
 ORDER BY ac.table_name ASC;
--%13F

-- Script to generate SQL queries that check for NULLs in NOT NULL columns for each table in the IDC schema
--%14S
--#SQL#
SELECT 'SELECT '
       || '''' || c.owner || ''' AS schema_name, '
       || '''' || c.table_name || ''' AS table_name, '
       || '''' || c.column_name || ''' AS column_name, '
       || 'COUNT(*) AS null_count '
       || 'FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(c.owner)
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(c.table_name)
       || ' t '
       || 'WHERE t.'
       || DBMS_ASSERT.ENQUOTE_NAME(c.column_name)
       || ' IS NULL '
       || 'HAVING COUNT(*) > 0'
       AS sql
  FROM all_tab_columns c
  JOIN all_tables t
    ON t.owner = c.owner
   AND t.table_name = c.table_name
 WHERE c.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
   AND c.nullable = 'N'
 ORDER BY c.table_name ASC, c.column_name ASC;
--%14F

-- Script to generate SQL queries that check for foreign key constraints in the IDC schema
--%15S
--#SQL#
SELECT 'SELECT '
       || '''' || fk.owner || ''' AS schema_name, '
       || '''' || fk.table_name || ''' AS child_table, '
       || '''' || pk.table_name || ''' AS parent_table, '
       || ''''
       || LISTAGG('c.' || acc.column_name || ' = p.' || pcc.column_name, ' AND '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ''' AS join_condition, '
       || 'COUNT(*) AS count '
       || 'FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(fk.owner)
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(fk.table_name)
       || ' c '
       || 'WHERE '
       || LISTAGG('c.' || DBMS_ASSERT.ENQUOTE_NAME(acc.column_name) || ' IS NOT NULL', ' AND '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ' AND NOT EXISTS ('
       || 'SELECT 1 FROM '
       || DBMS_ASSERT.ENQUOTE_NAME(pk.owner)
       || '.'
       || DBMS_ASSERT.ENQUOTE_NAME(pk.table_name)
       || ' p WHERE '
       || LISTAGG('c.' || DBMS_ASSERT.ENQUOTE_NAME(acc.column_name)
       || ' = p.' || DBMS_ASSERT.ENQUOTE_NAME(pcc.column_name), ' AND '
           ) WITHIN GROUP (ORDER BY acc.position)
       || ') HAVING COUNT(*) > 0'
       AS sql
  FROM all_constraints fk
  JOIN all_cons_columns acc
    ON fk.owner = acc.owner
   AND fk.constraint_name = acc.constraint_name
  JOIN all_constraints pk
    ON fk.r_owner = pk.owner
   AND fk.r_constraint_name = pk.constraint_name
  JOIN all_cons_columns pcc
    ON pk.owner = pcc.owner
   AND pk.constraint_name = pcc.constraint_name
   AND acc.position = pcc.position
  JOIN all_tables ct
    ON ct.owner = fk.owner
   AND ct.table_name = fk.table_name
  JOIN all_tables pt
    ON pt.owner = pk.owner
   AND pt.table_name = pk.table_name
 WHERE fk.constraint_type = 'R'
   AND fk.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
 GROUP BY
       fk.owner,
       fk.table_name,
       pk.owner,
       pk.table_name,
       fk.constraint_name
 ORDER BY
       fk.table_name ASC,
       pk.table_name ASC;
--%15F

-- Script to find disabled foreign key constraints in the IDC schema
--%16S
SELECT
    fk.owner        AS schema_name,
    fk.table_name   AS table_name,
    fk.constraint_name,
    pk.owner        AS referenced_schema,
    pk.table_name   AS referenced_table,
    fk.status,
    CASE WHEN fk.validated = 'VALIDATED' THEN 'YES' ELSE 'NO' END AS validated
FROM all_constraints fk
JOIN all_constraints pk
    ON fk.r_owner = pk.owner
   AND fk.r_constraint_name = pk.constraint_name
JOIN all_tables ct
    ON ct.owner = fk.owner
   AND ct.table_name = fk.table_name
   AND ct.dropped = 'NO'                 -- exclude recycle bin child tables
JOIN all_tables pt
    ON pt.owner = pk.owner
   AND pt.table_name = pk.table_name
   AND pt.dropped = 'NO'                 -- exclude recycle bin parent tables
WHERE fk.constraint_type = 'R'           -- foreign keys
  AND fk.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
  AND (
        fk.validated = 'NOT VALIDATED'   -- NOVALIDATE (PG: NOT VALID)
     OR fk.status    = 'DISABLED'        -- реально отключён
      )
ORDER BY
    fk.owner ASC,
    fk.table_name ASC,
    fk.constraint_name ASC;
--%16F

-- Script to generate SQL queries to find identity columns where the sequence last_value is less than the max value in the column
--%17S
--#SQL#
SELECT
    'SELECT '''
        || UPPER(t.owner) || ''' AS schema_name, '''
        || UPPER(t.table_name) || ''' AS table_name, '''
        || UPPER(ic.column_name) || ''' AS identity_column, '''
        || seq.sequence_name || ''' AS sequence_name, '
        || seq.last_number || ' AS last_value, '
        || 'NVL(MAX("' || ic.column_name || '"), 0) AS max_value '
        || 'FROM "' || t.owner || '"."' || t.table_name || '" '
        || 'HAVING NVL(MAX("' || ic.column_name || '"), 0) > '
        || seq.last_number
        AS sql
FROM all_tables t
JOIN all_tab_identity_cols ic
  ON t.owner = ic.owner
 AND t.table_name = ic.table_name
JOIN all_objects obj
  ON ic.owner = obj.owner
 AND ic.table_name = obj.object_name
 AND obj.object_type = 'TABLE'
JOIN all_sequences seq
  ON seq.sequence_owner = ic.owner
 AND seq.sequence_name = 'ISEQ$$_' || obj.object_id
WHERE t.owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')
  AND t.dropped = 'NO'
ORDER BY
    t.table_name ASC,
    ic.column_name ASC;
--%17F