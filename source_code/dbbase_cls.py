"""
Abstract base classes for database connectors and converters.

This module provides the foundational classes for database connectivity and data conversion
in the migration assessment system.
"""
import base64
from decimal import Decimal
from abc import ABC, abstractmethod
from . import app_utils as utils
from .app_utils import List, Any


class DbConverter(ABC):
    """Abstract base class for database value conversion."""
    def __init__(self, debug: bool = False):
        self._conversion_count = 0
        self._conversion_config = {}
        self._debug = debug

    @staticmethod
    def convert_binary(value: bytes | bytearray | memoryview) -> str:
        # Convert binary data to base64-encoded string
        if isinstance(value, memoryview):
            value = value.tobytes()
        encoded = base64.b64encode(value)
        return encoded.decode('utf-8')

    @staticmethod
    def convert_decimal(value: Decimal) -> str:
        """Convert Decimal to string, removing unnecessary decimals for whole numbers."""
        if value.to_integral_value() == value:
            return str(int(value))  # Remove .0 for whole numbers
        return format(value.normalize(), 'f')  # Remove trailing zeros

    @staticmethod
    def convert_float(value: float) -> str:
        """Convert float to string, removing unnecessary decimals and trailing zeros."""
        try:
            d = Decimal(str(value))
        except Exception:
            return str(value)
        return DbConverter.convert_decimal(d)  

    def _parse_conversion_rules(self) -> None:
        pass

    def set_config(self, config: dict) -> None:
        """
        Set configuration for the converter.

        Args:
            config (dict): Configuration parameters.
        """
        self._conversion_config = config
        self._parse_conversion_rules()

    @property
    def conversion_count(self) -> int:
        return self._conversion_count

    @abstractmethod
    def to_str_value(self, table_name, col, val) -> str:
        """
        Convert a value to its string representation.

        Args:
            val: The value to convert.

        Returns:
            str: The string representation of the value.
        """
        pass

    def convert_row(self, table_name: str, cols: List[str], row: List[Any]) -> List[str]:
        """
        Convert an entire row of values to string representations.

        Args:
            table_name: Name of the table.
            cols: List of column names.
            row: List of values to convert.
            
        Returns:
            List of string representations.
        """
        if len(cols) != len(row):
            raise ValueError(f"Column count {len(cols)} does not match row value count {len(row)} for table {table_name}.")

        converted = []
        for val, col in zip(row, cols):
            try:
                converted.append(self.to_str_value(table_name, col, val))
                self._conversion_count += 1
            except Exception as e:
                converted.append(str(val))  # Fallback to basic string conversion

        return converted

    def reset_stats(self) -> None:
        """Reset conversion statistics."""
        self._conversion_count = 0


