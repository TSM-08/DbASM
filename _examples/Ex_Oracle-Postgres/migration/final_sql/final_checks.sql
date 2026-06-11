-- This script contains the final checks to validate the consistency and completeness of the metadata collected for both source and target databases.
-- It includes checks for object counts, table and column properties, primary key definitions, foreign key constraints, index definitions, row counts, and data consistency through row hashes.
-- The results of these checks will be reflected in the final report to assess migration readiness and identify any potential migration issues.


-- Script to check count of tables between source and target
--%F01S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type = 'tables'
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F01F

-- Script to check count of sequences between source and target
--%F02S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type = 'sequences'
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F02F

-- Script to check count of indexes between source and target
--%F03S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type = 'indexes'
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F03F

-- Script to check count of constraints between source and target
--%F04S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type IN ('pkeys_constraints', 'fkeys_constraints', 
                         'check_constraints', 'unique_constraints')
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F04F

-- Script to check count of stored objects between source and target
--%F05S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type IN ('triggers', 'functions', 'procedures', 'views')
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F05F

-- Script to compare table list consistency between source and target
--%F06S
SELECT s.table_name as table_name_src,
       t.table_name as table_name_trg
  FROM src.metadata_02 s
  LEFT JOIN trg.metadata_02 t
    ON s.table_name = t.table_name
 WHERE t.table_name IS NULL;
--%F06F

-- Script to compare table properties between source and target
--%F07S
SELECT upper(s.table_name) AS table_name_src,
       upper(t.table_name) AS table_name_trg,
       s.is_partitioned AS is_partitioned_src,
       t.is_partitioned AS is_partitioned_trg,
       s.has_identity AS has_identity_src,
       t.has_identity AS has_identity_trg
  FROM src.metadata_02 s
  JOIN trg.metadata_02 t
    ON s.table_name = t.table_name
 WHERE s.is_partitioned != t.is_partitioned
    OR s.has_identity != t.has_identity;
--%F07F

-- Script to compare column list consistency between source and target for tables
--%F08S
SELECT s.table_name as table_name_src,
       s.column_name as column_name_src,
       t.table_name as table_name_trg,
       t.column_name as column_name_trg
  FROM src.metadata_03 s
  FULL JOIN trg.metadata_03 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE (s.column_name IS NULL or t.column_name IS NULL)
   AND coalesce(s.table_name, t.table_name) IN
       (SELECT table_name FROM src.metadata_02);
--%F08F

-- Script to compare column data types between source and target for tables
--%F09S
SELECT s.table_name as table_name, 
       s.column_name as column_name,
       s.type_formatted as data_type_src,
       t.type_formatted as data_type_trg
  FROM src.metadata_03 s
  JOIN trg.metadata_03 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
-- To handle replacement cases from character to boolean data type for specific columns
 WHERE 1 != ( 
       CASE
            WHEN s.type_formatted = t.type_formatted THEN 1
            WHEN s.table_name in ('purchase_orders')
                AND s.column_name = 'is_active'
                AND s.type_formatted = 'character(1)'
                AND t.type_formatted = 'boolean' THEN 1
       ELSE 0 END)
