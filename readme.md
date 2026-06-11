# DbASM - Database Assessment for Schema Migration

## Overview

**DbASM** (Database Assessment for Schema Migration) is a comprehensive Python-based tool designed to validate and assess database migrations. It performs a complete post-migration validation workflow that ensures data integrity and schema consistency between source and target databases.

The tool supports migrations between multiple database systems including **Oracle**, **PostgreSQL**, and **MSSQL**.

## Purpose

After migrating a database from one system to another (e.g., Oracle to PostgreSQL), it is critical to validate that:

1. **Schema Structure** - All database objects (tables, columns, constraints, indexes) are correctly replicated
2. **Data Integrity** - Data migration is complete and accurate
3. **Constraints & Relationships** - Foreign keys, primary keys, and other constraints are properly enforced
4. **Data Verification** - Row counts and row-level hash checks match between source and target

DbASM automates these validation checks by:
- Collecting detailed metadata from both source and target databases
- Generating row-level hashes for data comparison
- Running 35+ validation rules to ensure consistency
- Generating comprehensive assessment reports

## Key Features

- **Multi-Database Support**: Oracle, PostgreSQL, MSSQL
- **Comprehensive Validation**: 35+ validation rules covering schema, data, and constraints
- **Row-Level Hash Verification**: Ensures data integrity at the row level
- **Detailed Reporting**: Generates structured assessment reports with statistics
- **Configurable Assessment**: Customize validation queries and assessment rules
- **Command-Line Interface**: Override credentials and configuration via CLI arguments
- **Debug Mode**: Optional debug logging for troubleshooting

## Project Structure

```
DbASM/
├── app.py                          # Main application entry point
├── app_args.py                     # Command-line argument parser
├── config.yaml                     # Assessment and validation configuration
├── connection.yaml                 # Database connection configuration
├── requirements.txt                # Python dependencies
├── README.md                        # This file
├── _examples/                       # Example configurations for different migration scenarios
│   ├── Ex_Oracle-Postgres/
│   ├── Ex_MSSQL-Postgres/
│   └── Ex_Postgres-Postgres/
├── assessment/                      # Assessment results and metadata
│   ├── metadata/                    # Collected metadata from both databases
│   │   ├── src/                     # Source database metadata
│   │   └── trg/                     # Target database metadata
│   └── reports/                     # Generated assessment reports
├── migration/                       # SQL scripts and connectors
│   ├── src/                         # Source database SQL scripts
│   │   ├── connector.py
│   │   ├── metadata.sql
│   │   └── data_align.py
│   ├── trg/                         # Target database SQL scripts
│   │   ├── connector.py
│   │   ├── metadata.sql
│   │   └── data_align.py
│   └── final_sql/                   # Assessment and validation SQL scripts
│       ├── metadata.sql             # Creates assessment metadata tables
│       ├── validation.sql           # Creates validation result tables
│       ├── check_assm.sql           # Cross-checking rules
│       ├── final_checks.sql         # Final validation checks
│       └── pgs_indexes.sql          # Index creation
└── source_code/                     # Core Python modules
    ├── app_base.py                  # Base configuration and utilities
    ├── app_utils.py                 # Common utility functions
    ├── as_schema.py                 # Schema processor
    ├── dbbase_cls.py                # Base database class
    ├── data_align.py                # Data alignment utilities
    ├── final_check.py               # Final assessment logic
    ├── gen_hash.py                  # Hash generation for row validation
    ├── gen_report.py                # Report generation
    └── dbconnectors/                # Database-specific connectors
        ├── oracle_connector.py
        ├── postgres_connector.py
        └── mssql_connector.py
```

## Installation

### Prerequisites

- Python 3.8 or higher
- Network connectivity to source and target databases
- Appropriate database client libraries

### Setup

1. **Install Python Dependencies**

   ```bash
   pip install -r requirements.txt
   ```

   Key dependencies:
   - `pyyaml` - YAML configuration file parsing
   - `oracledb` - Oracle database connectivity
   - `psycopg2-binary` - PostgreSQL database connectivity
   - `pyodbc` - MSSQL database connectivity (if applicable)
   - `cryptography` - For secure credential handling

