import sys
import traceback

from app_source.app_base import AppBase
from app_source.app_utils import Dict, Optional
from app_source.gen_hash import HashMaker
from app_source.gen_report import MigrationReport
from app_source.final_check import FinalAssessment
from app_source.as_schema import SchemaProcessor
from app_args import BaseMigrationArgs

import app_source.app_utils as utils


class AssessmentArgs(BaseMigrationArgs):
    """Subclass with additional arguments for rollback operations."""
    def __init__(self, describtion=None):
        super().__init__('Post Assessment Tool')

    def build_parser(self):
        # Start with the base parser
        parser = super().build_parser()

        # Add optional arguments specific to assessment
        parser.add_argument(
            '--test-connection-only',
            action='store_true',
            help='Test database connections only without running full assessment'
        )

        return parser


class MigrationAssessmentError(Exception):
    """Custom exception for migration assessment errors."""
    pass


class MigrationAssessment:
    """
    Main orchestrator for database migration assessment.
    
    Handles the complete workflow: metadata collection, hash generation,
    data assessment, and report generation.
    """
    
    def __init__(self, app_args: AssessmentArgs):
        """
        Initialize migration assessment.   
        """
        args = app_args.get_args()
        self.test_connection_only = args.test_connection_only
        config_path = args.config_path

        self._config: Dict = {}
        self._connection: Dict = {}
        self._schemas: Dict = {}
        self._show_elapsed_time: bool = False
        self._show_final_report: bool = False
        self._check_hashes: bool = False
        self._abort_on_error: bool = True
        self._assessment = None

         # Set base path and load configuration
        if config_path:
            AppBase.set_base_path(config_path)
        else:
            AppBase.set_base_path(__file__)
            
        self._load_and_validate_config()

        # Override credentials if provided via command line
        app_args._override_source_credentials(self._connection)
        app_args._override_target_credentials(self._connection)

    def _timer_start(self):
        """Start the execution timer."""
        utils.timer_start()
    
    def _timer_stop(self):
        """Stop the execution timer."""
        utils.timer_stop()
        if self._show_elapsed_time:
            self._print_elapsed_time()
    
    def _print_elapsed_time(self):
        """Print the elapsed time since the last timer start."""
        print("* Elapsed time:", utils.elapsed_time_formatted())

    def _load_and_validate_config(self):
        """Load and validate configuration."""
        try:
            self._config = AppBase.open_base_config()
            self._connection = AppBase.open_connection_config()
            self._check_hashes = self._config.get('run_mode', {}).get('check_hashes', True)
            self._show_elapsed_time = self._config.get('run_mode', {}).get('show_elapsed_time', True)
            self._show_final_report = self._config.get('run_mode', {}).get('show_report', True)
            self._abort_on_error = self._config.get('run_mode', {}).get('abort_on_error', True)
            AppBase.set_debug(self._config.get('run_mode', {}).get('debug', False))
        except Exception as e:
            raise MigrationAssessmentError(f"Failed to load configuration: {e}") from e
        
        self._validate_config()
    
    def _validate_config(self):
        """Validate required configuration sections."""
        if not self._connection:
            raise MigrationAssessmentError("Database configuration is empty")
        
        # Validate database configuration
        if 'database' not in self._connection:
            raise MigrationAssessmentError("Database configuration section is missing")
        
        database_config = self._connection['database']
        required_db_keys = ['src', 'trg']
        missing_keys = [key for key in required_db_keys if key not in database_config]
        
        if missing_keys:
            raise MigrationAssessmentError(
                f"Missing database configurations: {missing_keys}"
            )
        
        # Validate each database configuration
        for key in required_db_keys:
            db_config = database_config[key]
            if not isinstance(db_config, dict):
                raise MigrationAssessmentError(f"Database config for '{key}' must be a dictionary")
            
            if 'type' not in db_config:
                raise MigrationAssessmentError(f"Database type not specified for '{key}'")
            
            db_type = db_config['type']
            if db_type not in AppBase.DB_CONNECTOR_MAP:
                raise MigrationAssessmentError(f"Unsupported database type '{db_type}' for '{key}'")
        
        # Validate assessment configuration (optional but should be dict if present)
        if 'assessment' in self._config and not isinstance(self._config['assessment'], dict):
            raise MigrationAssessmentError("Assessment configuration must be a dictionary")

    def _print_section_delimiter(self, delimiter: str = '='):
        print(delimiter * AppBase.SECTION_LENGTH)

    def run_complete_assessment(self) -> bool:
        """
        Run the complete migration assessment workflow.
        
        Returns:
            dict: Assessment report.
            
        Raises:
            MigrationAssessmentError: If any step of the assessment fails.
        """
        try:
            print("Starting Migration Assessment")
            self._print_section_delimiter()

            # Step 1: Collect metadata
            self._collect_metadata()

            # Step 2: Generate hashes
            self._generate_hashes()
            
            # Step 3: Upload data to target
            self._upload_assessment_data()
            
            # Step 4: Run final checks
            self._run_final_checks()
            
            # Step 5: Print report
            self._print_assessment_report()

            self._print_section_delimiter()
            print("Migration Assessment completed")
            return True
        except Exception as e:
            print(f"Migration assessment failed!")
            print(traceback.format_exc())
            return False

    def _collect_metadata(self):
        """Step 1: Collect metadata for source and target databases."""
        self._timer_start()
        print("Step 1: Collecting metadata for Source and Target databases")
        self._print_section_delimiter('-')
        
        assm_config = self._config.get('assessment', {})
        for direction in ['src', 'trg']:
            try:
                db_config = self._connection['database'][direction]
                print(f"\n- Fetching {direction.upper()} database metadata...")
                
                self._schemas[direction] = self._fetch_schema_data(
                    direction=direction,
                    connection=db_config,
                    assm_config=assm_config
                )               
                # print(f"{direction.upper()} metadata collection completed")
                
            except Exception as e:
                raise MigrationAssessmentError(
                    f"Failed to collect metadata for {direction}: {e}"
                ) from e
        
        print("\nMetadata collection completed for all databases")
        self._timer_stop()
    
    def _fetch_schema_data(self, direction: str, connection: dict, assm_config: dict) -> SchemaProcessor:
        """
        Fetch schema data for a specific database.
        
        Args:
            direction: Database direction ('src' or 'trg').
            connection: Database connection configuration.
            assm_config: Assessment configuration.
            
        Returns:
            SchemaProcessor: Configured schema processor.
            
        Raises:
            MigrationAssessmentError: If data fetching fails.
        """
        db_type = connection['type']  # Already validated
        connector_cls = AppBase.DB_CONNECTOR_MAP[db_type][0]  # Already validated
        convertor_key = AppBase.DB_CONNECTOR_MAP[db_type][1]
        try:
            with connector_cls(**connection) as db_connect:
                if convertor_key:
                    db_connect.converter.set_config(self._config.get(convertor_key, {}))
                    
                schema = SchemaProcessor(db=db_connect,
                            config=assm_config,
                            direction=direction
                )
                
                # Load metadata and validation data using fluent interface
                schema.load_metadata().load_validation()
                
                return schema
                
        except Exception as e:
            raise MigrationAssessmentError(
                f"Failed to fetch {direction} data ({db_type}): {e}"
            ) from e
    
    def _generate_hashes(self):
        """Step 2: Generate row hashes for source and target tables."""
        self._timer_start()
        print("\nStep 2: Generating row hashes for Source and Target tables")
        self._print_section_delimiter("-")

        if not self._check_hashes:
            print("Skipping hash generation as 'check_hashes' is set to False.")
            self._timer_stop()
            return
        
        for direction, schema in self._schemas.items():
            try:
                print(f"\n- Generating row hashes for {direction.upper()} tables...")
                
                hash_maker = HashMaker(schema, self._config)
                hash_maker.generate_hashes()
                
                # print(f"Row hashes for {direction.upper()} tables completed")
            except Exception as e:
                raise MigrationAssessmentError(
                    f"Unexpected error generating hashes for {direction}: {e}"
                ) from e
        
        print("\nRow hash generation completed for all databases")
        self._timer_stop()
    
    def _upload_assessment_data(self):
        """Step 3: Upload source and target metadata/hashes to target database."""
        self._timer_start()
        print("\nStep 3: Uploading metadata and hashes to Target database")
        self._print_section_delimiter("-")
        
        if 'src' not in self._schemas or 'trg' not in self._schemas:
            raise MigrationAssessmentError("Both source and target schemas are required")
        
        try:
            final_assessment = FinalAssessment(self._config,
                                schema_src=self._schemas['src'],
                                schema_trg=self._schemas['trg'])

            for direction in ['src', 'trg']:
                print(f"\n- Upload {direction.upper()} metadata and hashes into Target database\n")
                final_assessment.store_data_assessment(direction=direction)
            print("\nMetadata and hash upload completed")
            self._timer_stop()

            # Store assessment for final checks
            self.final_assessment = final_assessment
            
        except Exception as e:
            raise MigrationAssessmentError(
                f"Failed to upload assessment data: {e}") from e
    
    def _run_final_checks(self):
        """Step 4: Run final validation checks on target database."""
        self._timer_start()
        print("\nStep 4: Running final checks on Target database")
        self._print_section_delimiter("-")
        
        try:
            print("\n- Table index creation")
            self.final_assessment.create_indexes()
            print("Table index creation completed.\n")

            print("- Cross-checking metadata rules\n")
            success = self.final_assessment.cross_checking()
            if not success and self._abort_on_error:
                raise MigrationAssessmentError(
                    "Cross-checking metadata rules failed")
            print("\nCross-checking metadata rules completed.\n")
            
            print("- Running check rules")
            self._assessment = self.final_assessment.run_final_assessment()
            print("\nFinal checks completed.")
            self._timer_stop()

        except Exception as e:
            raise MigrationAssessmentError(
                f"Final checks failed: {e}") from e
    
    def _print_assessment_report(self):
        """Step 5: Generate migration assessment report."""
        self._timer_start()
        print("\nStep 5: Generating migration report")
        self._print_section_delimiter("-")
        if not self._assessment:
            raise MigrationAssessmentError("No assessment data available for report generation")
        
        try:
            # Generate report file path
            report_file = AppBase.get_report_path('post_assessment.rpt')

            migration_report = MigrationReport(self._config, 'final_report', self._assessment)
            report_content = migration_report.generate_report()

            # Save to file
            with open(report_file, 'w', encoding='utf-8') as f:
                f.write(report_content or "Report is not ready")
            
            print("\nGetting statistics summary...")
            stats = migration_report.get_statistics().get("overall", {})
            for key, value in stats.items():
                print(f"{key.upper()}: {value}")
            
            # Print to console
            if self._show_final_report:
                print("\n" + report_content)
            
            # self._print_section_delimiter("-")
            print(f"\nMigration report saved to: {report_file}")
            print("\nMigration report generated successfully")
            self._timer_stop()

        except Exception as e:
            raise MigrationAssessmentError(
                f"Failed to generate report: {e}") from e

    def test_database_connections(self):
        """Test connection to both source and target databases."""
        print("\nTesting connection to Source and Target databases")
        self._print_section_delimiter('-')
        db_config = self._connection['database']
        results = []
        
        for direction in ['src', 'trg']:
            conn_cfg = db_config[direction]
            db_type = conn_cfg['type']
            
            # Display connection info
            print(f"\n- Testing {direction.upper()} database connection:")
            print(f"  Type: {db_type}\n")
            
            if db_type == 'Oracle':
                if 'tns_alias' in conn_cfg:
                    print(f"  TNS Alias: {conn_cfg.get('tns_alias')}")
                else:
                    print(f"  Host: {conn_cfg.get('host')}")
                    print(f"  Port: {conn_cfg.get('port')}")
                    print(f"  Service: {conn_cfg.get('service_name')}")
                print(f"  Schema: {conn_cfg.get('schema')}\n")
            elif db_type == 'Postgres':
                print(f"  Host: {conn_cfg.get('host')}")
                print(f"  Port: {conn_cfg.get('port')}")
                print(f"  Database: {conn_cfg.get('database')}")
                print(f"  Schema: {conn_cfg.get('schema')}\n")
            
            connector_cls = AppBase.DB_CONNECTOR_MAP[db_type][0]
            try:
                with connector_cls(**conn_cfg) as db_connect:
                    print(f"[SUCCESS] Connection established.")
                    results.append(True)
            except Exception as e:
                print(f"[FAILURE] Connection failed")
                print(f"Error: {e}")
                results.append(False)
        
        if not all(results):
            print("\nOne or more database connections failed")
            return False
        
        print("\nDatabase connectivity test passed for both databases.\n")
        return True


def main():
    """Main application entry point."""
    main_args = AssessmentArgs()
    
    try:
        # Create migration assessment
        migration = MigrationAssessment(main_args)

        # Test connection
        passed = migration.test_database_connections()
        if not passed:
            sys.exit(1)
        elif migration.test_connection_only:
            sys.exit(0)

        # Run complete assessment
        if migration.run_complete_assessment():
            sys.exit(0)
        else:
            sys.exit(1)
            
    except MigrationAssessmentError as e:
        print(f"\nMigration Assessment Error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAssessment interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()