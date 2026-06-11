from . import app_utils as utils
from .as_schema import SchemaProcessor
from .app_base import AppBase
from .dbbase_cls import DbConnector
from .gen_hash import HashMaker 
from typing import Optional


class FinalAssessment:
    def __init__(self, config: dict, 
                 schema_src: SchemaProcessor, 
                 schema_trg: SchemaProcessor,
                 db_connect: Optional[DbConnector] = None) -> None:
        if not schema_src:
            raise ValueError("Source SchemaProcessor instance must be provided.")
        if not schema_trg:
            raise ValueError("Target SchemaProcessor instance must be provided.")

        self._schema_src = schema_src
        self._schema_trg = schema_trg
        self._config = config
        self._fetch_rows = config.get('hashing', {}).get('csv_chunk_rows', 10_000)
        self._db_connect = db_connect or schema_trg.db

        self._remove_assessment_schemas()
        self._init_assessment_schema(direction="src")
        self._init_assessment_schema(direction="trg")

    def _remove_assessment_schemas(self):
        schema_sql_path = AppBase.get_sql_path('clean_up.sql')
        self._db_connect.execute_sql(schema_sql_path)

    def _init_assessment_schema(self, direction: str):
        # Read, replace, and run SQL script
        for item in ['metadata', 'validation']:
            schema_sql_path = AppBase.get_sql_path(f'{item}.sql')
            with open(schema_sql_path, 'r', encoding='utf-8') as f:
                sql_script = f.read().replace("<schema_name>", direction)
            # Save to a temp file or run directly
            from tempfile import NamedTemporaryFile
            with NamedTemporaryFile('w+', delete=False, suffix='.sql', encoding='utf-8') as tmp:
                tmp.write(sql_script)
                tmp_path = tmp.name

            self._db_connect.execute_sql(tmp_path)
            utils.remove_file(tmp_path)

    def create_indexes(self):
        sql_path = AppBase.get_sql_path('pgs_indexes.sql')
        self._db_connect.execute_sql(sql_path)

    def cross_checking(self) -> bool:
        sql_path = AppBase.get_sql_path('check_assm.sql')
        self._db_connect.execute_sql(sql_path)
        sql = "SELECT COUNT(case when issue_type = 'Error' then 1 else null end) err_cnt, " \
              "COUNT(case when issue_type = 'Warning' then 1 else null end) warn_cnt " \
              "FROM {schema}.cross_checking"

        _, src = self._db_connect.execute(sql.format(schema='src'))
        print(f"Source cross-checking - Errors: {src[0][0]}, Warnings: {src[0][1]}")
        if src[0][0] > 0:
            print ("---------------------------------------------------")
            err_sql = "SELECT * FROM {schema}.cross_checking WHERE issue_type = 'Error'"
            for row in self._db_connect.execute(err_sql.format(schema='src'))[1]:
                print(row)
            print ("---------------------------------------------------")

        _, trg = self._db_connect.execute(sql.format(schema='trg'))
        print(f"Target cross-checking - Errors: {trg[0][0]}, Warnings: {trg[0][1]}")
        if trg[0][0] > 0:
            print ("---------------------------------------------------")
            err_sql = "SELECT * FROM {schema}.cross_checking WHERE issue_type = 'Error'"
            for row in self._db_connect.execute(err_sql.format(schema='trg'))[1]:
                print(row)
            print ("---------------------------------------------------")

        if src[0][0] > 0 or trg[0][0] > 0:
            return False
        return True

    def _perform_metadata_insert(self, direction: str):
        if direction not in ['src', 'trg']:
            raise ValueError("Direction must be either 'src' or 'trg'.")

        assessment = self._schema_trg.assessment
        for qry_id in assessment.get_metadata_list():
            table = f'metadata_{qry_id}'
            print(f"Inserting data for {table} from query ID {qry_id}...")            

            if qry_id == assessment.hash_qry_id:
                self._perform_hash_insert(direction, table)
            else:
                cols, data = self._schema_src.assessment.get_metadata(qry_id) \
                    if direction == 'src' else self._schema_trg.assessment.get_metadata(qry_id)

                col_names = ', '.join(cols)
                placeholders = ', '.join(['%s'] * len(cols))
                insert_sql = f"INSERT INTO {direction}.{table} ({col_names}) VALUES ({placeholders})"
                self._db_connect.execute_many(insert_sql, data)
                print(f"   Total rows inserted: {len(data)}")

    def _perform_validate_insert(self, direction: str):
        if direction not in ['src', 'trg']:
            raise ValueError("Direction must be either 'src' or 'trg'.")

        assessment = self._schema_trg.assessment
        for qry_id in assessment.get_validate_list():
            table = f'validation_{qry_id}'
            print(f"Inserting data for {table} from query ID {qry_id}...")

            if qry_id == assessment.hash_qry_id:
                self._perform_hash_insert(direction, table)
            else:
                cols, data = self._schema_src.assessment.get_validate(qry_id) \
                    if direction == 'src' else self._schema_trg.assessment.get_validate(qry_id)

                col_names = ', '.join(cols)
                placeholders = ', '.join(['%s'] * len(cols))
                insert_sql = f"INSERT INTO {direction}.{table} ({col_names}) VALUES ({placeholders})"
                self._db_connect.execute_many(insert_sql, data)
                print(f"   Total rows inserted: {len(data)}")

    def _perform_hash_insert(self, direction: str, hash_table: str):
        if direction not in ['src', 'trg']:
            raise ValueError("Direction must be either 'src' or 'trg'.")

        assessment = self._schema_trg.assessment
        hash_files = assessment.get_hashfiles() if direction == 'trg' \
            else self._schema_src.assessment.get_hashfiles()

        chunk_rows = self._fetch_rows
        total_rows_inserted = 0

        for table_name, file_path in hash_files.items():
            print(f"   Hash row populating for table: {table_name}")

            rows_inserted = 0
            with open(file_path, "r", encoding="utf-8") as f:
                # Skip header once
                _ = f.readline()
                while True:
                    lines = [line for 
                             line in [f.readline() for _ in range(chunk_rows)] 
                             if line]
                    if not lines:
                        break

                    rows_inserted += self._db_connect.bulk_insert(
                                            table_name=f"{direction}.{hash_table}", 
                                            data=lines,
                                            cols=HashMaker.HASH_COLS                                        )
            total_rows_inserted += rows_inserted
            print(f"   \\. Done: {rows_inserted} row(s) inserted")

        print(f"   Total rows inserted: {total_rows_inserted}")

    def store_data_assessment(self, direction: str = 'src'):
        # Load assessment data from the database
        self._perform_metadata_insert(direction=direction)
        self._perform_validate_insert(direction=direction)

    def run_final_assessment(self):
        assessment = self._schema_trg.assessment
        SchemaProcessor.run_final_check(assessment, self._db_connect)
        return assessment

    def run_precheck(self):
        assessment = self._schema_trg.assessment
        SchemaProcessor.run_precheck(assessment, self._db_connect)
        return assessment

    def run_detect_updates(self):
        assessment = self._schema_trg.assessment
        SchemaProcessor.run_discrepancy(assessment, self._db_connect)
        return assessment
    
    def run_rollback_check(self):
        assessment = self._schema_trg.assessment
        SchemaProcessor.run_rollback_check(assessment, self._db_connect) 
        return assessment