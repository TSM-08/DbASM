from . import app_base as AppBase
from .data_align import DataAdjustment
from .dbbase_cls import DbConnector
from . import app_utils as utils

import datetime


SQL_CODE_NOT_EXISTS = "SQL code is not specified."


class SchemaAssessment:
    METADATA_FILE = "metadata.sql"
    VALIDATE_FILE = "validation.sql"

    def __init__(self, db_type: str, config: dict, direction: str):
        if not db_type:
            raise ValueError("Database type must be provided.")
        
        self._sql_folder = AppBase.SQL_FOLDER_MAP.get(direction)
        if self._sql_folder is None:
            raise ValueError(f"Folder mapping not found for direction: {direction}")
        
        if direction not in ['src', 'trg']:
            raise ValueError(f"Unsupported direction: {direction}")

        self._hash_qry_id = None
        self._hash_files = {}
        self._direction = direction

        self._data_query = {}
        self._check_sql_file = utils.get_config_item(config, 'check_events', 'perform_checks')
        self._use_schema_name = utils.get_config_item(config, 'schema_name_in_query', direction, default=False)

        self._data_query["metadata_query"] = utils.get_config_item(config, 'metadata_query', default={})
        self._data_query["validate_query"] = utils.get_config_item(config, 'validate_query', default={})
        self._data_query["finalchk_query"] = utils.get_config_item(config, 'finalchk_query', default={})

        self._fetched_data = {"metadata_query": {}, 
                              "validate_query": {},
                              "finalchk_query": {}}

    @property
    def hash_qry_id(self):
        return self._hash_qry_id

    def get_data_list(self, data_query):
        if data_query not in self._fetched_data.keys():
            raise ValueError(f"Data query [{data_query}] does not exists.")
        item_data = self._fetched_data[data_query]
        res_list = [k for k,v in item_data.items()]
        res_list.sort()
        return res_list

    def add_fetched_data(self, data_query, qry_id, data):
        if data_query not in self._fetched_data.keys():
            raise ValueError(f"Data query [{data_query}] does not exists.")        
        fetched_data = self._fetched_data[data_query]
        fetched_data[qry_id] = data
    
    def get_data_by_id(self, data_query, qry_id):
       # Get data for a specific block.
        if data_query not in self._fetched_data.keys():
            raise ValueError(f"Data query [{data_query}] does not exists.")
        
        fetched_data = self._fetched_data[data_query]
        if qry_id not in fetched_data:
            raise ValueError(f"Fetched data for query [{qry_id}] not found.")
        
        return fetched_data[qry_id]        

    def get_metadata_list(self):
        return self.get_data_list('metadata_query')
   
    def get_validate_list(self):
        return self.get_data_list('validate_query')
    
    def get_finalcheck_list(self):
        return self.get_data_list('finalchk_query')

    def add_metadata(self, qry_id, data):
        self.add_fetched_data('metadata_query', qry_id, data)

    def add_validate(self, qry_id, data):
        self.add_fetched_data('validate_query', qry_id, data)
    
    def add_finalcheck(self, qry_id, data):
        self.add_fetched_data('finalchk_query', qry_id, data)

    def add_hashfile(self, table_name, full_path):
        self._hash_files[table_name] = full_path

    def get_hashfiles(self):
        return self._hash_files

    def get_metadata(self, qry_id: str) -> dict:
        return self.get_data_by_id('metadata_query', qry_id)
    
    def get_validate(self, qry_id: str) -> dict:
        return self.get_data_by_id('validate_query', qry_id)
    
    def get_finalcheck(self, qry_id: str) -> dict:
        return self.get_data_by_id('finalchk_query', qry_id)
  
    def iterate_metadata_query(self):
        if not self._sql_folder:
            raise ValueError(f"SQL folder not found!")
        file_sql = utils.path_join(self._sql_folder, self.METADATA_FILE)
        if not utils.file_exists(file_sql):
            raise FileNotFoundError(f"Metadata SQL file not found: [{file_sql}]")
        
        metadata_query = self._data_query.get("metadata_query") or {}
        for qry_id, description in metadata_query.items():
            sql = utils.extract_code_block(file_sql, qry_id)
            if sql and utils.is_hash_query(sql):
                self._hash_qry_id = qry_id
            yield qry_id, description, sql
    
    def iterate_validate_query(self):
        if not self._sql_folder:
            raise ValueError(f"SQL folder not found!")
        file_sql = utils.path_join(self._sql_folder, self.VALIDATE_FILE)
        if not utils.file_exists(file_sql):
            raise FileNotFoundError(f"Validation SQL file not found: {file_sql}")
        
        validate_query = self._data_query.get("validate_query") or {}
        for qry_id, description in validate_query.items():
            sql = utils.extract_code_block(file_sql, qry_id)
            yield qry_id, description, sql
    
    def iterate_finalcheck_query(self):
        file_sql = AppBase.get_sql_path(self._check_sql_file)
        if not utils.file_exists(file_sql):
            raise FileNotFoundError(f"Final check SQL file not found: {file_sql}")

        finalchk_query=self._data_query.get("finalchk_query") or {}
        for qry_id, description in finalchk_query.items():
            sql = utils.extract_code_block(file_sql, qry_id)
            yield qry_id, description, sql

    def save_metadata_csv(self, qry_id: str, cols: list, rows: list):
        """Assessment handles its own file operations."""
        path = AppBase.get_schema_path(self._direction)
        file_path = utils.path_join(path, f"metadata_{qry_id}.csv")
        utils.save_as_csv(file_path, rows if rows else [], cols)
        return file_path

    def save_validate_csv(self, qry_id: str, cols: list, rows: list):
        """Assessment handles its own file operations."""
        path = AppBase.get_schema_path(self._direction)
        file_path = utils.path_join(path, f"validation_{qry_id}.csv")
        utils.save_as_csv(file_path, rows if rows else [], cols)
        return file_path

    def read_metadata_csv(self, qry_id: str):
        """Read metadata from CSV file for source or target."""
        path = AppBase.get_schema_path(self._direction)
        file_path = utils.path_join(path, f"metadata_{qry_id}.csv")
        if not utils.file_exists(file_path):
            raise FileNotFoundError(f"Metadata CSV file not found: {file_path}")
        rows, cols = utils.read_csv_file(file_path)
        return rows, cols, file_path

    def read_validate_csv(self, qry_id: str):
        """Read validation data from CSV file for source or target."""
        path = AppBase.get_schema_path(self._direction)
        file_path = utils.path_join(path, f"validation_{qry_id}.csv")
        if not utils.file_exists(file_path):
            raise FileNotFoundError(f"Validation CSV file not found: {file_path}")
        rows, cols = utils.read_csv_file(file_path)
        return rows, cols, file_path


