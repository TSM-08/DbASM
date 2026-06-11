-- This script is used to clean up the database by dropping the schemas used for source and target metadata and validation results.
-- It ensures that any existing schemas and their contents are removed before a new assessment is performed.

DROP SCHEMA IF EXISTS src CASCADE;
DROP SCHEMA IF EXISTS trg CASCADE;
/