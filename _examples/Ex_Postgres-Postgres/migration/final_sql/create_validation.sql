-- This script creates the necessary tables to store validation results for various checks 
-- performed during database migration assessment. 
-- Each table corresponds to a specific validation check.

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS <schema_name>;
/

-- idc_table_pk_check
DROP TABLE IF EXISTS <schema_name>.validation_12;
CREATE TABLE <schema_name>.validation_12 (
    schema_name      TEXT,
    table_name       TEXT,
    has_primary_key  TEXT  -- 'YES' or 'NO'
);
/

-- idc_pkey_check_sql
DROP TABLE IF EXISTS <schema_name>.validation_13;
CREATE TABLE <schema_name>.validation_13 (
    schema_name   TEXT,
    table_name    TEXT,
    pk_column     TEXT,
    pk_value      TEXT,
    dup_count     BIGINT  -- Count duplicates in primary key columns
);
/

-- idc_not_null_check_sql
DROP TABLE IF EXISTS <schema_name>.validation_14;
CREATE TABLE <schema_name>.validation_14 (
    schema_name   TEXT,
    table_name    TEXT,
    column_name   TEXT,
    null_count    BIGINT  -- Count NULLs in NOT NULL columns
);
/

-- idc_fk_check_sql
DROP TABLE IF EXISTS <schema_name>.validation_15;
CREATE TABLE <schema_name>.validation_15 (
    schema_name     TEXT,
    child_table     TEXT,
    parent_table    TEXT,
    join_condition  TEXT,  -- e.g., "c.id = p.id"
    count           BIGINT  -- Count of orphaned rows
);
/

-- idc_disabled_fk_constraints
DROP TABLE IF EXISTS <schema_name>.validation_16;
CREATE TABLE <schema_name>.validation_16 (
    schema_name       TEXT,
    table_name        TEXT,
    constraint_name   TEXT,
    referenced_schema TEXT,
    referenced_table  TEXT
);
/

-- idc_identity_max_sql
DROP TABLE IF EXISTS <schema_name>.validation_17;
CREATE TABLE <schema_name>.validation_17 (
    schema_name     TEXT,
    table_name      TEXT,
    identity_column TEXT,
    sequence_name   TEXT,
    last_value      BIGINT,
    max_value       BIGINT  -- Current max value in the column
);
/