class DbConnector(ABC):
    Table_Autocommit = True
    # Constants
    SQL_CODE_EMPTY = "An empty SQL statement is passed as a parameter."
    NO_DB_CONNECTION = "Database connection is not established."
    """
    Abstract base class for database connectors.
    Handles connection, query execution, and data preparation.
    """

    def __init__(self, debug: bool = False, **params):
        """
        Initialize the connector with parameters.

        Args:
            **params: Arbitrary keyword arguments for connection.
        """        
        self.params = params
        self.schema = params.get('schema')
        self.db_type = params.get('type')
        self.converter: DbConverter | None = None
        self.connection = None
        self.debug = debug

    def __enter__(self):
        """
        Context manager entry. Establishes the connection.

        Returns:
            DbConnector: The connector instance.
        """        
        self.connect()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        """
        Context manager exit. Closes the connection.

        Args:
            exc_type: Exception type.
            exc_value: Exception value.
            traceback: Traceback object.
        """        
        self.close()

    @abstractmethod
    def connect(self):
        """
        Establish a database connection.
        """
        pass

    @abstractmethod
    def get_schema_param(self):
        """
        Get schema parameters for the database connection.

        Returns:
            list: Parameters for schema queries.
        """
        pass

    @abstractmethod
    def read_data_chunks(self, sql_query: str, chunk_size: int = 10000):
        """
        Read data from a table in chunks until the end.

        Args:
            sql_query (str): The SQL query to execute.
            chunk_size (int): Number of records per chunk (default: 10000).

        Yields:
            tuple: (columns, chunk_data) for each chunk.
        """
        yield [], []

    def dynamic_sql_one(self, rows: List[List[Any]]) -> str:
        queries = []
        for row in rows:
            sql = str(row[0]).rstrip(';')
            if sql.upper().startswith('SELECT'):
                queries.append(sql)

        return ' UNION ALL '.join(queries)

    def dynamic_sql_gen(self, rows: List[List[Any]], title: List[str]) -> str:
        if utils.get_position(title, "SQL") == -1:
            raise ValueError("Dynamic column 'SQL' is missing in the query.")
                
        queries = []
        for row in rows:
            sql, cols = '', ''
            for i, col in enumerate(title):
                if col.lower() == "sql":
                    sql = str(row[i]).rstrip(';')
                else:
                    cols += f"'{row[i]}' as {col}, "
            queries.append(f"SELECT {cols} a.*  FROM ({sql}) a")   
        
        query = ' union all '.join(queries)
        return query

    @abstractmethod
    def _execute_query(self, sql: str, params: list|None=None) -> tuple[list[str], list[list]]:
        """
        Execute a SQL query and return the results.

        Args:
            sql (str): The SQL query to execute.
            params (list, optional): Parameters for the query.
        """
        pass

    def execute(self, sql: str, params: List[Any] | None = None) -> tuple:
        """
        Execute a SQL query and return the results.

        Args:
            sql (str): The SQL query to execute.
            params (list, optional): Parameters for the query.

        Returns:
            tuple: (columns, results)
        """
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if sql is None or sql.strip() == '':
            raise ValueError(DbConnector.SQL_CODE_EMPTY)

        result = self._execute_query(sql, params)
        return result

    @abstractmethod
    def execute_many(self, table: str, cols: list, data: list) -> int:
        pass

    @abstractmethod
    def execute_sql(self, script_path: str):
        """
        Execute a SQL script file on the connected database.

        Args:
            script_path (str): Full path to the SQL script file.
            params (list, optional): Parameters for the script, if any.

        Returns:
            None
        """
        pass

    def prepare_data(self, sql: str, use_schema_param: bool = False) -> tuple:
        """
        Execute a SQL query and return the results.

        Args:
            sql (str): The SQL query to execute.

        Returns:
            tuple: (columns, rows)
        """
        if not sql:
            raise ValueError(DbConnector.SQL_CODE_EMPTY)
        if not self.connection:
            self.connect()

        sql = sql.rstrip(';')

        schema_param = self.get_schema_param()
        cols, rows = self.execute(sql=sql, params=schema_param if use_schema_param else None)
        if not utils.has_dyn_query(sql):
            return cols, rows
        if rows is None or len(rows) == 0:
            return [], []
        return self.prepare_data_dyn(cols, rows)

    def prepare_data_dyn(self, title: List[str], rows: List[List[Any]] | None):
        """
        Prepare and execute dynamic SQL queries from metadata.

        Args:
            title (list): List of column names.
            rows (list[list] | None): List of row data or None.

        Returns:
            tuple: (columns, rows)
        """
        pos = utils.get_position(title, "SQL")
        if pos == -1:
            raise ValueError("Dynamic column 'SQL' is missing in the query.")        
        if rows is None:
            return title, []
        if pos > 0:
            query = self.dynamic_sql_gen(rows, title)
        else:
            query = self.dynamic_sql_one(rows)
        return self.execute(query)

    def commit(self):
        """
        Commit the current transaction.
        """        
        if self.connection:
            self.connection.commit()

    def rollback(self):
        """
        Rollback the current transaction.
        """        
        if self.connection:
            self.connection.rollback()            

    def close(self):
        """
        Close the database connection.
        """        
        if self.connection:
            self.connection.close()
            self.connection = None

    def bulk_insert(self, table_name: str, data: list, 
                    cols: list[str]) -> int:
        """
        Perform bulk insert into a table.

        Args:
            table_name (str): Name of the table.
            cols (list): List of column names.
            data (list[list]): List of row data.

        Returns:
            int: Number of rows inserted.
        """
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not data:
            return -1

        return 0 # Placeholder for actual bulk insert implementation

    def table_select(self, table_name: str, cols: list[str],
                     pk_fields: list[str], pk_values: list) -> tuple[list[str], list[list]]:
        """
        Perform table select from a table based on primary key values.  

        Args:
            table_name (str): Name of the table.    
            cols (list): List of column names.
            pk_fields (list): Primary key field(s),
            pk_values (list): List of primary key values to select.
        Returns:
            tuple: (columns, rows)
        """
        if not self.connection:
            self.connect()
        
        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not pk_values:
            return cols, []
        return cols, []  # Placeholder for actual select implementation

    def table_insert(self, table_name: str, data: list, 
                    cols: list[str]) -> int:
        """
        Perform table insert into a table.

        Args:
            table_name (str): Name of the table.
            cols (list): List of column names.
            data (list[list]): List of row data.

        Returns:
            int: Number of rows inserted.
        """
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not data:
            return -1

        return 0 # Placeholder for actual bulk insert implementation

    def table_update(self, table_name: str, data: list,  
                    cols: list[str], pk_fields: list[str]) -> int:
        """
        Perform table update into a table based on primary key.

        Args:
            table_name (str): Name of the table.
            cols (list): List of column names.
            data (list[list]): List of row data.
            pk_field (str): Primary key field(s), can be composite separated by '|'.

        Returns:
            int: Number of rows updated.
        """
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not data:
            return -1

        return 0  # Placeholder for actual bulk update implementation

    def table_delete(self, table_name: str, pk_fields: list[str],
                    pk_values: list) -> int:
        """
        Perform table delete from a table based on primary key values.

        Args:
            table_name (str): Name of the table.
            pk_field (str): Primary key field(s), can be composite separated by '|'.
            pk_values (list): List of primary key values to delete.

        Returns:
            int: Number of rows deleted.
        """
        if not self.connection:
            self.connect()

        if self.connection is None:
            raise RuntimeError(DbConnector.NO_DB_CONNECTION)
        if not pk_values:
            return -1

        return 0  # Placeholder for actual bulk delete implementation