-- To handle compatible data types with different names or properties      
   AND 1 != (
       CASE 
            WHEN s.data_type = 'VARCHAR2' AND t.data_type = 'CHARACTER VARYING'
			          AND s.data_length <= t.data_length THEN 1
	          WHEN s.data_type = 'VARCHAR2' 
                AND t.data_type = 'TEXT' THEN 1
	          WHEN s.data_type = 'NUMBER' AND s.data_scale > 0 
	              AND t.data_type = 'NUMERIC' THEN 1
	          WHEN s.data_type = 'NUMBER' AND s.data_scale = 0 
	 		          AND s.data_precision > 0 AND s.data_precision <= 4
	              AND t.data_type = 'SMALLINT' THEN 1		
	          WHEN s.data_type = 'NUMBER' AND s.data_scale = 0 
	 		          AND s.data_precision > 4 AND s.data_precision < 10
	              AND t.data_type IN ('INTEGER', 'NUMERIC') THEN 1
	          WHEN s.data_type = 'NUMBER' AND COALESCE(s.data_scale, 0) = 0 
	 		          AND (s.data_precision >= 10 OR s.data_precision IS NULL)
	              AND t.data_type IN ('BIGINT', 'NUMERIC') THEN 1	
	          WHEN s.data_type IN ('TIMESTAMP(6)', 'TIMESTAMP(9)')
	 		          AND t.data_type = 'TIMESTAMP WITHOUT TIME ZONE' THEN 1
	          WHEN s.data_type = 'CLOB'
	 		          AND t.data_type = 'TEXT' THEN 1	
	          WHEN s.data_type = 'CHAR'
	 		          AND t.data_type = 'CHARACTER' THEN 1
            WHEN s.data_type = 'CHAR' AND s.data_length = 1 
	 		          AND t.data_type = 'BOOLEAN' THEN 1
	          WHEN s.data_type = 'DATE'
	 		          AND t.data_type IN ('DATE', 'TIMESTAMP WITHOUT TIME ZONE') THEN 1
	          WHEN s.data_type = 'BLOB'
	 		          AND t.data_type = 'BYTEA' THEN 1			 
	    ELSE 0 END);
--%F09F

-- Script to compare column nullability between source and target for tables
--%F10S
SELECT s.table_name AS table_name, 
       s.column_name AS column_name,
       s.is_nullable AS is_nullable_src,
       t.is_nullable AS is_nullable_trg
  FROM src.metadata_03 s
  JOIN trg.metadata_03 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE s.is_nullable != t.is_nullable;
--%F10F

-- Script to compare column default values between source and target for tables
--%F11S
SELECT s.table_name AS table_name, 
       s.column_name AS column_name,
       s.data_default AS data_default_src,
       t.data_default AS data_default_trg
       --s.data_type, t.data_type
  FROM src.metadata_03 s
  JOIN trg.metadata_03 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE 1 != 
       CASE 
            WHEN coalesce(s.data_default, '-') = coalesce(t.data_default, '-') 
                THEN 1
            WHEN lower(s.table_name) IN ('purchase_orders')
                AND lower(s.column_name) = 'is_active'
                AND s.data_default = '''Y''' AND t.data_default = 'true' 
                THEN 1
       ELSE 0 END;
--%F11F

-- Script to compare table sequence matching between source and target
--%F12S
SELECT s.table_name as table_name_src,
       s.column_name as column_name_src,
       t.table_name as table_name_trg,
       t.column_name as column_name_trg
  FROM src.metadata_04 s
  LEFT JOIN trg.metadata_04 t
    ON t.table_name = s.table_name
 WHERE t.table_name IS NULL
    OR s.column_name != t.column_name;
--%F12F

-- Script to compare sequence counts between source and target
--%F13S
SELECT seq_count_src, seq_count_trg
FROM
(
    SELECT (select count(*) 
              from src.metadata_05) as seq_count_src,
           (select count(*) 
              from trg.metadata_05) as seq_count_trg
) r
 WHERE seq_count_src != seq_count_trg;
--%F13F

-- Script to compare column max values for identity columns between source and target tables
--%F14S
SELECT s.table_name AS table_name,
       s.column_name AS column_name,
       s.max_value AS max_value_src,
       t.max_value AS max_value_trg
  FROM src.metadata_04 s
  LEFT JOIN trg.metadata_04 t
    ON s.table_name = t.table_name
   AND s.column_name = t.column_name
 WHERE s.max_value != t.max_value
    OR t.table_name IS NULL;
--%F14F

-- Script to confirm that max values in identity columns are less than sequence last_value in target
--%F15S
SELECT identity_column, sequence_name, last_value, max_value
  FROM trg.validation_17;
--%F15F

-- Script to confirm that max values in identity columns are less than sequence last_value in source
--%F16S
SELECT schema_name, table_name,
       identity_column, sequence_name, last_value, max_value
  FROM src.validation_17;
--%F16F

