import pyodbc
import datetime, source_code.app_utils as utils
from source_code.dbbase_cls import DbConnector, DbConverter
from decimal import Decimal


class MssqlConvert(DbConverter):
    def __init__(self, debug: bool = False):
        super().__init__(debug)
        self._replaced_as_boolean = {}

    def _parse_conversion_rules(self) -> None:
        boolean_replacements = utils.get_config_item(self._conversion_config, 'replaced_as_boolean', default={})
        self._parse_replacement_rules(boolean_replacements)

    def _parse_replacement_rules(self, boolean_replacements: dict):
        self._replaced_as_boolean = {}
        for table_name, rules in boolean_replacements.items():
            self._replaced_as_boolean[table_name.upper()] = {}
            for rule in rules:
                parts = rule.split('|')
                if len(parts) == 3:
                    col_name, orig_type, values = parts
                    true_val, false_val = values.split(':')
                    self._replaced_as_boolean[table_name.upper()][col_name.upper()] = {
                        'original_type': orig_type,
                        'true_value': true_val,
                        'false_value': false_val
                    }

    def _convert_boolean(self, table_name: str, col: str, value: bool) -> str | None:
        replacement_rule = self._replaced_as_boolean.get(table_name.upper(), {}).get(col.upper())
        if replacement_rule:
            return replacement_rule['true_value'] if value else replacement_rule['false_value']
        return None

    def _convert_datetime(self, value: datetime.datetime) -> str:
        if value.tzinfo is not None:
            return value.strftime('%Y-%m-%d %H:%M:%S.%f %Z')
        return value.strftime('%Y-%m-%d %H:%M:%S.%f')

    def _convert_date(self, value: datetime.date) -> str:
        return value.strftime('%Y-%m-%d') + ' 00:00:00.000000'

    def _convert_time(self, value: datetime.time) -> str:
        return '1900-01-01 ' + value.strftime('%H:%M:%S')

    def to_str_value(self, table_name: str, col: str, value) -> str:
        if type(value) is bool and value is not None:
            converted = self._convert_boolean(table_name, col, value)
            if converted is not None:
                return converted

        if value is None:
            result = 'None'
        elif isinstance(value, (bytes, bytearray, memoryview)):
            result = DbConverter.convert_binary(value)
        elif isinstance(value, datetime.datetime):
            result = self._convert_datetime(value)
        elif isinstance(value, datetime.date):
            result = self._convert_date(value)
        elif isinstance(value, datetime.time):
            result = self._convert_time(value)
        elif isinstance(value, Decimal):
            result = DbConverter.convert_decimal(value)
        elif isinstance(value, float):
            result = DbConverter.convert_float(value)
        else:
            result = str(value)

        if self._debug:
            print(f"table: {table_name}, field: {col}, value type: {type(value)}, result: {result}")

        return result