class SchemaProcessor:
    def __init__(self, db: DbConnector, config: dict, direction: str = "src"):
        if not db:
            raise ValueError("Database connector must be provided.")
        if not db.db_type:
            raise ValueError("Database type must be provided.")
        if direction not in ["src", "trg"]:
            raise ValueError("Migration side must be either 'src' or 'trg'.")
        
        self.direction = direction
        self.assessment = SchemaAssessment(db.db_type, config, direction)
        self.db = db

    def fetch_metadata_by_id(self, query: list):
        qry_id, description, sql = query
        print(f"\nFetching data for: [{qry_id}] {description}")
        if not sql:
            raise ValueError(SQL_CODE_NOT_EXISTS)
        cols, rows = self.db.prepare_data(sql, self.assessment._use_schema_name)
        print(f"Fetched {len(rows) if rows else 0} row(s) with columns: {cols}")
        if cols is None or len(cols) == 0:
            print(f"*** Warning: No columns returned for query [{qry_id}].")

        if new_rows := DataAdjustment.adjust(qry_id, rows, cols, self.direction):
            rows = new_rows

        return cols, rows

    def load_metadata(self):
        self.save_db_env()
        for query in self.assessment.iterate_metadata_query():
            qry_id = query[0]
            cols, rows = self.fetch_metadata_by_id(list(query))
            file_path = self.assessment.save_metadata_csv(qry_id, cols, rows)
            self.assessment.add_metadata(qry_id, (cols, rows))
            print(f"Data saved to {file_path}")

        # print("Data fetching completed.")
        return self

    def load_validation(self):
        for query in self.assessment.iterate_validate_query():
            qry_id = query[0]
            cols, rows = self.fetch_metadata_by_id(list(query))
            file_path = self.assessment.save_validate_csv(qry_id, cols, rows)
            self.assessment.add_validate(qry_id, (cols, rows))
            print(f"Data saved to {file_path}")

        # print("Data fetching completed.")
        return self
    
    def restore_metadata(self) -> None:
        for query in self.assessment.iterate_metadata_query():
            qry_id, description, _ = query
            print(f"\nFetching data for: [{qry_id}] {description}")
            rows, cols, file_path = self.assessment.read_metadata_csv(qry_id)
            print(f"Fetched {len(rows) if rows else 0} row(s) with columns: {cols}")
            self.assessment.add_metadata(qry_id, (cols, rows))
            print(f"Data restored from {file_path}")
    
    def restore_validation(self) -> None:
        for query in self.assessment.iterate_validate_query():
            qry_id, description, _ = query
            print(f"\nFetching data for: [{qry_id}] {description}")
            rows, cols, file_path = self.assessment.read_validate_csv(qry_id)
            print(f"Fetched {len(rows) if rows else 0} row(s) with columns: {cols}")
            self.assessment.add_validate(qry_id, (cols, rows))
            print(f"Data restored from {file_path}")

    def restore_hashes(self) -> None:
        hashes_dir = AppBase.get_hashes_path(self.direction.lower())
        hash_files = {}
        files = utils.get_all_files(hashes_dir)
        for file_name in files:
            hash_files[utils.cut_filename(file_name)] = file_name
        self.assessment._hash_files = hash_files
    
    @classmethod
    def run_final_check(cls, assessment: SchemaAssessment, db: DbConnector):
        for query in assessment.iterate_finalcheck_query():
            qry_id, description, sql = query
            print(f"\nChecking: [{qry_id}] {description}...")
            if not sql:
                raise ValueError(SQL_CODE_NOT_EXISTS)
            cols, rows = db.prepare_data(sql)
            print(f"Returned {len(rows) if rows else 0} issue(s)")

            assessment.add_finalcheck(qry_id, (cols, rows))
    
    def save_db_env(self):
        env_path = AppBase.get_schema_path(self.direction)
        AppBase.remove_path_contents(env_path)
        utils.FileOperations.ensure_directory(env_path)

        env_file = utils.path_join(env_path, '.db_env')
        # Write connection parameters as KEY=VALUE, excluding username and password
        params = {k: v for k, v in self.db.params.items() if k.lower() not in ("password")}
        with open(env_file, 'w', encoding='utf-8') as f:
            # add timestamp for reference
            f.write(f"# Generated on {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            for key, value in params.items():
                f.write(f"{key}={value}\n")
        return env_file