2. **Offline Installation (if required)**

   Pre-built wheel packages are provided in the `offline_packages/` directory for environments without internet access:

   ```bash
   pip install offline_packages/*.whl
   ```

## Configuration

DbASM requires two main configuration files:

### 1. `connection.yaml` - Database Connections

Defines the source and target database connection parameters.

**Example Configuration:**

```yaml
database:
  src:  # Source database (Oracle example)
    type: Oracle
    host: source-server.example.com
    port: 1521
    service_name: orcl
    schema: PURCHASE
    username: purchase_user
    password: purchase_password

  trg:  # Target database (PostgreSQL example)
    type: Postgres
    host: target-server.example.com
    port: 5432
    database: postgres
    schema: purchase
    username: postgres
    password: postgres_password
```

**Supported Database Types:**
- `Oracle` - Oracle Database 19c+
- `Postgres` - PostgreSQL 12+
- `MSSQL` - Microsoft SQL Server 2017+

**Connection Parameters by Database Type:**

**Oracle:**
```yaml
type: Oracle
host: hostname
port: 1521
service_name: database_service_name
schema: schema_name
username: username
password: password
```

**PostgreSQL:**
```yaml
type: Postgres
host: hostname
port: 5432
database: database_name
schema: schema_name
username: username
password: password
```

**MSSQL:**
```yaml
type: MSSQL
host: hostname
port: 1433
database: database_name
schema: schema_name
username: username
password: password
```

### 2. `config.yaml` - Assessment Configuration

Defines assessment rules, validation queries, and report settings.

**Key Sections:**

**a) Run Mode Settings**

Controls the assessment execution behavior:

```yaml
run_mode:
  check_hashes: true              # Enable/disable row hash verification
  show_elapsed_time: true         # Display execution time for each step
  show_report: true               # Display final report in console
  abort_cross_check: true         # Stop on cross-checking failures
  debug: false                    # Enable debug logging
```

**b) Assessment Configuration**

Defines metadata and validation queries:

```yaml
assessment:
  version: 1.0.1
  
  # Whether to include schema name in query parameters
  schema_name_in_query:
    src: false
    trg: false
  
  # Metadata queries (11 standard queries)
  metadata_query:
    "01": "Simple total count of major object types"
    "02": "Tables with identity and partitioning flags"
    "03": "Column name, types and other properties"
    "04": "Table sequences"
    "05": "Sequences and their properties"
    "06": "Primary key constraints definitions"
    "07": "Table check constraints excluding not null"
    "08": "Foreign key constraints definitions"
    "09": "Indexes and their properties"
    "10": "Calculate row counts for each table"
    "11": "Generate row hash values for each table"
  
  # Validation queries (6 data integrity checks)
  validate_query:
    "12": "Check all tables have a primary key"
    "13": "Check for duplicate rows based on primary key"
    "14": "Check for NULLs in NOT NULL columns"
    "15": "Check for foreign key constraint violations"
    "16": "Check for disabled foreign key constraints"
    "17": "Check max value for identity columns"
  
  # Final checks (35 comprehensive validation rules)
  finalchk_query:
    "F01": "Verify count of tables between source and target"
    "F02": "Verify count of sequences between source and target"
    # ... (33 more final checks)
    "F35": "Per-table row hashes identical in both databases"
  
  # Final report configuration
  final_report:
    name: "FINAL MIGRATION REPORT"
    data_query: "finalchk_query"
    show_statistics: true
    section_length: 90
    items:
      "A":
        title: "Database Objects Counts Validation"
        rules:
          - "F01": High
          - "F02": High
      # ... more sections
```

## Usage

### Basic Execution

Run the complete assessment workflow:

```bash
python app.py
```

This executes the following steps:
1. **Step 1**: Collect metadata from source and target databases
2. **Step 2**: Generate row hashes for data validation
3. **Step 3**: Upload assessment data to target database
4. **Step 4**: Run final validation checks
5. **Step 5**: Generate migration assessment report