class MssqlConnect(DbConnector):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = MssqlConvert()

    def connect(self):
        driver = self.params.get('driver', '{ODBC Driver 18 for SQL Server}')
        host = self.params.get('host')
        port = self.params.get('port')
        instance = self.params.get('instance')
        database = self.params.get('database') or self.params.get('dbname')
        username = self.params.get('username')
        password = self.params.get('password')
        trusted = self.params.get('trusted_connection') or self.params.get('trusted') or False

        if not host:
            raise ValueError("MSSQL connection parameter 'host' is required.")
        if not database:
            raise ValueError("MSSQL connection parameter 'database' is required.")

        server = host
        if instance:
            server = f"{server}\\{instance}"
        if port:
            server = f"{server},{port}"

        if trusted and not username and not password:
            conn_str = (
                f"Driver={driver};Server={server};Database={database};"
                "Trusted_Connection=yes;TrustServerCertificate=yes"
            )
        else:
            if username is None or password is None:
                raise ValueError(
                    "MSSQL username and password must be provided unless trusted_connection is enabled."
                )
            conn_str = (
                f"Driver={driver};Server={server};Database={database};"
                f"UID={username};PWD={password};TrustServerCertificate=yes"
            )

        self.connection = pyodbc.connect(conn_str, autocommit=False)
        return self

    def get_schema_param(self):
        return [self.schema] if self.schema else None

    def _execute_query(self, sql: str, params: list|None=None) -> tuple[list[str], list]:
        with self.connection.cursor() as cursor:
            if params:
                cursor.execute(sql, params)
            else:
                cursor.execute(sql)

            columns = [desc[0].upper() for desc in cursor.description] if cursor.description else []
            rows = [tuple(row) for row in cursor.fetchall()]

        self.connection.commit()
        return columns, rows

    def execute_sql(self, script_path: str):
        sql_script = utils.open_sql_file(script_path)

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            batch = []
            for line in sql_script.splitlines():
                if line.strip().upper() == '/':
                    statement = '\n'.join(batch).strip()
                    if statement:
                        cursor.execute(statement)
                    batch = []
                else:
                    batch.append(line)

            final_statement = '\n'.join(batch).strip()
            if final_statement:
                cursor.execute(final_statement)

            self.connection.commit()

    def execute_many(self, table: str, cols: list, data: list):
        if not data:
            return -1

        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)

        placeholders = ', '.join(['?'] * len(cols))
        insert_sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})"
        
        with self.connection.cursor() as cursor:
            cursor.executemany(insert_sql, data)
            row_count = cursor.rowcount
            if row_count == -1:
                row_count = len(data)

        self.connection.commit()
        return row_count

    def read_data_chunks(self, sql_query: str, chunk_size: int = 10000):
        if sql_query is None or sql_query.strip() == '':
            raise ValueError("SQL query is not specified.")

        if not self.connection:
            self.connect()

        offset = 0
        while True:
            chunk_query = f"{sql_query} OFFSET {offset} ROWS FETCH NEXT {chunk_size} ROWS ONLY"
            columns, chunk_data = self.execute(chunk_query)
            if not chunk_data:
                break
            yield columns, chunk_data
            if len(chunk_data) < chunk_size:
                break
            offset += chunk_size

    def bulk_insert(self, table_name: str, data: list, cols: list[str]) -> int:
        if not data:
            return -1

        values_placeholder = ', '.join(['?'] * len(cols))
        column_list = ', '.join(cols)
        insert_sql = f"INSERT INTO {table_name} ({column_list}) VALUES ({values_placeholder})"

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            cursor.executemany(insert_sql, data)
            row_count = cursor.rowcount
            if row_count == -1:
                row_count = len(data)

        self.connection.commit()
        return row_count

    def table_select(self, table_name: str, cols: list[str], pk_fields: list[str], pk_values: list[tuple]) -> tuple[list[str], list]:
        if not pk_fields or not pk_values:
            return [], []

        select_list = ', '.join(cols) if cols else '*'

        if len(pk_fields) == 1:
            placeholders = ', '.join(['?'] * len(pk_values))
            sql_select = f"SELECT {select_list} FROM {table_name} WHERE {pk_fields[0]} IN ({placeholders}) ORDER BY {pk_fields[0]}"
            params = tuple(val[0] if isinstance(val, (list, tuple)) else val for val in pk_values)
        else:
            conditions = []
            params = []
            for row in pk_values:
                if len(row) != len(pk_fields):
                    raise ValueError("Each composite PK tuple must match the number of pk_fields.")
                conditions.append('(' + ' AND '.join([f"{pk} = ?" for pk in pk_fields]) + ')')
                params.extend(row)
            sql_select = f"SELECT {select_list} FROM {table_name} WHERE {' OR '.join(conditions)} ORDER BY {', '.join(pk_fields)}"

        return self.execute(sql_select, list(params))

    def table_insert(self, table_name: str, data: list, cols: list[str]) -> int:
        if not data:
            return -1

        values_placeholder = ', '.join(['?'] * len(cols))
        column_list = ', '.join(cols)
        sql = f"INSERT INTO {table_name} ({column_list}) VALUES ({values_placeholder})"
        binds = [tuple(row) for row in data]

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            cursor.executemany(sql, binds)
            row_count = cursor.rowcount
            if row_count == -1:
                row_count = len(data)

        self.connection.commit()
        return row_count

    def table_update(self, table_name: str, data: list, cols: list[str], pk_fields: list[str]) -> int:
        if not data:
            return -1

        update_fields = [col for col in cols if col not in pk_fields]
        if not update_fields:
            return -2

        set_clause = ', '.join([f"{col} = ?" for col in update_fields])
        where_clause = ' AND '.join([f"{pk} = ?" for pk in pk_fields])
        sql = f"UPDATE {table_name} SET {set_clause} WHERE {where_clause}"

        binds = []
        for row in data:
            row_dict = dict(zip(cols, row))
            binds.append(tuple(row_dict.get(col) for col in update_fields + pk_fields))

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            cursor.executemany(sql, binds)
            row_count = cursor.rowcount

        self.connection.commit()
        return row_count

    def table_delete(self, table_name: str, pk_fields: list[str], pk_values: list) -> int:
        if not pk_values:
            return -1

        if len(pk_fields) == 1:
            sql = f"DELETE FROM {table_name} WHERE {pk_fields[0]} = ?"
            binds = [(val[0] if isinstance(val, (list, tuple)) else val,) for val in pk_values]
        else:
            conditions = []
            binds = []
            for row in pk_values:
                if len(row) != len(pk_fields):
                    raise ValueError("Each composite PK tuple must match the number of pk_fields.")
                conditions.append('(' + ' AND '.join([f"{pk} = ?" for pk in pk_fields]) + ')')
                binds.append(tuple(row))
            sql = f"DELETE FROM {table_name} WHERE {' OR '.join(conditions)}"

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            cursor.executemany(sql, binds)
            row_count = cursor.rowcount

        self.connection.commit()
        return row_count