-- Script to compare primary key definitions between source and target for tables
--%F17S
SELECT s.table_name AS table_name_src,
       s.pk_column AS pk_column_src,
       t.table_name AS table_name_trg,
       t.pk_column AS pk_column_trg
  FROM src.metadata_06 s
  LEFT JOIN trg.metadata_06 t
    ON t.table_name = s.table_name
 WHERE s.pk_column != t.pk_column
    OR t.table_name IS NULL;
--%F17F

-- Script to compare primary key constraint status between source and target for tables
--%F18S
SELECT s.table_name AS table_name_src,
       s.pk_column AS pk_column_src,
       s.status AS status_src,
       t.status AS status_trg
  FROM src.metadata_06 s
  LEFT JOIN trg.metadata_06 t
    ON t.table_name = s.table_name
   AND s.pk_column = t.pk_column
 WHERE s.status != t.status
    OR t.table_name IS NULL;
--%F18F

-- Script to compare check constraint counts between source and target for tables
--%F19S
SELECT s.table_name as table_name_src,
       s.tot_count as tot_count_src,
       t.table_name as table_name_trg,
       t.tot_count as tot_count_trg
FROM
(
   select table_name, count(constraint_name) tot_count
     from src.metadata_07
    group by table_name
) s
LEFT JOIN
(
   select table_name, count(constraint_name) tot_count
     from trg.metadata_07
    group by table_name
) t
   ON s.table_name = t.table_name
WHERE t.table_name IS NULL
   OR s.tot_count != t.tot_count;
--%F19F

-- Script to compare foreign key definitions between source and target for tables
--%F20S
SELECT s.table_name as table_name_src,
       s.child_columns as child_columns_src,
       s.table_name as table_name_trg,
       s.child_columns as child_columns_trg
  FROM src.metadata_08 s
  LEFT JOIN trg.metadata_08 t
    ON t.table_name = s.table_name
   AND t.child_columns = s.child_columns
 WHERE t.table_name IS NULL;
--%F20F

-- Script to compare foreign key parent table/columns between source and target for tables
--%F21S
SELECT s.table_name AS table_name_src,
       s.child_columns AS child_columns_src,
       s.table_name AS table_name_trg,
       s.child_columns AS child_columns_trg
  FROM src.metadata_08 s
  LEFT JOIN trg.metadata_08 t
    ON t.table_name = s.table_name
   AND t.child_columns = s.child_columns
 WHERE t.parent_table != s.parent_table
    OR t.parent_columns != s.parent_columns
    OR t.table_name IS NULL;
--%F21F

-- Script to compare index definitions between source and target for tables
--%F22S
SELECT s.table_name AS table_name_src,
       s.index_columns AS index_columns_src,
       t.table_name AS table_name_trg,
       t.index_columns AS index_columns_trg
  FROM src.metadata_09 s
  LEFT JOIN trg.metadata_09 t
    ON s.table_name = t.table_name
   AND s.index_columns = t.index_columns
 WHERE t.table_name IS NULL;
--%F22F

-- Script to compare index properties between source and target for tables
--%F23S
SELECT s.table_name AS table_name_src,
       s.index_columns AS index_columns_src,
       s.is_unique AS is_unique_src,
       s.is_primary AS is_primary_src,
       t.table_name AS table_name_trg,
       t.index_columns AS index_columns_trg,
       t.is_unique AS is_unique_trg,
       t.is_primary AS is_primary_trg
  FROM src.metadata_09 s
  JOIN trg.metadata_09 t
    ON s.table_name = t.table_name
   AND s.index_columns = t.index_columns
 WHERE s.is_unique != t.is_unique
    OR s.is_primary != t.is_primary;
--%F23F

-- Script to compare row counts between source and target for tables
--%F24S
SELECT s.table_name AS table_name_src,
       s.row_count AS row_count_src,
       t.table_name AS table_name_trg,
       t.row_count AS row_count_trg   
  FROM src.metadata_10 s
  LEFT JOIN trg.metadata_10 t
    ON t.table_name = s.table_name
 WHERE coalesce(t.row_count, 0) != coalesce(s.row_count, 0);
--%F24F