### Test Database Connections

Verify connectivity to both databases without running the full assessment:

```bash
python app.py --test-connection-only
```

### Override Connection Credentials (CLI Arguments)

Override any connection parameter via command-line arguments:

```bash
# Override source database credentials
python app.py --src-host new-host.com --src-port 1522 --src-username admin

# Override target database credentials
python app.py --trg-host new-target.com --trg-port 5433 --trg-password newpass

# Override both
python app.py --src-host source-host --src-username user1 --trg-host target-host --trg-username postgres
```

**Available CLI Arguments:**

Dynamically generated based on `connection.yaml` database configuration. Common examples:
- `--src-host` - Source database hostname
- `--src-port` - Source database port
- `--src-username` - Source database username
- `--src-password` - Source database password
- `--src-schema` - Source schema name
- `--trg-host` - Target database hostname
- `--trg-port` - Target database port
- `--trg-username` - Target database username
- `--trg-password` - Target database password
- `--trg-schema` - Target schema name

### Enable Debug Mode

For troubleshooting, enable detailed debug logging:

Edit `config.yaml`:
```yaml
run_mode:
  debug: true
```

Or use environment variable (if supported by deployment):
```bash
DEBUG=1 python app.py
```

## Assessment Workflow

### Step 1: Metadata Collection

Gathers structural information from both databases:
- Object counts (tables, sequences, indexes, constraints)
- Table properties (identity columns, partitioning)
- Column definitions and types
- Constraint definitions (PK, FK, CHECK)
- Index information
- Row counts per table

Results are stored in:
- `assessment/metadata/src/` - Source database metadata
- `assessment/metadata/trg/` - Target database metadata

### Step 2: Hash Generation

Generates row-level hash values for data validation:
- Creates hash values for each row in every table
- Uses primary key or composite key when available
- Compares source and target row hashes for data integrity verification
- Results stored in hash CSV files

### Step 3: Data Upload to Target

Uploads collected metadata and validation results to the target database:
- Creates assessment tables in target database schema
- Stores metadata_01 through metadata_11 results
- Stores validation_12 through validation_17 results
- Creates indexes for efficient querying

### Step 4: Final Validation Checks

Runs comprehensive validation rules:

**Database Objects Validation (5 checks):**
- F01: Table counts match
- F02: Sequence counts match
- F03: Index counts match
- F04: Constraint counts match
- F05: Stored objects count matches

**Table Structure Validation (8 checks):**
- F06: Identical table names exist
- F07: Table options match (identity, partitioning)
- F08-F11: Column consistency (lists, types, nullability, defaults)
- F12-F14: Sequence and identity consistency

**Constraint Validation (4 checks):**
- F17-F19: Primary key validation
- F20-F22: Foreign key and index validation

**Data Integrity Validation (11 checks):**
- F23-F24: Row count and hash validation
- F25-F35: Data validation rules (no duplicates, no NULLs in NOT NULL columns, no orphaned rows, etc.)

### Step 5: Report Generation

Generates a structured assessment report with:
- Overall pass/fail status for all checks
- Detailed section-by-section results
- Statistics and summary metrics
- Issues and warnings
- Recommendations

Report saved to: `assessment/reports/MIGRATION_REPORT_<timestamp>.txt`

## Migration Folder SQL Scripts

## Release assessment — preparing a real validation

This project can be configured to run a full release assessment. Follow these steps to prepare
the repository and configuration for a production-style validation run.

- Consider the migration first:
  - Identify source and target DB types and the connectors required.
  - Ensure `migration/src` and `migration/trg` contain per-DB SQL scripts used to extract
    metadata and to prepare data for hashing.

- Connectors:
  - Check `source_code/dbconnectors/` for a connector matching each DB type (oracle, postgres, mssql).
  - If a connector is missing, implement one by subclassing the base class in `source_code/dbbase_cls.py`.
    Implement connect/execute/fetch/close and any helper methods needed for DDL/DML scripts.

