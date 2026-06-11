import oracledb
from source_code.dbbase_cls import DbConnector, DbConverter
import datetime, source_code.app_utils as app_utils
from decimal import Decimal


class OracleConvert(DbConverter):
    def __init__(self, debug: bool = False):
        super().__init__(debug)

    def _convert_datetime(self, value: datetime.datetime) -> str:
        # Handle datetime objects (includes timezone info if present)
        if value.tzinfo is not None:
            # Include milliseconds and timezone if present
            ms = value.strftime('%f')[:6]  # Get first 6 digits for microseconds
            tz = value.strftime(' %Z') if value.tzinfo else ''
            result = value.strftime('%Y-%m-%d %H:%M:%S') + f'.{ms}{tz}'
        else:
            ms = value.strftime('%f')[:6]
            result = value.strftime('%Y-%m-%d %H:%M:%S') + f'.{ms}'
        return result
    
    def _convert_date(self, value: datetime.date) -> str:
        # Handle date-only objects (no time component)
        return value.strftime('%Y-%m-%d')
    
    def _convert_time(self, value: datetime.time) -> str:
        # Handle time-only objects
        return '1900-01-01 ' + value.strftime('%H:%M:%S')
    
    def to_str_value(self, table_name, col, value) -> str:
        if value is None:
            result = 'None'
        elif isinstance(value, oracledb.LOB):
            result = value.read()
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
        
        if isinstance(result, (bytes, bytearray, memoryview)):
            result = DbConverter.convert_binary(result)

        if self._debug:
             print(f"table: {table_name}, field: {col}, value type: {type(value)}, result: {result}")
        
        return result


