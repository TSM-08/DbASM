import sys
import traceback
from contextlib import contextmanager

import source_code.app_base as AppBase
from source_code.app_utils import Dict, Optional
from source_code.gen_hash import HashMaker
from source_code.gen_report import MigrationReport
from source_code.final_check import FinalAssessment
from source_code.as_schema import SchemaProcessor
from app_args import BaseMigrationArgs

import source_code.app_utils as utils


class AssessmentArgs(BaseMigrationArgs):
    """Subclass with additional arguments for assessment operations."""
    def __init__(self, description=None):
        super().__init__(description or 'Post Assessment Tool')


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

        self._config: Dict = {}
        self._connection: Dict = {}
        self._schemas: Dict = {}
        self._show_elapsed_time: bool = False
        self._show_final_report: bool = False
        self._check_hashes: bool = False
        self._abort_cross_check: bool = True
        self._assessment = None
          
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

    @contextmanager
    def _timed_section(self, title: str, delimiter: str = '-'):
        """Context manager for timing and formatting assessment sections."""
        self._timer_start()
        print(f"\n{title}")
        self._print_section_delimiter(delimiter)
        try:
            yield
        finally:
            self._timer_stop()

    def _process_each_direction(self, callback, *args, **kwargs):
        """
        Execute callback for each database direction ('src', 'trg').
        Wraps error handling for consistency.
        """
        for direction in ['src', 'trg']:
            try:
                callback(direction, *args, **kwargs)
            except Exception as e:
                raise MigrationAssessmentError(
                    f"Failed {callback.__name__} for {direction.upper()}: {e}"
                ) from e

    def _load_and_validate_config(self):
        """Load and validate configuration."""
        try:
            self._config = AppBase.open_base_config()
            self._connection = AppBase.open_connection_config()
            self._check_hashes = utils.get_config_item(self._config, 'run_mode', 'check_hashes', default=True)
            self._show_elapsed_time = utils.get_config_item(self._config, 'run_mode', 'show_elapsed_time', default=True)
            self._show_final_report = utils.get_config_item(self._config, 'run_mode', 'show_report', default=True)
            self._abort_cross_check = utils.get_config_item(self._config, 'run_mode', 'abort_cross_check', default=True)
            AppBase.set_debug(utils.get_config_item(self._config, 'run_mode', 'debug', default=False))
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
            
            # Step 4: Run final assessment
            self._run_final_assessment()
            
            # Step 5: Print report
            self._print_assessment_report()

            self._print_section_delimiter()
            print("Migration Assessment completed")
            return True
        except Exception as e:
            print(f"Migration assessment failed!")
            print(traceback.format_exc())
            return False

    def _collect_metadata(self) -> None:
        """
        Step 1: Collect metadata for source and target databases.
        Populates self._schemas for 'src' and 'trg'.
        """
        with self._timed_section("Step 1: Collecting metadata for Source and Target databases"):
            def fetch_metadata(direction: str) -> None:
                print(f"\n- Fetching {direction.upper()} database metadata...")
                self._schemas[direction] = self._fetch_schema_data(direction)
            self._process_each_direction(fetch_metadata)
            print("\nMetadata collection completed for all databases")
    
    def _fetch_schema_data(self, direction: str) -> SchemaProcessor:
        """
        Fetch schema data for a specific database direction ('src' or 'trg').
        Returns a configured SchemaProcessor instance.
        Raises MigrationAssessmentError on failure.
        """
        db_config = self._connection['database'][direction]
        db_type = db_config.get('type', 'unknown')
        connector_cls, convertor_key = AppBase.DB_CONNECT_MAP[direction]
        assm_config = self._config.get('assessment', {})
        try:
            with connector_cls(**db_config) as db_connect:
                if convertor_key:
                    db_connect.converter.set_config(self._config.get(convertor_key, {}))
                schema = SchemaProcessor(
                    db=db_connect, config=assm_config, direction=direction
                )
                schema.load_metadata().load_validation()
                return schema
        except Exception as e:
            raise MigrationAssessmentError(
                f"Failed to fetch {direction} data ({db_type}): {e}"
            ) from e
    
    def _generate_hashes(self):
        """Step 2: Generate row hashes for source and target tables."""
        with self._timed_section("Step 2: Generating row hashes for Source and Target tables"):
            if not self._check_hashes:
                print("Skipping hash generation as 'check_hashes' is set to False.")
                return
            
            def generate_hash(direction):
                schema = self._schemas[direction]
                print(f"\n- Generating row hashes for {direction.upper()} tables...")
                hash_maker = HashMaker(schema, self._config)
                hash_maker.generate_hashes()
            
            self._process_each_direction(generate_hash)
            print("\nRow hash generation completed for all databases")
    
    def _upload_assessment_data(self):
        """Step 3: Upload source and target metadata/hashes to target database."""
        with self._timed_section("Step 3: Uploading metadata and hashes to Target database"):
            if 'src' not in self._schemas or 'trg' not in self._schemas:
                raise MigrationAssessmentError("Both source and target schemas are required")
            
            final_assessment = FinalAssessment(config=self._config, 
                                               schema_src=self._schemas['src'],
                                               schema_trg=self._schemas['trg'])
            
            def upload_data(direction):
                print(f"\n- Upload {direction.upper()} metadata and hashes into Target database\n")
                final_assessment.store_data_assessment(direction=direction)
            
            self._process_each_direction(upload_data)
            print("\nMetadata and hash upload completed")
            
            # Store assessment for final checks
            self.final_assessment = final_assessment
    
    def _run_final_assessment(self):
        """Step 4: Run final validation checks on target database."""
        with self._timed_section("Step 4: Running final checks on Target database"):
            print("\n- Pre-check preparation")
            self.final_assessment.pre_checks()
            print("\nPre-check preparation completed.")

            print("\n- Cross-checking metadata rules")
            success = self.final_assessment.cross_checking()
            if not success and self._abort_cross_check:
                raise MigrationAssessmentError("Cross-checking metadata rules failed")
            print("\nCross-checking metadata rules completed.")
            
            print("\n- Running check rules")
            self._assessment = self.final_assessment.run_final_assessment()
            print("\nFinal checks completed.")
    
    def _print_assessment_report(self):
        """Step 5: Generate migration assessment report."""
        with self._timed_section("Step 5: Generating migration report"):
            if not self._assessment:
                raise MigrationAssessmentError("No assessment data available for report generation")
            
            migration_report = MigrationReport(self._config, 'final_report', self._assessment, self._connection)
            report_file = AppBase.get_report_path(migration_report.report_file)
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
            
            print(f"\nMigration report saved to: {report_file}")
            print("\nMigration report generated successfully")

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
            print(f"  Type: {db_type}")
            
            connector_cls = AppBase.DB_CONNECT_MAP[direction][0]
            try:
                with connector_cls(**conn_cfg) as db_connect:
                    print(f"[SUCCESS] Connection established.")
                    results.append(True)
            except Exception as e:
                print(f"[FAILURE] Connection failed")
                print(f"Error: {e}")
                results.append(False)
        
        if not all(results):
            print("\nOne or more database connections failed.")
            return False
        
        print("\nDatabase connectivity test passed for both databases.\n")
        return True


def main():
    """Main application entry point."""
    AppBase.set_base_path(__file__)
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