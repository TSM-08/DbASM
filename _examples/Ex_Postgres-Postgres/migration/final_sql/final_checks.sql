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
 WHERE s.object_type in ('pkeys_constraints', 'fkeys_constraints', 
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
 WHERE s.object_type in ('triggers', 'functions', 'procedures', 'views')
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F05F

-- Script to compare table list consistency between source and target
--%F06S
select s.table_name as table_name_src,
       t.table_name as table_name_trg
  from src.metadata_02 s
  full join trg.metadata_02 t
    on s.table_name = t.table_name
 where t.table_name is null 
    or s.table_name is null;
--%F06F

-- Script to compare table properties between source and target
--%F07S
select s.table_name as table_name_src,
       t.table_name as table_name_trg,
       s.is_partitioned as is_partitioned_src, 
       t.is_partitioned as is_partitioned_trg,
       s.has_identity as has_identity_src, 
       t.has_identity as has_identity_trg
  from src.metadata_02 s
 inner join trg.metadata_02 t
    on s.table_name = t.table_name 
 where s.is_partitioned != t.is_partitioned
    or s.has_identity != t.has_identity;
--%F07F

-- Script to compare column list consistency between source and target for tables
--%F08S
select s.table_name as table_name_src, 
       s.column_name as column_name_src,
       t.table_name as table_name_trg, 
       t.column_name as column_name_trg
  from src.metadata_03 s
  full join trg.metadata_03 t
    on t.table_name = s.table_name
   and t.column_name = s.column_name
 where (s.column_name is null or t.column_name is null)
   and coalesce(s.table_name, t.table_name) in 
       (select table_name from src.metadata_02);
--%F08F

-- Script to compare column data types between source and target for tables
--%F09S
select s.table_name as table_name, 
       s.column_name as column_name,
       s.type_formatted as data_type_src,
       t.type_formatted as data_type_trg
  from src.metadata_03 s
 inner join trg.metadata_03 t
    on t.table_name = s.table_name
   and t.column_name = s.column_name
 where 0 = case 
           when s.type_formatted = t.type_formatted 
                then 1
           when s.table_name in ('purchase_orders')
                and s.column_name = 'is_active'
                and s.type_formatted = 'character(1)'
                and t.type_formatted = 'boolean' 
                then 1
       else 0 end ;
--%F09F

-- Script to compare column nullability between source and target for tables
--%F10S
select s.table_name as table_name, 
       s.column_name as column_name,
       s.is_nullable as is_nullable_src,
       t.is_nullable as is_nullable_trg
  from src.metadata_03 s
 inner join trg.metadata_03 t
    on t.table_name = s.table_name
   and t.column_name = s.column_name
 where s.is_nullable != t.is_nullable;
--%F10F

-- Script to compare column default values between source and target for tables
--%F11S
select s.table_name as table_name, 
       s.column_name as column_name,
       s.data_default as data_default_src,
       t.data_default as data_default_trg
       --s.data_type, t.data_type
 from src.metadata_03 s
inner join trg.metadata_03 t
   on t.table_name = s.table_name
  and t.column_name = s.column_name
where 0 = case 
          when coalesce(s.data_default, '-') = coalesce(t.data_default, '-') 
               then 1
          when s.table_name in ('purchase_orders')
               and s.column_name = 'is_active'
               and s.data_default = '''Y''' and t.data_default = 'true' 
               then 1
      else 0 end; 
--%F11F

-- Script to compare table sequence matching between source and target
--%F12S
select s.table_name as table_name_src,
       s.column_name as column_name_src,
       t.table_name as table_name_trg,
       t.column_name as column_name_trg
  from src.metadata_04 s
  full join trg.metadata_04 t
    on t.table_name = s.table_name
 where s.table_name is null
    or t.table_name is null
    or s.column_name != t.column_name;
--%F12F

-- Script to compare sequence counts between source and target
--%F13S
select seq_count_src, seq_count_trg
from
(
   select (select count(*) 
             from src.metadata_05) as seq_count_src,
          (select count(*) 
             from trg.metadata_05) as seq_count_trg
) r
where seq_count_src != seq_count_trg;
--%F13F

-- Script to compare column max values for identity columns between source and target tables
--%F14S
select s.table_name as table_name,
       s.column_name as column_name,
       s.max_value as max_value_src,
       t.max_value as max_value_trg
  from src.metadata_04 s
  join trg.metadata_04 t
    on s.table_name = t.table_name
   and s.column_name = t.column_name
 where s.max_value != t.max_value;
--%F14F

-- Script to confirm that max values in identity columns are less than sequence last_value in target
--%F15S
select schema_name, table_name,
       identity_column, sequence_name, last_value, max_value
  from trg.validation_17;
--%F15F

-- Script to confirm that max values in identity columns are less than sequence last_value in source
--%F16S
select schema_name, table_name,
       identity_column, sequence_name, last_value, max_value
  from src.validation_17;
--%F16F

-- Script to compare primary key definitions between source and target for tables
--%F17S
select s.table_name as table_name_src,
       s.pk_column as pk_column_src,
       t.table_name as table_name_trg,
       t.pk_column as pk_column_trg
  from src.metadata_06 s
 inner join trg.metadata_06 t
    on t.table_name = s.table_name
 where s.pk_column != t.pk_column;
--%F17F

-- Script to compare primary key constraint status between source and target for tables
--%F18S
select s.table_name as table_name_src,
       s.pk_column as pk_column_src,
       s.status as status_src,
       t.status as status_trg
  from src.metadata_06 s
 inner join trg.metadata_06 t
    on t.table_name = s.table_name
   and s.pk_column = t.pk_column
 where s.status != t.status;
--%F18F

-- Script to compare check constraint counts between source and target for tables
--%F19S
select s.table_name as table_name_src,
       s.tot_count as tot_count_src,
       t.table_name as table_name_trg,
       t.tot_count as tot_count_trg
from
(
   select table_name, count(constraint_name) tot_count
     from src.metadata_07
    group by table_name
) s
full outer join
(
   select table_name, count(constraint_name) tot_count
     from trg.metadata_07
    group by table_name
) t
on s.table_name = t.table_name
where s.table_name is null or t.table_name is null
or s.tot_count != t.tot_count;
--%F19F

-- Script to compare foreign key definitions between source and target for tables
--%F20S
select s.table_name as table_name_src,
       s.child_columns as child_columns_src,
       s.table_name as table_name_trg,
       s.child_columns as child_columns_trg
  from src.metadata_08 s
  left join trg.metadata_08 t
    on t.table_name = s.table_name
   and t.child_columns = s.child_columns
 where t.table_name is null;
--%F20F

-- Script to compare foreign key parent table/columns between source and target for tables
--%F21S
select s.table_name as table_name_src,
       s.child_columns as child_columns_src,
       s.table_name as table_name_trg,
       s.child_columns as child_columns_trg
  from src.metadata_08 s
 inner join trg.metadata_08 t
    on t.table_name = s.table_name
   and t.child_columns = s.child_columns
 where t.parent_table != s.parent_table or
       t.parent_columns != s.parent_columns;
--%F21F

-- Script to compare index definitions between source and target for tables
--%F22S
select s.table_name as table_name_src,
       s.index_columns as index_columns_src,
       t.table_name as table_name_trg,
       t.index_columns as index_columns_trg
  from src.metadata_09 s
  left join trg.metadata_09 t
    on s.table_name = t.table_name
   and s.index_columns = t.index_columns
 where t.table_name is null;
--%F22F

-- Script to compare index properties between source and target for tables
--%F23S
select s.table_name as table_name_src,
       s.index_columns as index_columns_src,
       s.is_unique as is_unique_src,
       s.is_primary as is_primary_src,
       t.table_name as table_name_trg,
       t.index_columns as index_columns_trg,
       t.is_unique as is_unique_trg,
       t.is_primary as is_primary_trg
  from src.metadata_09 s
 inner join trg.metadata_09 t
    on s.table_name = t.table_name
   and s.index_columns = t.index_columns
 where t.table_name is null
    or s.is_unique != t.is_unique
    or s.is_primary != t.is_primary;
--%F23F

-- Script to compare row counts between source and target for tables
--%F24S
select s.table_name as table_name_src,
       s.row_count as row_count_src,
       t.table_name as table_name_trg,
       t.row_count as row_count_trg   
  from src.metadata_10 s
  left join trg.metadata_10 t
    on t.table_name = s.table_name
 where coalesce(t.row_count, 0) != coalesce(s.row_count, 0);
--%F24F

-- Script to check for tables without primary key in target
--%F25S
select schema_name, table_name, has_primary_key
  from trg.validation_12;
--%F25F

-- Script to compare tables without primary key between source and target
--%F26S
select s.table_name as table_name_src,
       s.has_primary_key as has_pk_src,
       t.table_name as table_name_trg,
       t.has_primary_key as has_pk_trg
  from trg.validation_12 t
  left join src.validation_12 s
    on t.table_name = s.table_name
 where s.table_name is null;
--%F26F

-- Script to check for duplicate primary key in target tables
--%F27S
select schema_name, table_name, pk_column, pk_value, dup_count
  from trg.validation_13;
--%F27F

-- Script to compare tables with duplicate primary key between source and target
--%F28S
select s.table_name as table_name_src,
       s.pk_column as pk_column_src,
       t.table_name as table_name_trg,
       t.pk_column as pk_column_trg
  from trg.validation_13 t
  left outer join src.validation_13 s
    on t.table_name = s.table_name
   and t.pk_column = s.pk_column
 where s.table_name is null or
       coalesce(t.dup_count, 0) != coalesce(s.dup_count, 0);
--%F28F

-- Script to check for null values for not null columns in target tables
--%F29S
select schema_name, table_name, column_name, null_count
  from trg.validation_14;
--%F29F

-- Script to compare nullability violations between source and target
--%F30S
select s.table_name as table_name_src,	
       s.column_name as column_name_src,
       s.null_count as null_count_src,
       t.table_name as table_name_trg,
       t.column_name as column_name_trg,
       t.null_count as null_count_trg
  from trg.validation_14 t
  left join src.validation_14 s
    on t.table_name = s.table_name
   and t.column_name = s.column_name
 where s.table_name is null or
       coalesce(t.null_count, 0) != coalesce(s.null_count, 0);
--%F30F

-- Script to check for foreign key violations in target tables
--%F31S
select schema_name, child_table, parent_table, join_condition, count
  from trg.validation_15;
--%F31F

-- Script to compare foreign key violations between source and target
--%F32S
select s.child_table as child_table_src,
       s.parent_table as parent_table_src,
       s.join_condition as join_condition_src,
       s.count as count_src,
       t.child_table as child_table_trg,
       t.parent_table as parent_table_trg,
       t.join_condition as join_condition_trg,
       t.count as count_trg
  from trg.validation_15 t
  left join src.validation_15 s	
    on t.child_table = s.child_table
   and t.parent_table = s.parent_table	
   and t.join_condition = s.join_condition
 where s.child_table is null
    or coalesce(t.count, 0) != coalesce(s.count, 0);
--%F32F

-- Script to check for disabled foreign key constraints in target tables
--%F33S
select schema_name, table_name,
       constraint_name, referenced_schema, referenced_table
  from trg.validation_16;
--%F33F

-- Script to check for disabled foreign key constraints in source tables
--%F34S
select t.schema_name, t.table_name,
       t.constraint_name, t.referenced_schema, t.referenced_table
  from trg.validation_16 t
  left join src.validation_16 s
    on s.schema_name = t.schema_name
   and s.table_name = t.table_name
   and s.constraint_name = t.constraint_name
   and s.referenced_schema = t.referenced_schema
   and s.referenced_table = t.referenced_table
 where s.table_name is null;  
--%F34F

-- Script to compare row hashes between source and target for tables
--%F35S
select s.table_name, 
       s.pk_value, 
       s.row_hash as row_hash_src,
       t.row_hash as row_hash_trg
  from src.metadata_11 s 
  left join trg.metadata_11 t
    on s.table_name = t.table_name and s.pk_value = t.pk_value 
 where s.row_hash != t.row_hash or t.pk_value is null;
--%F35F