class OracleConnect(DbConnector):
    def __init__(self, **params):
        super().__init__(**params)

        if params.get("tns_alias"):
            self.dsn = params.get("tns_alias")
            ora_path = params.get("ora_path")
            if ora_path:
                oracledb.init_oracle_client(lib_dir= rf"{ora_path}")
        else:
            host = params.get("host")
            port = params.get("port", 1521)
            service_name = params.get("service_name")
            if any(param is None for param in [host, service_name]):
                raise ValueError("Database connection parameters 'host' and 'service_name' must be provided.")
            self.dsn = oracledb.makedsn(str(host), int(port), str(service_name))
        self.converter = OracleConvert()

    def connect(self):
        # Establish a connection to the Oracle database.
        username = self.params.get("username")
        password = self.params.get("password")

        if username is None and password is None:
            # Passwordless connection using wallet/certificate
            self.connection = oracledb.connect(
                dsn=self.dsn    
            )
        else:
            self.connection = oracledb.connect(
                user=username,
                password=password,
                dsn=self.dsn
            )

        # Set current schema to the specified schema
        with self.connection.cursor() as cursor:
            if self.schema:
                cursor.execute(f"ALTER SESSION SET CURRENT_SCHEMA = {self.schema}")

        # Set output type handler to automatically convert CLOBs to strings
        self.connection.outputtypehandler = self._output_type_handler        
        
        return self

    def _output_type_handler(self, cursor, name, defaultType, size, precision, scale):
        """
        Custom output type handler to automatically convert CLOB/BLOB to string.
        """
        # Convert CLOB to string automatically
        if defaultType == oracledb.DB_TYPE_CLOB:
            return cursor.var(oracledb.DB_TYPE_LONG, arraysize=cursor.arraysize)

        # Convert NCLOB to string automatically
        if defaultType == oracledb.DB_TYPE_NCLOB:
            return cursor.var(oracledb.DB_TYPE_LONG_NVARCHAR, arraysize=cursor.arraysize)
                
        # Convert BLOB to bytes automatically (optional)
        #if defaultType == oracledb.DB_TYPE_BLOB:
        #    return cursor.var(oracledb.DB_TYPE_LONG_RAW, arraysize=cursor.arraysize)

    def get_schema_param(self):
        return {"idc": self.schema} if self.schema else None

    def _execute_query(self, sql: str, params: list|None=None):
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
            columns = [desc[0].upper() for desc in cursor.description]
            # Fetch all results
            if not (results := cursor.fetchall()):
                return columns, []

            # Convert results to a list of dictionaries
            # results = [dict(zip(columns, row)) for row in results]
        
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
        sql_script = app_utils.open_sql_file(script_path)

        if not self.connection:
            self.connect()

        with self.connection.cursor() as cursor:
            for statement in filter(None, sql_script.split('/')):
                stmt = statement.strip()
                if stmt:
                    cursor.execute(stmt)
            self.connection.commit()
    
    def execute_many(self, sql: str, data: list):
        row_count = -1
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)

        with self.connection.cursor() as cursor:
            cursor.executemany(sql, data if data else [])
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

    def _bind_input_sizes(self, cols: list[str], binds: list[dict]):
        input_sizes = {}
        for col in cols:
            # Check if the value is datetime and set type explicitly
            sample_val = None
            for b in binds:
                if b.get(col) is not None:
                    sample_val = b[col]
                    break
            if isinstance(sample_val, datetime.datetime):
                input_sizes[f"{col}"] = oracledb.TIMESTAMP
        return input_sizes

    def table_update(self, table_name: str, data: list, cols: list[str],
                    pk_fields: list[str]) -> int:
        """
        Update multiple rows when every row has the same update fields.
        'data' is a list of tuples (row results from SELECT).
        'cols' is the list of column names corresponding to data tuples.
        """
        if not data:
            return -1

        update_fields = [col for col in cols if col not in pk_fields]
        if not update_fields:
            return -2
        
        # Build SQL like:
        # UPDATE "table" SET "c1"=:c1, "c2"=:c2 WHERE "pk1"=:pk1 AND "pk2"=:pk2
        set_clause = ", ".join([f'"{c}" = :{c}' for c in update_fields])
        where_clause = " AND ".join([f'"{pk}" = :{pk}' for pk in pk_fields])
        sql = f'UPDATE "{table_name}" SET {set_clause} WHERE {where_clause}'

        # Bind order should match the placeholders, but with named binds it's flexible.
        # Still, ensure each row dict has all keys required.
        bind_keys = update_fields + pk_fields

        # Convert tuples to dicts using cols as keys
        binds = []
        for row in data:
            row_dict = dict(zip(cols, row))
            b = {k: row_dict.get(k, None) for k in bind_keys}
            binds.append(b)
        
        conn_close = False
        if not self.connection:
            self.connect()
            conn_close = True

        try:
            with self.connection.cursor() as cur:
                input_sizes = self._bind_input_sizes(bind_keys, binds)
                if input_sizes:
                    cur.setinputsizes(**input_sizes)
                
                # executemany() with array binding
                cur.executemany(sql, binds, batcherrors=True, arraydmlrowcounts=True)

                # optional: inspect per-row results
                rowcounts = cur.getarraydmlrowcounts()  # one count per bound row
                # Commit
                if conn_close or self.Table_Autocommit:
                    self.connection.commit()
                return sum((rc if isinstance(rc, int) else 0) for rc in rowcounts)
        finally:
            if conn_close:
                self.close()
    
    def table_insert(self, table_name: str, data: list, cols: list[str]) -> int:
        """
        Perform bulk insert into a table.
        'data' is a list of tuples (row results from SELECT).
        'cols' is the list of column names corresponding to data tuples.
        """
        if not data:
            return -1

        # Build SQL like:
        # INSERT INTO table (c1, c2, c3) VALUES (:c1, :c2, :c3)
        col_names = ", ".join([f'"{col}"' for col in cols])
        placeholders = ", ".join([f":{col}" for col in cols])
        sql = f'INSERT INTO "{table_name}" ({col_names}) VALUES ({placeholders})'

        # Convert tuples to dicts using cols as keys
        binds = []
        for row in data:
            row_dict = dict(zip(cols, row))
            binds.append(row_dict)
        
        close_conn = False
        if not self.connection:
            close_conn = True
            self.connect()

        try:
            with self.connection.cursor() as cur:
                input_sizes = self._bind_input_sizes(cols, binds)
                if input_sizes:
                    cur.setinputsizes(**input_sizes)
                
                # executemany() with array binding
                cur.executemany(sql, binds, batcherrors=True, arraydmlrowcounts=True)

                # optional: inspect per-row results
                rowcounts = cur.getarraydmlrowcounts()  # one count per bound row
                # Commit
                if close_conn or self.Table_Autocommit:
                    self.connection.commit()
                return sum((rc if isinstance(rc, int) else 0) for rc in rowcounts)
        finally:
            if close_conn:
                self.close()


    def table_delete(self, table_name: str, pk_fields: list[str],
                    pk_values: list) -> int:
        """
        Perform bulk delete from a table based on primary key values.

        Args:
            table_name (str): Name of the table.
            pk_field (str): Primary key field(s), can be composite separated by '|'.
            pk_values (list): List of primary key values to delete.

        Returns:
            int: Number of rows deleted.
        """
        close_conn = False
        if not self.connection:
            self.connect()
            close_conn = True

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not pk_values:
            return -1

        # Build SQL like:
        # DELETE FROM "table" WHERE pk = :pk
        pk_field_list = ", ".join([f'"{pk}"' for pk in pk_fields])
        placeholders = ", ".join([f":{pk_field}" for pk_field in pk_fields])
        sql = f'DELETE FROM "{table_name}" WHERE ({pk_field_list} IN ({", ".join([f"({placeholders})"] * len(pk_values))}))'

        try:
            with self.connection.cursor() as cur:
                # Prepare bind values for each row in pk_values
                binds = []
                for val in pk_values:
                    if isinstance(val, list):
                        bind_dict = dict(zip(pk_fields, val))
                    else:
                        bind_dict = {pk_fields[0]: val}
                    binds.append(bind_dict)

                cur.executemany(sql, binds, batcherrors=True, arraydmlrowcounts=True)
                rowcounts = cur.getarraydmlrowcounts()
                if close_conn or self.Table_Autocommit:
                    self.connection.commit()
                return sum((rc if isinstance(rc, int) else 0) for rc in rowcounts)
        finally:
            if close_conn:
                self.close()