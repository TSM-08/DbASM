import psycopg2, io
from source_code.dbbase_cls import DbConnector, DbConverter
import datetime, source_code.app_utils as utils
from decimal import Decimal


class PostgreConvert(DbConverter):
    def __init__(self, debug: bool = False):
        super().__init__(debug)
        self._replaced_as_boolean = {}

    def _parse_conversion_rules(self) -> None:
        boolean_replacements = utils.get_config_item(self._conversion_config, 'replaced_as_boolean', default={})
        self._parse_replacement_rules(boolean_replacements)

    def _parse_replacement_rules(self, boolean_replacements: dict):
        """Parse boolean replacement rules into usable format."""
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
        """Convert boolean value using replacement rules if available."""
        replacement_rule = self._replaced_as_boolean.get(table_name.upper(), {}).get(col.upper())
        if replacement_rule:
            return replacement_rule['true_value'] if value else replacement_rule['false_value']
        return None

    def _convert_datetime(self, value: datetime.datetime) -> str:
        """Convert datetime object to formatted string."""
        if value.tzinfo is not None:
            return value.strftime('%Y-%m-%d %H:%M:%S.%f %Z')
        return value.strftime('%Y-%m-%d %H:%M:%S.%f')

    def _convert_date(self, value: datetime.date) -> str:
        """Convert date object to formatted string with time set to 00:00:00."""
        return value.strftime('%Y-%m-%d') + ' 00:00:00.000000'

    def _convert_time(self, value: datetime.time) -> str:
        """Convert time object to formatted string with date set to 1900-01-01."""
        return '1900-01-01 ' + value.strftime('%H:%M:%S')
    
    def to_str_value(self, table_name: str, col: str, value) -> str:
        """Convert value to string representation based on type."""
        # Handle boolean with replacement rules
        if type(value) is bool and value is not None:
            converted = self._convert_boolean(table_name, col, value)
            if converted is not None:
                return converted

        # Type-based conversion dispatch
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


class PostgreConnect(DbConnector):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = PostgreConvert()

    def connect(self):
        # Establish a connection to the Oracle database.
        self.connection = psycopg2.connect(
            dbname=self.params.get("database"),
            host=self.params.get("host"),
            port=self.params.get("port"),
            user=self.params.get("username"),
            password=self.params.get("password")
        )

        # Set current schema to the specified schema
        with self.connection.cursor() as cursor:
            self.set_current_schema(cursor, self.schema)
        
        return self

    @staticmethod
    def set_current_schema(cur, schema_name):
        if cur and schema_name:
            cur.execute(f"SET search_path TO {schema_name}")

    def get_schema_param(self):
        return [self.schema] if self.schema else None

    def _execute_query(self, sql: str, params: list|None=None) -> tuple:
        """
        Execute a SQL query and return the results.

        Args:
            sql (str): The SQL query to execute.
            params (list, optional): Parameters for the query.

        Returns:
            tuple: (columns, results)
        """  
        with self.connection.cursor() as cursor:
            cursor.execute(sql, params)
            # Get column names from cursor description
            if cursor.description:
                columns = [desc[0].upper() for desc in cursor.description]
            else:
                columns = []      
            # Fetch all results
            if not (results := cursor.fetchall()):
                results = []

        self.connection.commit()

        return columns, results    

    def execute_sql(self, script_path: str):
        """
        Execute a SQL script file on the connected database.

        Args:
            script_path (str): Full path to the SQL script file.
            params (list, optional): Parameters for the script, if any.

        Returns:
            None
        """
        sql_script = utils.open_sql_file(script_path)

        if not self.connection or self.connection.closed:
            self.connect()

        with self.connection.cursor() as cursor:
            for statement in filter(None, sql_script.split('/')):
                stmt = statement.strip()
                if stmt:
                    cursor.execute(stmt)
            self.connection.commit()

    def execute_many(self, table: str, cols: list, data: list):
        row_count = -1
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)

        placeholders = ', '.join(['%s'] * len(cols))
        insert_sql = f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({placeholders})"        

        with self.connection.cursor() as cursor:
            cursor.executemany(insert_sql, data if data else [])
            row_count = cursor.rowcount

        self.connection.commit()
        return row_count

    def read_data_chunks(self, sql_query: str, chunk_size: int = 10000):
        """
        Read data from a table in chunks until the end.

        Args:
            sql_query: The SQL query to execute.
            chunk_size: Number of records per chunk (default: 10000).

            Yields:
                tuple: (columns, chunk_data) for each chunk.
        """
        if sql_query is None or sql_query.strip() == '':
            raise ValueError("SQL query is not specified.")

        if not self.connection:
            self.connect()

        offset = 0        
        has_more_data = True

        while has_more_data:
            # Add LIMIT and OFFSET for pagination
            chunk_query = f"{sql_query} OFFSET {offset} ROWS FETCH NEXT {chunk_size} ROWS ONLY"

            try:
                columns, chunk_data = self.execute(chunk_query)

                if not chunk_data or len(chunk_data) == 0:
                    # No more data
                    has_more_data = False
                    break

                yield columns, chunk_data
                
                # Check if we got less than chunk_size records (end of data)
                if len(chunk_data) < chunk_size:
                    has_more_data = False
                
                offset += chunk_size

            except Exception as e:
                raise RuntimeError(f"Failed to read chunk at offset {offset}: {e}")

    def bulk_insert(self, table_name: str, data: list, cols: list[str]) -> int:
        copy_sql = f"""
            COPY {table_name} ({", ".join(cols)})
            FROM STDIN
            WITH (FORMAT csv, HEADER false, DELIMITER ',');
            """
        with self.connection.cursor() as cur:
            # Wrap chunk in a file-like object
            chunk_stream = io.StringIO("".join(data))
            cur.copy_expert(copy_sql, chunk_stream)
        self.connection.commit()

        return len(data)
    
    def table_select(self, table_name: str, cols: list[str], pk_fields: list[str], 
                     pk_values: list[tuple]) -> tuple[list[str], list]:
        if not pk_fields or not pk_values:
            return [], []

        select_list = ', '.join(cols) if cols else '*'
        pk_field = pk_fields[0] if len(pk_fields) == 1 else f"({', '.join(pk_fields)})"
        
        if len(pk_fields) == 1:
            # --- Single column PK ---
            sql_select = f"""
                SELECT {select_list}
                FROM {table_name}
                WHERE {pk_field} IN %s
                ORDER BY {pk_field};
            """
            params = (tuple([val[0] for val in pk_values]),)
        else:
            # --- Composite PK ---
            field_list = ', '.join(pk_fields)
            placeholders = ', '.join(['(' + ', '.join(['%s'] * len(pk_fields)) + ')' for _ in pk_values])

            sql_select = f"""
                SELECT {select_list}
                FROM {table_name}
                WHERE ({field_list}) IN (
                    VALUES {placeholders}
                )
                ORDER BY {field_list};
            """
            params = tuple([item for tup in pk_values for item in tup])

        with self.connection.cursor() as cursor:
            cursor.execute(sql_select, params)
            if cursor.description:
                columns = [desc[0].upper() for desc in cursor.description]
            else:
                columns = []
            results = cursor.fetchall()
        # self.connection.commit()

        return columns, results