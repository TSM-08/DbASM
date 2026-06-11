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

-- Script to check count of indexes between source and target
--%F02S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type = 'indexes'
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F02F

-- Script to check count of constraints between source and target
--%F03S
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
--%F03F

-- Script to check count of stored objects between source and target
--%F04S
SELECT s.object_type,
       s.object_count AS object_count_src,
       t.object_count AS object_count_trg
  FROM src.metadata_01 s
  LEFT JOIN trg.metadata_01 t
    ON s.object_type = t.object_type
 WHERE s.object_type IN ('triggers', 'functions', 'procedures', 'views')
   AND (t.object_type IS NULL
    OR s.object_count <> t.object_count);
--%F04F

-- Script to compare table list consistency between source and target
--%F05S
SELECT s.table_name as table_name_src,
       t.table_name as table_name_trg
  FROM src.metadata_02 s
  LEFT JOIN trg.metadata_02 t
    ON s.table_name = t.table_name
 WHERE t.table_name IS NULL;
--%F05F

-- Script to compare table properties between source and target
--%F06S
SELECT s.table_name AS table_name_src,
       t.table_name AS table_name_trg,
       s.is_partitioned AS is_partitioned_src,
       t.is_partitioned AS is_partitioned_trg,
       s.has_identity AS has_identity_src,
       t.has_identity AS has_identity_trg
  FROM src.metadata_02 s
  JOIN trg.metadata_02 t
    ON s.table_name = t.table_name
 WHERE s.is_partitioned != t.is_partitioned
    OR s.has_identity != t.has_identity;
--%F06F

-- Script to compare column count per table between source and target
--%F07S
SELECT s.table_name AS table_name_src,
       t.table_name AS table_name_trg,
       s.column_count AS column_count_src,
       t.column_count AS column_count_trg
  FROM src.metadata_03 s
  LEFT JOIN trg.metadata_03 t
    ON s.table_name = t.table_name
 WHERE t.table_name IS NULL
    OR s.column_count <> t.column_count;
--%F07F