- `connection.yaml`:
  - Create `connection.yaml` in the repository root with `src` and `trg` sections (do not commit secrets).
  - Minimal example:

```yaml
src:
  type: oracle
  host: oracle-host
  port: 1521
  service: ORCL
  user: SCHEMA_USER
  password: "<secure>"

trg:
  type: postgres
  host: pg-host
  port: 5432
  dbname: target_db
  user: pg_user
  password: "<secure>"
```

- Migration scripts organization:
  - Put object-level extraction scripts in `migration/src/` and `migration/trg/` (e.g. `metadata.sql`, `validation.sql`).
  - Put cross-database, load and finalisation scripts in `migration/final_sql/` (e.g. `metadata.sql`, `generate_hashes.sql`, `final_checks.sql`).
  - Reference finalisation scripts from `assessment.check_events` in `config.yaml`.

- Metadata & validation queries:
  - Update `assessment.metadata_query`, `assessment.validate_query` and `assessment.finalchk_query` in `config.yaml`
    to reflect the actual object types transferred and checks you want to run.
  - Typical objects: tables, sequences, indexes, PK/FK constraints, stored procedures, views.

- Final report generation:
  - Use scripts in `migration/final_sql/` to load collected metadata into the target assessment schema and
    to compute per-row hashes.
  - Ensure `assessment.final_report` maps `items` to checks from `finalchk_query`.
  - Run the full workflow with `python app.py` (or CI/scripted job) to produce the final report in `assessment/reports/`.

Checklist (quick):
- Add or update connectors in `source_code/dbconnectors`
- Create/verify `connection.yaml` with `src`/`trg` credentials (do not commit secrets)
- Populate `migration/src` and `migration/trg` with extraction SQL
- Add/load cross-database scripts to `migration/final_sql`
- Update `config.yaml` queries and `final_report` mapping
- Run `python app.py` to generate the assessment report

The `migration/` folder contains database-specific SQL scripts:

### `/migration/src/` - Source Database Scripts

- **`metadata.sql`** - Queries to extract schema metadata from source database
- **`validation.sql`** - Validation queries for data integrity checks
- **`connector.py`** - Source database connector class
- **`data_align.py`** - Data alignment and normalization utilities

### `/migration/trg/` - Target Database Scripts

- **`metadata.sql`** - Queries to extract schema metadata from target database
- **`validation.sql`** - Validation queries for target database
- **`connector.py`** - Target database connector class
- **`data_align.py`** - Data alignment utilities

### `/migration/final_sql/` - Assessment & Validation Scripts

- **`metadata.sql`** - Creates assessment metadata tables in target database
- **`validation.sql`** - Creates validation result tables
- **`check_assm.sql`** - Cross-checking rules implementation
- **`final_checks.sql`** - Final validation checks queries
- **`pgs_indexes.sql`** - PostgreSQL-specific index creation

**Important:** These SQL scripts use placeholder syntax that gets replaced at runtime:
- `<schema_name>` - Replaced with actual schema name from configuration
- `%01S`, `%02S`, etc. - Replaced with actual SQL queries

## Output Files

### Assessment Metadata

- **Location**: `assessment/metadata/src/` and `assessment/metadata/trg/`
- **Files**: 
  - `metadata_01.csv` through `metadata_11.csv` - Structural metadata
  - `validation_12.csv` through `validation_17.csv` - Data validation results
  - `hashes/` - Row hash verification files

### Assessment Reports

- **Location**: `assessment/reports/`
- **Files**: 
  - `MIGRATION_REPORT_<timestamp>.txt` - Final assessment report with all validation results

### Logs (if debug enabled)

- **Location**: `migration/logs/`
- **Contains**: Detailed execution logs, SQL queries, and error traces

## Examples

The `_examples/` directory contains pre-configured examples for common migration scenarios:

