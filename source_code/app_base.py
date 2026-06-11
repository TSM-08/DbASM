from . import app_utils as utils
from migration.src.connector import SrcConnector
from migration.trg.connector import TrgConnector
from pathlib import Path
import shutil


# Constants for directory and file management
BASE_PATH = ""  # To be set at runtime
MGR_FOLDER = "migration"
SCHEMA_DIR = "assessment/metadata"
REP_FOLDER = "assessment/reports"
SRC_FOLDER = "src"
TRG_FOLDER = "trg"

_debug = False

SECTION_LENGTH = 90  # Length of section separators in logs or outputs

# Mapping of database type to connector class and optional convertor key
DB_CONNECT_MAP = {
    'src': (SrcConnector, None),
    'trg': (TrgConnector, "transformation")
}

# Mapping of SQL script folders for source, target, and assessment phases
SQL_FOLDER_MAP = {
    'src': f'{MGR_FOLDER}/src',
    'trg': f'{MGR_FOLDER}/trg',
    'assessment': f'{MGR_FOLDER}/final_sql'
}

# Default field names used for hash table storage and retrieval
TABLE_HASH_MAP = {
    'schema_name': 'schema_name',
    'table_name': 'table_name',
    'key_fields': 'key_fields',
    'key_values': 'key_values',
    'hash_value': 'hash_value',
}


def init_hash_table_structure(config):
    """
    Returns a TABLE_HASH_MAP dict with all required keys, filled from config if present, otherwise defaults.
    """
    table_struct = utils.get_config_item(config, 'hashing', 'table_structure', default={})
    for key in TABLE_HASH_MAP:
        if key in table_struct:
            TABLE_HASH_MAP[key] = table_struct[key]
    return TABLE_HASH_MAP


def set_debug(debug: bool):
    """Set debug mode."""
    global _debug
    _debug = debug


def is_debug() -> bool:
    """Check if debug mode is enabled."""
    return _debug


def _check_base_path():
    """Ensure BASE_PATH is set."""
    if not BASE_PATH:
        raise ValueError("BASE_PATH is not specified.")


def open_base_config() -> dict:
    """
    Open the base configuration file.

    Returns:
        dict: The contents of the configuration file.
    """
    _check_base_path()
    file_path: str = utils.path_join(BASE_PATH, 'config.yaml')
    return utils.open_config(file_path)


def open_connection_config() -> dict:
    """
    Open the connection configuration file.

    Returns:
        dict: The contents of the connections configuration.
    """
    _check_base_path()
    file_path: str = utils.path_join(BASE_PATH, 'connection.yaml')
    return utils.open_config(file_path)


def get_sql_path(file_name: str | None = None) -> str:
    """Get the SQL scripts path."""
    _check_base_path()
    sql_path = SQL_FOLDER_MAP.get('assessment') or ''
    if file_name:
        return utils.path_join(BASE_PATH, sql_path, file_name)
    return utils.path_join(BASE_PATH, sql_path)


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
    _check_base_path()

    folder = SRC_FOLDER if direction == "src" else TRG_FOLDER
    return utils.path_join(BASE_PATH, SCHEMA_DIR, folder)


def remove_path(path: str) -> None:
    """
    Remove a file or directory tree at the specified path.

    Args:
        path: Path to a file or directory to remove.

    Raises:
        ValueError: If the path is invalid or unsafe.
    """
    if not path:
        raise ValueError("Path cannot be empty.")

    path_obj = Path(path)
    if not path_obj.exists():
        return

    resolved = path_obj.resolve()
    if resolved == resolved.anchor:
        raise ValueError("Refusing to remove root path.")

    if path_obj.is_dir():
        shutil.rmtree(path_obj)
    else:
        path_obj.unlink()


def remove_path_contents(path: str) -> None:
    """
    Remove all files and directories inside the specified directory,
    preserving the directory itself.

    Args:
        path: Path to a directory whose contents should be removed.

    Raises:
        ValueError: If the path is invalid, not a directory, or unsafe.
    """
    if not path:
        raise ValueError("Path cannot be empty.")

    path_obj = Path(path)
    if not path_obj.exists():
        return

    resolved = path_obj.resolve()
    if resolved == resolved.anchor:
        raise ValueError("Refusing to remove contents of root path.")

    if not path_obj.is_dir():
        raise ValueError("Path must be an existing directory.")

    for child in path_obj.iterdir():
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()


def set_base_path(file_path: str):
    """
    Set the base path for the application.

    Args:
        file_path (str): The file path to use as the base.
    """
    global BASE_PATH
    if file_path:
        BASE_PATH = utils.base_path(file_path)


def get_hashes_path(direction: str, file_name: str | None = None) -> str:
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
    _check_base_path()
    folder = SRC_FOLDER if direction == "src" else TRG_FOLDER
    base_path = utils.path_join(BASE_PATH, SCHEMA_DIR, folder, 'hashes')
    return utils.path_join(base_path, file_name) if file_name else base_path


def get_report_path(filename: str) -> str:
    """
    Get the full path for a report file.

    Args:
        filename: Name of the report file.

    Returns:
        str: Full path to the report file.
    """
    _check_base_path()
    return utils.path_join(BASE_PATH, REP_FOLDER, filename)