-- Script to check for tables without primary key in target
--%F25S
SELECT schema_name, table_name, has_primary_key
  FROM trg.validation_12;
--%F25F

-- Script to compare tables without primary key between source and target
--%F26S
SELECT s.table_name AS table_name_src,
       s.has_primary_key AS has_pk_src,
       t.table_name AS table_name_trg,
       t.has_primary_key AS has_pk_trg
  FROM trg.validation_12 t
  LEFT JOIN src.validation_12 s
    ON t.table_name = s.table_name
 WHERE s.table_name IS NULL;
--%F26F

-- Script to check for duplicate primary key in target tables
--%F27S
SELECT schema_name, table_name, pk_column, pk_value, dup_count
  FROM trg.validation_13;
--%F27F

-- Script to compare tables with duplicate primary key between source and target
--%F28S
SELECT s.table_name AS table_name_src,
       s.pk_column AS pk_column_src,
       t.table_name AS table_name_trg,
       t.pk_column AS pk_column_trg
  FROM trg.validation_13 t
  LEFT JOIN src.validation_13 s
    ON t.table_name = s.table_name
   AND t.pk_column = s.pk_column
 WHERE s.table_name IS NULL OR
       coalesce(t.dup_count, 0) != coalesce(s.dup_count, 0);
--%F28F

-- Script to check for null values for not null columns in target tables
--%F29S
SELECT schema_name, table_name, column_name, null_count
  FROM trg.validation_14;
--%F29F

-- Script to compare nullability violations between source and target
--%F30S
SELECT s.table_name AS table_name_src,	
       s.column_name AS column_name_src,
       s.null_count AS null_count_src,
       t.table_name AS table_name_trg,
       t.column_name AS column_name_trg,
       t.null_count AS null_count_trg
  FROM trg.validation_14 t
  LEFT JOIN src.validation_14 s
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE s.table_name IS NULL OR
       coalesce(t.null_count, 0) != coalesce(s.null_count, 0);
--%F30F

-- Script to check for foreign key violations in target tables
--%F31S
SELECT schema_name, child_table, parent_table, join_condition, count
  FROM trg.validation_15;
--%F31F

-- Script to compare foreign key violations between source and target
--%F32S
SELECT s.child_table AS child_table_src,
       s.parent_table AS parent_table_src,
       s.join_condition AS join_condition_src,
       s.count AS count_src,
       t.child_table AS child_table_trg,
       t.parent_table AS parent_table_trg,
       t.join_condition AS join_condition_trg,
       t.count AS count_trg
  FROM trg.validation_15 t
  LEFT JOIN src.validation_15 s	
    ON t.child_table = s.child_table
   AND t.parent_table = s.parent_table	
   AND t.join_condition = s.join_condition
 WHERE s.child_table IS NULL
    OR coalesce(t.count, 0) != coalesce(s.count, 0);
--%F32F

-- Script to check for disabled foreign key constraints in target tables
--%F33S
SELECT schema_name, table_name,
       constraint_name, referenced_schema, referenced_table
  FROM trg.validation_16;
--%F33F

-- Script to check for disabled foreign key constraints in source tables
--%F34S
SELECT t.schema_name, t.table_name,
       t.constraint_name, t.referenced_schema, t.referenced_table
  FROM trg.validation_16 t
  LEFT JOIN src.validation_16 s
    ON s.schema_name = t.schema_name
   AND s.table_name = t.table_name
   AND s.constraint_name = t.constraint_name
   AND s.referenced_schema = t.referenced_schema
   AND s.referenced_table = t.referenced_table
 WHERE s.table_name IS NULL;  
--%F34F

-- Script to compare row hashes between source and target for tables
--%F35S
SELECT s.table_name, 
       s.pk_value, 
       s.row_hash as row_hash_src,
       t.row_hash as row_hash_trg
  FROM src.metadata_11 s 
  LEFT JOIN trg.metadata_11 t
    ON s.table_name = t.table_name AND s.pk_value = t.pk_value 
 WHERE s.row_hash != t.row_hash 
    OR t.pk_value IS NULL;
--%F35F