1. **`Ex_Oracle-Postgres/`** - Oracle to PostgreSQL migration
   - Pre-configured `connection.yaml` and `config.yaml`
   - Suitable for Oracle 19c → PostgreSQL 12+ migrations

2. **`Ex_MSSQL-Postgres/`** - MSSQL to PostgreSQL migration
   - MSSQL Server 2017+ → PostgreSQL 12+

3. **`Ex_Postgres-Postgres/`** - PostgreSQL to PostgreSQL migration
   - PostgreSQL upgrades or schema-only migrations

**To use an example:**

```bash
# Copy example configuration to root (force overwrite)
cp -f _examples/Ex_Oracle-Postgres/connection.yaml .
cp -f _examples/Ex_Oracle-Postgres/config.yaml .

# Copy migration folder to root (recursive + force)
cp -rf _examples/Ex_Oracle-Postgres/migration .

# Update with your actual database credentials
vi connection.yaml

# Run assessment
python app.py
```

## Troubleshooting

### Issue: Connection Failed

**Symptom**: "Failed to fetch source/target data"

**Solutions**:
1. Verify database hostname, port, and credentials in `connection.yaml`
2. Ensure network connectivity to both databases
3. Check database user has required permissions
4. Use `--test-connection-only` to verify connectivity

### Issue: Missing Database Objects

**Symptom**: "Table counts don't match" in F01 check

**Possible Causes**:
1. Migration incomplete - some objects not migrated
2. Schema name mismatch between source and target
3. Filtering or exclusions in migration scripts

**Resolution**:
1. Review migration logs and scripts
2. Verify schema names in `connection.yaml`
3. Check for any table naming transformations

### Issue: Data Hash Mismatch

**Symptom**: "Row hashes don't match" in F35 check

**Possible Causes**:
1. Data transformation during migration (e.g., data type conversion)
2. Truncation or rounding of numeric/decimal values
3. Character encoding differences
4. Data loading errors during migration

**Resolution**:
1. Check data transformation rules in migration scripts
2. Examine specific mismatched rows
3. Re-run source extraction and target validation

### Issue: Primary Key Violations

**Symptom**: "Duplicate rows" in F27/F28 checks

**Solution**:
1. Identify problematic tables in validation results
2. Clean duplicate rows in target database
3. Re-run assessment after correction

## Performance Considerations

- **Large Databases**: Hash generation can be time-consuming. For tables with millions of rows, consider:
  - Running during off-hours
  - Sampling data (if appropriate for your use case)
  - Using `check_hashes: false` for initial validation

- **Network Latency**: Assessment time varies with network latency. High-latency connections may increase execution time.

- **Target Database Load**: Assessment creates temporary tables. Ensure target database has sufficient space and resources.

## Requirements

See `requirements.txt` for complete list. Key requirements:

```
pyyaml>=6.0.3
oracledb>=3.3.0  (for Oracle migrations)
psycopg2-binary>=2.9.10  (for PostgreSQL migrations)
pyodbc>=4.x  (for MSSQL migrations, if applicable)
cryptography>=46.0.2
```

## Security Considerations

1. **Credentials Management**:
   - Store database passwords securely (avoid hardcoding in config files)
   - Use environment variables or secure vaults in production
   - Rotate credentials regularly

2. **Network Security**:
   - Use encrypted connections (SSL/TLS) when available
   - Restrict network access to assessment tool
   - Use VPNs for remote database access

3. **Assessment Data**:
   - Assessment results may contain sensitive metadata
   - Store reports securely
   - Limit access to assessment reports

## Support & Maintenance

For issues, enhancement requests, or contributions:

1. Check examples in `_examples/` for reference configurations
2. Review error messages in assessment reports
3. Enable debug mode for detailed logging
4. Consult database-specific connector documentation

## Version History

- **1.0.1** - Current version
  - Multi-database support (Oracle, PostgreSQL, MSSQL)
  - 35+ validation rules
  - Comprehensive reporting
  - Command-line credential override

## License

[Specify your license here - e.g., MIT, Apache 2.0, etc.]

## Contact

[Specify contact information or support channel]
