import sys

from typing import Dict, Optional
from app_source.app_base import AppBase
from app_source.gen_hash import HashMaker
from app_source.as_schema import SchemaProcessor
from app_source.final_check import FinalAssessment
from app_source.as_schema import SchemaAssessment
from app_source.data_sync import DataSync
from app_args import BaseMigrationArgs
from app_source.gen_report import MigrationReport

import app_source.app_utils as utils


class RollbackArgs(BaseMigrationArgs):
    """Subclass with additional arguments for rollback operations."""
    def __init__(self, description=None):
        super().__init__('Rollback Migration Tool')

    def build_parser(self):
        # Start with the base parser
        parser = super().build_parser()

        # Add optional arguments specific to rollback
        parser.add_argument(
            '--check-source-only', 
            action='store_true', 
            help='Check if source DB unchanged'
        )

        return parser


class DataSyncBackError(Exception):
    """Custom exception for migration assessment errors."""
    pass


class DataSyncBack():
    def __init__(self, app_args: RollbackArgs):
        args = app_args.get_args()
        self.check_source_only = args.check_source_only
        config_path=args.config_path

        # Set base path and load configuration
        if config_path:
            AppBase.set_base_path(config_path)
        else:
            AppBase.set_base_path(__file__)

        self._config = AppBase.open_base_config()
        AppBase.set_debug(self._config.get('run_mode', {}).get('debug', False))
        self._show_report = self._config.get('run_mode', {}).get('show_report', True)
        self._connection = AppBase.open_connection_config()
        self._show_elapsed_time = self._config.get('run_mode', {}).get('show_elapsed_time', True)
        self._schemas: Dict = {}

        # Override credentials if provided via command line
        app_args._override_source_credentials(self._connection)
        app_args._override_target_credentials(self._connection)

    def _print_section_delimiter(self, delimiter: str = '='):
        print(delimiter * AppBase.SECTION_LENGTH)

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

    def _get_connection(self, direction: str) -> dict:
        """Get database connection configuration for the specified direction."""
        if 'database' not in self._connection or direction not in self._connection['database']:
            raise DataSyncBackError(f"{direction.capitalize()} database configuration is missing.")
        return self._connection['database'][direction]
    
    def _fetch_metadata(self, direction: str, connection: dict, assm_config: dict, 
                        restore: bool = False) -> SchemaProcessor:
        db_type = connection['type'] 
        connector_cls = AppBase.DB_CONNECTOR_MAP[db_type][0] 
        convertor_key = AppBase.DB_CONNECTOR_MAP[db_type][1]
        try:
            with connector_cls(**connection) as db_connect:
                if convertor_key:
                    db_connect.converter.set_config(self._config.get(convertor_key, {}))
                    
                schema = SchemaProcessor(db=db_connect, config=assm_config, 
                                         direction=direction)
                if restore:
                    schema.restore_metadata()
                    schema.restore_validation()
                    schema.restore_hashes()
                else:
                    schema.load_metadata().load_validation()
                    hash_maker = HashMaker(schema, self._config)
                    hash_maker.generate_hashes()

                return schema
            
        except Exception as e:
            raise DataSyncBackError(
                f"Failed to fetch {direction} data ({db_type}): {e}"
            ) from e
                           
    def check_source_db(self):
        print("Midweek Rollback Pre-Checking process started")
        print("Checking source database is unchanged since the last assessment")        
        
        assm_config = self._config.get('assessment', {})
        db_config = self._get_connection(direction='src')

        self._timer_start()
        self._print_section_delimiter('=')
        print("Step 1: Collecting metadata for Oracle database")
        self._print_section_delimiter('-')

        for direction in ['src', 'trg']:
            if direction == 'src':
                print(f"\n- Fetching {direction.upper()} database metadata from storage (last assessment)...")
            else:
                print(f"\n- Fetching {direction.upper()} database metadata from database (current status)...")
            self._schemas[direction] = self._fetch_metadata(direction=direction,
                        connection=db_config,
                        assm_config=assm_config, 
                        restore=direction=='src')
        print("\nDatabase metadata collected.")
        self._timer_stop()

        self._timer_start()
        print("\nStep 2: Uploading metadata and hashes for pre-checking")
        self._print_section_delimiter("-")    
        self._upload_assessment_data()
        print("\nDatabase metadata and row hashes uploaded.")
        self._timer_stop()

        self._timer_start()
        print("\nStep 3: Running pre-checking process")
        self._print_section_delimiter("-")
        assessment = self.final_assessment.run_precheck()
        issues_found = 0
        for res in assessment.get_precheck_list():
            _, rows = assessment.get_precheck(res)
            issues_found += len(rows) if rows else 0
        print(f"\nPre-check completed. Total issues found: {issues_found}.")
        self._timer_stop()

        self._print_section_delimiter('=')
        print("Midweek Rollback pre-checking process completed.")
        if issues_found > 0:
            print("\nResolution - FAILURE. Please resolve the issues before proceeding with rollback.")
        else:
            print("\nResolution - Success. Midweek rollback process can be performed.")
        
        return issues_found == 0
    
    def _get_increment_results(self, assessment: SchemaAssessment) -> tuple:
        """Process increment queries and return changes, tabmaps, colmaps."""
        results = {"DIS": [], "TAB": [], "COL": []}

        for item in assessment.get_incrment_list():
            cols, rows = assessment.get_incrment(item)
            results[item] = [dict(zip(cols, row)) for row in rows] if rows else []

        return results["DIS"], results["TAB"], results["COL"]

    def _detect_changes(self):
        self._print_section_delimiter('=')
        self._timer_start()
        print("Step 1: Collecting metadata for source and target databases")
        self._print_section_delimiter('-')
        assm_config = self._config.get('assessment', {})
        for direction in ['src', 'trg']:
            print(f"\n- Fetching {direction.upper()} database metadata...")
            db_config = self._get_connection(direction=direction)
            self._schemas[direction] = self._fetch_metadata(direction=direction,
                        connection=db_config,
                        assm_config=assm_config)
        print("\nDatabase metadata and row hashes collected.")
        self._timer_stop()

        self._timer_start()
        print("\nStep 2: Uploading metadata and hashes to get discrepancy")
        self._print_section_delimiter('-')
        self._upload_assessment_data()
        print("\nDatabase metadata and row hashes uploaded.")
        self._timer_stop()

        self._timer_start()
        print("\nStep 3: Detecting target incremental changes for source database")
        self._print_section_delimiter('-')
        print("Running discrepancy checks and possible transformations...")
        assessment = self.final_assessment.run_detect_updates()
        changes, tabmaps, colmaps = self._get_increment_results(assessment)
        print(f"\nChange detection completed. Changes found: {len(changes)}.")
        self._timer_stop()
    
        return changes, tabmaps, colmaps

    def _apply_changes(self, changes, tabmaps, colmaps) -> DataSync:
        data_sync = DataSync(schemas=self._schemas, 
                             changes=changes, tabmaps=tabmaps, colmaps=colmaps)
        print("\nStep 4: Applying detected changes to source database")
        self._print_section_delimiter('-')
        if changes:
            self._timer_start()   
            data_sync.apply_changes()
            print("\nChanges have been applied to source database.")
            self._timer_stop()
        else:
            print("No changes detected to apply.")
        return data_sync

    def _upload_assessment_data(self):   
        if 'src' not in self._schemas or 'trg' not in self._schemas:
            raise DataSyncBackError("Both source and target schemas are required")

        connection = self._get_connection(direction='trg')
        db_type = connection['type'] 
        connector_cls = AppBase.DB_CONNECTOR_MAP[db_type][0]
        db_connect = connector_cls(**connection)

        try:
            final_assessment = FinalAssessment(self._config,
                            schema_src=self._schemas['src'],
                            schema_trg=self._schemas['trg'],
                            db_connect=db_connect)

            for direction in ['src', 'trg']:
                print(f"\n- Upload {direction.upper()} metadata and hashes\n")
                final_assessment.store_data_assessment(direction=direction)
            
            # Store assessment for final checks
            self.final_assessment = final_assessment
            
        except Exception as e:
            raise DataSyncBackError(
                f"Failed to upload assessment data: {e}") from e

    def _report_generation(self, data_sync: DataSync):
        """Generate assessment report."""
        self._timer_start()
        print("\nStep 5: Prepare assessment data for report")
        self._print_section_delimiter('-')
        for direction in ['src', 'trg']:
            print(f"\n- Fetching {direction.upper()} metadata for report generation...")
            db_config = self._get_connection(direction=direction)
            self._schemas[direction] = self._fetch_metadata(direction=direction,
                        connection=db_config,
                        assm_config=self._config.get('assessment', {}))
            
        self._upload_assessment_data() 
        print('\nAssessment data prepared.') 
        self._timer_stop()   
        
        self._timer_start()
        print("\nStep 6: Assessment report generation")
        self._print_section_delimiter('-')
        print("\n- Running assessment checks for report generation")
        self._assessment = self.final_assessment.run_rollback_check()

        assessment = self.final_assessment._schema_trg.assessment
        migration_report = MigrationReport(self._config, 'rollback_report', assessment)
        report_content = migration_report.generate_report()

        print("\n- Generate report and Rollback Assessment Summary\n")
        print(f"Total detected changes: {data_sync.total_changes()}")
        print(f"\nTotal applied  changes: {data_sync.total_applied()}")
        print("--------------------------------")
        data_sync.report_updates()

        print("\nGetting assessment statistics...")
        stats = migration_report.get_statistics().get("overall", {})
        for key, value in stats.items():
            print(f"{key.upper()}: {value}")
            
        # Print to console
        if self._show_report:
            print("\n" + report_content)
            
        # Save to file
        report_file = AppBase.get_report_path('rollback_assessment.rpt')
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report_content)
        
        print(f"\nAssessment report generated: {report_file}")
        print('\nAssessmet report generated successfully.')
        self._timer_stop()

    def revert_data(self) -> bool:
        """Run the midweek rollback synchronization."""
        result = True
        print("MidWeek Rollback process started")
        print("Replicating data from target to source database")
        try:
            changes, tabmaps, colmaps = self._detect_changes()
            data_sync = self._apply_changes(changes, tabmaps, colmaps)
            self._report_generation(data_sync)
            self._print_section_delimiter('=')
            print("MidWeek Rollback process completed.")
        except Exception as e:
            print(f"Error during data synchronization: {e}")
            result = False
        return result


def main():
    """Main application entry point."""
    main_args = RollbackArgs()
    
    try:
        # Create migration assessment
        sync_data = DataSyncBack(main_args)
        
        if sync_data.check_source_only:
            success = sync_data.check_source_db()
        else:
            success = sync_data.revert_data()
        
        if success:
            sys.exit(0)
        else:
            sys.exit(1)

    except DataSyncBackError as e:
        print(f"\nDataSyncBack Error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nDataSyncBack interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()