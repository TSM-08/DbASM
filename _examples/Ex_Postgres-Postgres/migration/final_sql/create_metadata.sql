-- This script creates the necessary tables to store metadata and cross-checking results 
-- for database migration assessment.
-- Each table corresponds to a specific aspect of the database metadata or cross-checking results.

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS <schema_name>;
DROP TABLE IF EXISTS <schema_name>.cross_checking;
CREATE TABLE <schema_name>.cross_checking (
    issue_code     TEXT,
    issue_type     TEXT,
    title          TEXT,
    message        TEXT,
    direction      TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_01;
CREATE TABLE <schema_name>.metadata_01 (
    schema_name     TEXT,
    object_type     TEXT,
    object_count    BIGINT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_02;
CREATE TABLE <schema_name>.metadata_02 (
    schema_name     TEXT,
    table_name      TEXT,
    orig_tabname    TEXT,
    is_partitioned  TEXT,
    has_identity    TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_03;
CREATE TABLE <schema_name>.metadata_03 (
    schema_name     TEXT,
    table_name      TEXT,
    column_name     TEXT,
    orig_colname    TEXT,
    column_pos      INTEGER,
    data_type       TEXT,
    data_length     INTEGER,
    data_precision  INTEGER,
    data_scale      INTEGER,
    type_formatted  TEXT,
    is_nullable     TEXT,
    data_default    TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_04;
CREATE TABLE <schema_name>.metadata_04 (
    schema_name    TEXT,
    table_name     TEXT,
    column_name    TEXT,
    sequence_name  TEXT,
    max_value      BIGINT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_05;
CREATE TABLE <schema_name>.metadata_05 (
    schema_name    TEXT,
    sequence_name  TEXT,
    current_value  BIGINT,
    start_value    BIGINT,
    min_value      NUMERIC,
    max_value      NUMERIC,
    increment_by   BIGINT,
    cycle_flag     TEXT,
    cache_size     BIGINT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_06;
CREATE TABLE <schema_name>.metadata_06 (
    schema_name      TEXT,
    table_name       TEXT,
    constraint_name  TEXT,
    pk_column        TEXT,
    status           TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_07;
CREATE TABLE <schema_name>.metadata_07 (
    schema_name      TEXT,
    table_name       TEXT,
    constraint_name  TEXT,
    definition       TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_08;
CREATE TABLE <schema_name>.metadata_08 (
    schema_name      TEXT,
    table_name       TEXT,
    constraint_name  TEXT,
    child_columns    TEXT,
    parent_schema    TEXT,
    parent_table     TEXT,
    parent_columns   TEXT,
    delete_rule      TEXT,
    status           TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_09;
CREATE TABLE <schema_name>.metadata_09 (
    schema_name    TEXT,
    table_name     TEXT,
    index_name     TEXT,
    is_unique      TEXT,
    is_primary     TEXT,
    index_columns  TEXT,
    index_type     TEXT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_10;
CREATE TABLE <schema_name>.metadata_10 (
    schema_name  TEXT,
    table_name   TEXT,
    row_count    BIGINT
);
/

DROP TABLE IF EXISTS <schema_name>.metadata_11;
CREATE TABLE <schema_name>.metadata_11 (
    schema_name  TEXT,
    table_name   TEXT,
    pk_col       TEXT,
    pk_value     TEXT,
    row_hash     TEXT
);
/