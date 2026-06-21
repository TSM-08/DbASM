-- This script performs various checks to ensure consistency and completeness of metadata collected in previous steps.
-- It compares counts and existence of tables, columns, and sequences across different metadata tables and logs any discrepancies 
-- in the cross_checking table for both Source and Target databases.

-- Check that the number of tables is consistent across rules 01, 02 in Source.
-- This query checks if the count of tables in metadata_02 matches with metadata_01
