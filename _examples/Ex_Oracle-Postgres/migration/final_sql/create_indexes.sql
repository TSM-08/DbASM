-- Essential indexes for final_check.sql performance
-- Apply to both src and trg schemas

-- For metadata_02 (queries 17, 18) - table comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_02_table_name ON src.metadata_02 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_02_table_name ON trg.metadata_02 (table_name);

-- For metadata_03 (queries 19, 20, 21, 22) - column comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_03_table_column ON src.metadata_03 (table_name, column_name);
CREATE INDEX IF NOT EXISTS idx_metadata_03_table_column ON trg.metadata_03 (table_name, column_name);

-- For metadata_04 (query 23, 25) - sequence table matching
CREATE INDEX IF NOT EXISTS idx_metadata_04_table_name ON src.metadata_04 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_04_table_name ON trg.metadata_04 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_04_sequence_name ON src.metadata_04 (sequence_name);
CREATE INDEX IF NOT EXISTS idx_metadata_04_sequence_name ON trg.metadata_04 (sequence_name);

-- For metadata_05 (queries 24, 25) - sequence counts and values
CREATE INDEX IF NOT EXISTS idx_metadata_05_sequence_name ON src.metadata_05 (sequence_name);
CREATE INDEX IF NOT EXISTS idx_metadata_05_sequence_name ON trg.metadata_05 (sequence_name);

-- For metadata_06 (queries 26, 27) - primary key comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_06_table_name ON src.metadata_06 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_06_table_name ON trg.metadata_06 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_06_table_pk ON src.metadata_06 (table_name, pk_column);
CREATE INDEX IF NOT EXISTS idx_metadata_06_table_pk ON trg.metadata_06 (table_name, pk_column);

-- For metadata_07 (query 28) - check constraint counts
CREATE INDEX IF NOT EXISTS idx_metadata_07_table_name ON src.metadata_07 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_07_table_name ON trg.metadata_07 (table_name);

-- For metadata_08 (queries 29, 30) - foreign key comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_08_table_child ON src.metadata_08 (table_name, child_columns);
CREATE INDEX IF NOT EXISTS idx_metadata_08_table_child ON trg.metadata_08 (table_name, child_columns);

-- For metadata_09 (index comparisons - referenced in comments)
CREATE INDEX IF NOT EXISTS idx_metadata_09_table_columns ON src.metadata_09 (table_name, index_columns);
CREATE INDEX IF NOT EXISTS idx_metadata_09_table_columns ON trg.metadata_09 (table_name, index_columns);

-- For metadata_10 (query 31) - row count comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_10_table_name ON src.metadata_10 (table_name);
CREATE INDEX IF NOT EXISTS idx_metadata_10_table_name ON trg.metadata_10 (table_name);

-- For metadata_11 (query 40) - MOST CRITICAL - row hash comparisons
CREATE INDEX IF NOT EXISTS idx_metadata_11_table_pk ON src.metadata_11 (table_name, pk_value);
CREATE INDEX IF NOT EXISTS idx_metadata_11_table_pk ON trg.metadata_11 (table_name, pk_value);

-- For validation tables (queries 32-39) - TARGET SCHEMA ONLY
CREATE INDEX IF NOT EXISTS idx_validation_12_table ON trg.validation_12 (table_name);
CREATE INDEX IF NOT EXISTS idx_validation_12_table ON src.validation_12 (table_name);

CREATE INDEX IF NOT EXISTS idx_validation_13_table_pk ON trg.validation_13 (table_name, pk_column);
CREATE INDEX IF NOT EXISTS idx_validation_13_table_pk ON src.validation_13 (table_name, pk_column);

CREATE INDEX IF NOT EXISTS idx_validation_14_table_column ON trg.validation_14 (table_name, column_name);
CREATE INDEX IF NOT EXISTS idx_validation_14_table_column ON src.validation_14 (table_name, column_name);

CREATE INDEX IF NOT EXISTS idx_validation_15_child_parent 
ON trg.validation_15 (child_table, parent_table, join_condition);
CREATE INDEX IF NOT EXISTS idx_validation_15_child_parent 
ON src.validation_15 (child_table, parent_table, join_condition);