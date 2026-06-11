from . import app_utils as utils
from databases.Oracle.connector import OracleConnect
from databases.Postgres.connector import PostgreConnect


class AppBase:
    """
    Utility class for application-wide constants, path management, and configuration loading.
    """

    # Constants for directory and file management
    BASE_PATH = ""  # To be set at runtime
    SCHEMA_DIR = "schemas"
    SRC_FOLDER = "src"
    TRG_FOLDER = "trg"
    SQL_FOLDER = "sql_scripts"
    ORA_FOLDER = "oracle"
    _debug = False

    SECTION_LENGTH = 90 # Length of section separators in logs or outputs

    # Mapping of database type to connector class and optional convertor key
    DB_CONNECTOR_MAP = {
        'Oracle': (OracleConnect, None),
        'Postgres': (PostgreConnect, "pgs_converter")
    }

    # Mapping of database type to SQL scripts folder name
    SQL_FOLDER_MAP = {
        'Oracle': 'databases\\Oracle',
        'Postgres': 'databases\\Postgres',
    }

    @classmethod
    def set_debug(cls, debug: bool):
        cls._debug = debug  
    
    @classmethod
    def is_debug(cls) -> bool:
        return cls._debug

    @staticmethod
    def _check_base_path():
        if not AppBase.BASE_PATH:
            raise ValueError("BASE_PATH is not specified.")

    @staticmethod
    def open_base_config() -> dict:
        """
        Open the base configuration file.

        Returns:
            dict: The contents of the configuration file.
        """
        AppBase._check_base_path()
        file_path: str = utils.path_join(AppBase.BASE_PATH, 'config.yaml')
        return utils.open_config(file_path)

    @staticmethod
    def open_connection_config() -> dict:
        """
        Open the connection configuration file.

        Returns:
            dict: The contents of the connections configuration.
        """
        AppBase._check_base_path()
        file_path: str = utils.path_join(AppBase.BASE_PATH, 'connection.yaml')
        return utils.open_config(file_path)
        
    @staticmethod
    def open_type_config() -> dict:
        """
        Open the database type configuration file.

        Returns:
            dict: The contents of the configuration file.
        """
        AppBase._check_base_path()
        file_path: str = utils.path_join(AppBase.BASE_PATH, 'ora2pg.yaml')
        return utils.open_config(file_path)

    @staticmethod
    def get_sql_path(file_name: str|None=None) -> str:
        AppBase._check_base_path()
        sql_path = AppBase.SQL_FOLDER or ''
        if file_name:
            return utils.path_join(AppBase.BASE_PATH, sql_path, file_name)
        return utils.path_join(AppBase.BASE_PATH, sql_path)
    
    @staticmethod
    def get_ora_path(file_name: str|None=None) -> str:
        AppBase._check_base_path()
        sql_path = utils.path_join(AppBase.BASE_PATH, AppBase.SQL_FOLDER, 
                                   AppBase.ORA_FOLDER)
        if file_name:
            return utils.path_join(sql_path, file_name)
        return sql_path

    @staticmethod
    def get_schema_path(direction: str) -> str:
        """
        Get the schema path for the given direction ('src' or 'trg').

        Args:
            direction (str): Either 'src' or 'trg'.

        Returns:
            str: The schema path.

        Raises:
            ValueError: If direction is invalid or BASE_PATH is not set.
        """        
        if direction not in ["src", "trg"]:
            raise ValueError("Direction must be 'src' or 'trg'.")
        AppBase._check_base_path()
        
        folder = AppBase.SRC_FOLDER if direction == "src" else AppBase.TRG_FOLDER
        return utils.path_join(AppBase.BASE_PATH, AppBase.SCHEMA_DIR, 
                               folder)

    @staticmethod
    def set_base_path(file_path: str):
        """
        Set the base path for the application.

        Args:
            file_path (str): The file path to use as the base.
        """        
        if file_path:
            AppBase.BASE_PATH = utils.base_path(file_path)

    @staticmethod
    def get_hashes_path(direction: str, file_name: str|None=None) -> str:
        """
        Get the path for storing or retrieving hash files.

        Args:
            direction (str): Either 'src' or 'trg'.
            file_name (str, optional): The hash file name.

        Returns:
            str: The full path to the hashes directory or file.

        Raises:
            ValueError: If direction is invalid or BASE_PATH is not set.
        """        
        if direction not in ["src", "trg"]:
            raise ValueError("Direction must be 'src' or 'trg'.")
        AppBase._check_base_path()
        folder = AppBase.SRC_FOLDER if direction == "src" else AppBase.TRG_FOLDER
        base_path = utils.path_join(AppBase.BASE_PATH, AppBase.SCHEMA_DIR, folder, 'hashes')
        return utils.path_join(base_path, file_name) if file_name else base_path
    
    @staticmethod
    def get_report_path(filename: str) -> str:
        """
        Get the full path for a report file.
        
        Args:
            filename: Name of the report file.
            
        Returns:
            str: Full path to the report file.
        """
        AppBase._check_base_path()
        return utils.path_join(AppBase.BASE_PATH, filename)