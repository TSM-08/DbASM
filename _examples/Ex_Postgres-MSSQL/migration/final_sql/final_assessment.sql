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


-- Script to compare column name consistency across databases
--%F08S
SELECT table_name, column_name
FROM src.metadata_04
EXCEPT
SELECT table_name, column_name
FROM trg.metadata_04;
--%F08F

-- Script to compare column types between source and target
--%F09S
SELECT
    s.table_name,
    s.column_name,
    s.type_formatted AS data_type_src,
    t.type_formatted AS data_type_trg
FROM src.metadata_04 s
JOIN trg.metadata_04 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
WHERE 1 != (
    CASE
        -- STRING FAMILY (varchar/nvarchar/text) + length check
        WHEN LOWER(s.data_type) IN ('character varying','varchar','text')
         AND LOWER(t.data_type) IN ('varchar','nvarchar')
         AND (
                -- TEXT -> only MAX
                (LOWER(s.data_type) = 'text' AND t.data_length = -1)

                OR (
                    LOWER(s.data_type) IN ('character varying','varchar')
                    AND (
                        t.data_length = -1
                        OR ISNULL(s.data_length,0) <= ISNULL(t.data_length,0)
                    )
                )
             )
        THEN 1

        -- CHAR (exact length)
        WHEN LOWER(s.data_type) = 'character'
         AND LOWER(t.data_type) IN ('char','nchar')
         AND ISNULL(s.data_length,0) = ISNULL(t.data_length,0)
        THEN 1

        -- BOOLEAN -> BIT / CHAR(1)
        WHEN LOWER(s.data_type) = 'boolean'
         AND (
                LOWER(t.data_type) = 'bit'
                OR (LOWER(t.data_type) = 'char' AND t.data_length = 1)
             )
        THEN 1

        -- BIGINT (ignore fake precision)
        WHEN LOWER(s.data_type) = 'bigint'
         AND LOWER(t.data_type) = 'bigint'
        THEN 1

        -- INTEGER FAMILY
        WHEN LOWER(s.data_type) = 'integer'
         AND LOWER(t.data_type) IN ('int','bigint')
        THEN 1

        WHEN LOWER(s.data_type) = 'smallint'
         AND LOWER(t.data_type) IN ('smallint','int','bigint')
        THEN 1

        -- NUMERIC / DECIMAL
        WHEN LOWER(s.data_type) = 'numeric'
         AND LOWER(t.data_type) IN ('numeric','decimal')
         AND (
                s.data_precision IS NULL
                OR (
                    ISNULL(s.data_precision,0) <= ISNULL(t.data_precision,0)
                    AND ISNULL(s.data_scale,0) <= ISNULL(t.data_scale,0)
                )
             )
        THEN 1

        -- TIMESTAMP
        WHEN LOWER(s.data_type) = 'timestamp without time zone'
         AND LOWER(t.data_type) IN ('datetime','datetime2')
        THEN 1

        -- TIMESTAMPTZ
        WHEN LOWER(s.data_type) = 'timestamp with time zone'
         AND LOWER(t.data_type) = 'datetimeoffset'
        THEN 1

        -- DATE
        WHEN LOWER(s.data_type) = 'date'
         AND LOWER(t.data_type) IN ('date','datetime','datetime2')
        THEN 1

        -- BYTEA
        WHEN LOWER(s.data_type) = 'bytea'
         AND LOWER(t.data_type) = 'varbinary'
        THEN 1

    ELSE 0
    END
)
ORDER BY s.table_name, s.column_name;
--%F09F

-- Script to compare column nullability between source and target
--%F10S
SELECT s.table_name AS table_name,
       s.column_name AS column_name,
       s.is_nullable AS is_nullable_src,
       t.is_nullable AS is_nullable_trg
  FROM src.metadata_04 s
  JOIN trg.metadata_04 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE s.is_nullable != t.is_nullable;
--%F10F

-- Script to compare column default values between source and target
--%F11S
SELECT s.table_name AS table_name,
       s.column_name AS column_name,
       s.data_default AS data_default_src,
       t.data_default AS data_default_trg
  FROM src.metadata_04 s
  JOIN trg.metadata_04 t
    ON t.table_name = s.table_name
   AND t.column_name = s.column_name
 WHERE 0 = CASE
            WHEN COALESCE(s.data_default, '-') = COALESCE(t.data_default, '-') THEN 1
            -- Handle common default value differences, e.g., CURRENT_TIMESTAMP vs sysdatetime()
            WHEN s.data_default = 'CURRENT_TIMESTAMP' AND t.data_default = 'sysdatetime()' THEN 1
            -- Special handling for purchase_orders.is_active column where 'Y' in source maps to 'true' in target
            WHEN s.table_name = 'purchase_orders'
             AND s.column_name = 'is_active'
             AND t.data_default = '''Y'''
             AND s.data_default = 'true'
            THEN 1
            ELSE 0
          END;
--%F11F

-- Script to compare row counts between source and target
--%F12S
SELECT s.table_name AS table_name,
       s.row_count AS row_count_src,
       t.row_count AS row_count_trg
  FROM src.metadata_10 s
  JOIN trg.metadata_10 t
    ON s.table_name = t.table_name
 WHERE s.row_count <> t.row_count;
--%F12F

-- Script to compare row hashes between source and target
--%F13S
SELECT s.table_name AS table_name,
       s.pk_value AS pk_value,
       s.row_hash AS row_hash_src,
       t.row_hash AS row_hash_trg
  FROM src.metadata_11 s
  LEFT JOIN trg.metadata_11 t
    ON s.table_name = t.table_name
   AND s.pk_value = t.pk_value
 WHERE s.row_hash <> t.row_hash
    OR t.row_hash IS NULL;
--%F13F