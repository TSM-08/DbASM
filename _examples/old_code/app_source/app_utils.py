"""
Application utilities module for database migration assessment.

This module provides common utility functions for file operations, 
configuration management, CSV handling, and SQL processing.
"""

import csv
import functools
import re
from datetime import datetime
from pathlib import Path
import typing
import yaml
import tempfile
import os


# Constants
HASHTAG = '#HASH#'
DYN_TAG = '#SQL#'
DEFAULT_ENCODING = 'utf-8'

Any = typing.Any
Optional = typing.Optional
Tuple = typing.Tuple
Dict = typing.Dict
List = typing.List


class UtilsError(Exception):
    """Custom exception for utility function errors."""
    pass


class FileOperations:
    """File operation utilities with error handling and debug support."""
    
    @staticmethod
    @functools.lru_cache(maxsize=128)
    def read_file(file_path: str) -> str:
        """
        Read file content with caching and error handling.
        
        Args:
            file_path: Path to the file to read.
            
        Returns:
            File content as string.
            
        Raises:
            UtilsError: If file cannot be read.
        """
        try:
            file_path_obj = Path(file_path)
            if not file_path_obj.exists():
                raise FileNotFoundError(f"File not found: {file_path}")
            
            with open(file_path, 'r', encoding=DEFAULT_ENCODING) as f:
                content = f.read()
            return content
            
        except Exception as e:
            raise UtilsError(f"Failed to read file {file_path}: {e}") from e
    
    @staticmethod
    def file_exists(file_path: str) -> bool:
        """
        Check if file exists.
        
        Args:
            file_path: Path to check.
            
        Returns:
            True if file exists, False otherwise.
        """
        exists = Path(file_path).exists()
        return exists
    
    @staticmethod
    def remove_file(file_path: str) -> None:
        """
        Remove file if it exists.
        
        Args:
            file_path: Path to file to remove.
        """
        
        try:
            file_path_obj = Path(file_path)
            if file_path_obj.exists():
                file_path_obj.unlink()

        except Exception as e:
            raise UtilsError(f"Failed to remove file {file_path}: {e}") from e
    
    @staticmethod
    def ensure_directory(dir_path: str) -> None:
        """
        Ensure directory exists, create if necessary.
        
        Args:
            dir_path: Directory path to ensure exists.
        """
        try:
            Path(dir_path).mkdir(parents=True, exist_ok=True)
        except Exception as e:
            raise UtilsError(f"Failed to create directory {dir_path}: {e}") from e


class ConfigManager:
    """Configuration file management utilities."""
    
    @staticmethod
    @functools.lru_cache(maxsize=32)
    def open_config(file_path: str) -> Dict[str, Any]:
        """
        Open and parse YAML configuration file with caching.
        
        Args:
            file_path: Path to YAML configuration file.
            
        Returns:
            Configuration dictionary.
            
        Raises:
            UtilsError: If configuration cannot be loaded.
        """
        try:
            if not FileOperations.file_exists(file_path):
                raise FileNotFoundError(f"Configuration file not found: {file_path}")
            
            with open(file_path, 'r', encoding=DEFAULT_ENCODING) as f:
                config = yaml.safe_load(f)
            
            if config is None:
                config = {}
            
            return config
            
        except yaml.YAMLError as e:
            raise UtilsError(f"Invalid YAML in {file_path}: {e}") from e
        except Exception as e:
            raise UtilsError(f"Failed to load configuration {file_path}: {e}") from e


class PathUtils:
    """Path manipulation utilities."""
    
    @staticmethod
    def base_path(file_path: str) -> str:
        """
        Get the base directory path from a file path.
        
        Args:
            file_path: Input file path.
            
        Returns:
            Base directory path.
        """
        base = str(Path(file_path).resolve().parent)
        
        return base
    
    @staticmethod
    def path_join(path: str, *paths: str) -> str:
        """
        Join path components safely across platforms.
        
        Args:
            path: Base path.
            *paths: Additional path components.
            
        Returns:
            Joined path.
        """
        result = str(Path(path).joinpath(*paths))
        return result
    
    @staticmethod
    def read_files_from_path(dir_path: str) -> List[str]:
        """
        Read all files from a dedicated path and return list with these files.
        
        Args:
            dir_path: Directory path to read files from.
        
        Returns:
            List of full paths to all files in the directory.
        
        Raises:
            UtilsError: If directory does not exist or cannot be read.
        """
        try:
            dir_obj = Path(dir_path)
            
            if not dir_obj.exists():
                raise FileNotFoundError(f"Directory not found: {dir_path}")
            
            if not dir_obj.is_dir():
                raise ValueError(f"Path is not a directory: {dir_path}")
            
            files = [str(file) for file in dir_obj.iterdir() if file.is_file()]
            return sorted(files)
            
        except (FileNotFoundError, ValueError) as e:
            raise UtilsError(str(e)) from e
        except Exception as e:
            raise UtilsError(f"Failed to read files from {dir_path}: {e}") from e
    
    @staticmethod
    def get_filename_without_extension(file_path: str) -> str:
        """
        Get filename without path and extension from a full path.
        
        Args:
            file_path: Full file path.
        
        Returns:
            Filename only, without path and extension.
        
        Raises:
            UtilsError: If file path is invalid.
            
        Example:
            get_filename_without_extension('/path/to/AUDIT_LOGS.csv') -> 'AUDIT_LOGS'
        """
        try:
            file_obj = Path(file_path)
            return file_obj.stem
            
        except Exception as e:
            raise UtilsError(f"Failed to extract filename from {file_path}: {e}") from e


class CSVManager:
    """CSV file operations with enhanced error handling."""
    
    @staticmethod
    def save_as_csv(file_path: str, data: List[List], title: Optional[List[str]] = None, add_mode: bool = False) -> None:
        """
        Save data to CSV file with proper error handling.
        
        Args:
            file_path: Output file path.
            data: Data rows to save.
            title: Optional column headers.
            add_mode: If True, append to existing file; otherwise overwrite.
            
        Raises:
            UtilsError: If CSV cannot be saved.
        """
        try:
            # Ensure output directory exists
            FileOperations.ensure_directory(str(Path(file_path).parent))

            mode = 'a' if add_mode else 'w'

            with open(file_path, mode, newline='', encoding=DEFAULT_ENCODING) as f:
                writer = csv.writer(f)
 
                # Only write headers if not appending OR if file is empty when appending
                if title and (not add_mode or not FileOperations.file_exists(file_path) or Path(file_path).stat().st_size == 0):
                    writer.writerow(title)

                # Process data rows to handle None values
                for row in data:
                    processed_row = ['None' if val is None else val for val in row]
                    writer.writerow(processed_row)
           
        except Exception as e:
            raise UtilsError(f"Failed to save CSV {file_path}: {e}") from e
    
    @staticmethod
    def read_csv_file(file_path: str) -> Tuple[List[List[str]], List[str]]:
        """
        Read CSV file and return data with headers.
        
        Args:
            file_path: Path to CSV file.
            
        Returns:
            Tuple of (data_rows, column_headers).
            
        Raises:
            UtilsError: If CSV cannot be read.
        """
        
        try:
            if not FileOperations.file_exists(file_path):
                raise FileNotFoundError(f"CSV file not found: {file_path}")
            
            data = []
            with open(file_path, newline='', encoding=DEFAULT_ENCODING) as csvfile:
                reader = csv.reader(csvfile)
                columns = next(reader, [])  # Header row with default empty list
                for row in reader:
                    # Convert 'None' string back to Python None
                    processed_row = [None if val == 'None' else val for val in row]
                    data.append(processed_row)
            
            return data, columns
            
        except Exception as e:
            raise UtilsError(f"Failed to read CSV {file_path}: {e}") from e

    @staticmethod
    def read_csv_chunk(file_path: str, start_row: int = 0, 
                  chunk_size: int = 10000) -> Tuple[List[List[str]], List[str], bool]:
        """
        Read a specific chunk of CSV file by row position (memory efficient).
        
        Args:
            file_path: Path to CSV file.
            start_row: Starting row number (0-based, excluding header).
            chunk_size: Number of rows to read.
            
        Returns:
            Tuple of (chunk_data, columns, has_more_data).
            
        Raises:
            UtilsError: If CSV chunk cannot be read.
        """
        try:
            if not FileOperations.file_exists(file_path):
                raise FileNotFoundError(f"CSV file not found: {file_path}")
            
            if start_row < 0 or chunk_size <= 0:
                raise ValueError("start_row must be >= 0 and chunk_size must be > 0")
            
            with open(file_path, 'r', newline='', encoding=DEFAULT_ENCODING) as csvfile:
                reader = csv.reader(csvfile)
                
                # Read header
                try:
                    columns = next(reader)
                except StopIteration:
                    # File is completely empty
                    return [], [], False
                
                if not columns:
                    # Header exists but is empty
                    return [], [], False
                
                # Check if we have any data rows by trying to peek at the first data row
                try:
                    first_data_row = next(reader)
                    # We found at least one data row, so we need to handle it
                    has_data_rows = True
                except StopIteration:
                    # No data rows, only header
                    return [], columns, False
                
                # If start_row is 0, we already have the first row
                current_row = 0
                chunk_data = []
                
                if start_row == 0:
                    # Include the first row we already read
                    processed_row = [None if cell == '' else cell for cell in first_data_row]
                    chunk_data.append(processed_row)
                    current_row = 1
                else:
                    # Skip to start_row (we've already read row 0)
                    current_row = 1
                    while current_row < start_row:
                        try:
                            next(reader)
                            current_row += 1
                        except StopIteration:
                            # Reached end of file before start_row
                            return [], columns, False
                
                # Read chunk_size rows (or until we've read chunk_size total)
                rows_in_chunk = len(chunk_data)
                
                for row in reader:
                    if rows_in_chunk >= chunk_size:
                        # We have more data available
                        return chunk_data, columns, True
                    
                    # Convert empty strings to None for proper NULL handling
                    processed_row = [None if cell == '' else cell for cell in row]
                    chunk_data.append(processed_row)
                    rows_in_chunk += 1
                
                # Reached end of file
                return chunk_data, columns, False
                
        except Exception as e:
            raise UtilsError(f"Failed to read CSV chunk {file_path}: {e}") from e
    
    @staticmethod
    def get_csv_info(file_path: str) -> Dict[str, Any]:
        """
        Get CSV file information without loading all data.
        
        Args:
            file_path: Path to CSV file.
            
        Returns:
            Dictionary with CSV file information.
            
        Raises:
            UtilsError: If CSV info cannot be retrieved.
        """
        try:
            if not FileOperations.file_exists(file_path):
                raise FileNotFoundError(f"CSV file not found: {file_path}")
            
            with open(file_path, 'r', newline='', encoding=DEFAULT_ENCODING) as csvfile:
                reader = csv.reader(csvfile)
                
                # Read header
                columns = next(reader, [])
                column_count = len(columns)
                
                # Count data rows
                row_count = sum(1 for _ in reader)
                
                # Get file size
                file_size = Path(file_path).stat().st_size
                
                return {
                    'file_path': file_path,
                    'file_size_bytes': file_size,
                    'file_size_mb': round(file_size / (1024 * 1024), 2),
                    'column_count': column_count,
                    'columns': columns,
                    'row_count': row_count,
                    'estimated_rows_per_mb': int(row_count / (file_size / (1024 * 1024))) if file_size > 0 else 0
                }
                
        except Exception as e:
            raise UtilsError(f"Failed to get CSV info {file_path}: {e}") from e


class SQLProcessor:
    """SQL file and query processing utilities."""
    
    @staticmethod
    def open_sql_file(file_path: str) -> str:
        """
        Open SQL file and return its contents with validation.
        
        Args:
            file_path: Path to SQL file.
            
        Returns:
            SQL file contents.
            
        Raises:
            UtilsError: If SQL file cannot be read.
        """

        try:
            if not FileOperations.file_exists(file_path):
                raise FileNotFoundError(f"SQL file not found: {file_path}")
            
            content = FileOperations.read_file(file_path)
            return content
            
        except Exception as e:
            raise UtilsError(f"Failed to open SQL file {file_path}: {e}") from e
    
    @staticmethod
    def extract_code_block(file_path: str, block_num: str) -> Optional[str]:
        """
        Extract SQL code block from file using block markers.
        
        Args:
            file_path: Path to file containing code blocks.
            block_num: Block number identifier.
            
        Returns:
            Extracted code block or None if not found.
            
        Raises:
            UtilsError: If file cannot be processed.
        """
        
        try:
            content = FileOperations.read_file(file_path)
            
            # Use regex to find everything between --> and --<
            pattern = f'--%{block_num}S' + r'(.*?)' + f'--%{block_num}F'
            matches = re.findall(pattern, content, re.DOTALL)
            
            result = matches[0].strip() if matches else None
            
            return result
            
        except Exception as e:
            raise UtilsError(f"Failed to extract code block: {e}") from e
    
    @staticmethod
    def has_dyn_query(sql: str) -> bool:
        """
        Check if SQL contains dynamic query marker.
        
        Args:
            sql: SQL string to check.
            
        Returns:
            True if SQL has dynamic query marker.
        """

        if not sql:
            return False
        
        first_line = sql.splitlines()[0]
        result = first_line.startswith(f'--{DYN_TAG}')
        return result
    
    @staticmethod
    def is_hash_query(sql: str) -> bool:
        """
        Check if SQL is a hash query.
        
        Args:
            sql: SQL string to check.
            
        Returns:
            True if SQL is a hash query.
        """
        if not sql:
            return False
        
        first_line = sql.splitlines()[0]
        result = first_line.startswith(f'--{HASHTAG}')
        return result

    @staticmethod
    def create_temp_file(file_path: str, replace: Dict[str, str]) -> str:
        """
        Create a temp file in the system temp directory based on file_path, 
        replacing placeholders with values.
        Returns the path to the temp file.
        """

        temp_dir = tempfile.gettempdir()
        p = Path(file_path)
        temp_path = os.path.join(temp_dir, p.name)
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        for placeholder, value in replace.items():
            content = content.replace(placeholder, value)
        with open(temp_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return temp_path


class DataProcessor:
    """Data processing and manipulation utilities."""
    
    @staticmethod
    @functools.lru_cache(maxsize=128)
    def _get_sorted_map(columns: List[str], 
                        exclude_cols: List[str] = []) -> Tuple[List[str], List[int]]:
        """
        Get index mapping for sorted columns excluding specified columns.
        
        Args:
            columns: Original column names.
            exclude_cols: Column names to exclude from sorting.
        Returns:
            Sorted list of columns and a list of indices mapping sorted columns to original columns.
        """
        # Filter out excluded columns
        included_columns = [col for col in columns if col not in exclude_cols]
        sorted_columns = sorted(included_columns)

        # Map sorted column names to their original indices
        index_map = [columns.index(col) for col in sorted_columns]
        return (sorted_columns, index_map)

    @staticmethod
    def sort_row_by_columns(columns: List[str], row: List, 
                            exclude_cols: Optional[List[str]] = None) -> Tuple[List[str], List]:
        """
        Sort row values based on alphabetically sorted column names.
        
        Args:
            columns: Original column names.
            row: Single row of values aligned with columns.
            exclude_cols: Column names to exclude from sorting.
            
        Returns:
            Tuple of (sorted_columns, sorted_row).
            
        Raises:
            UtilsError: If data processing fails.
        """
        
        try:
            exclude_cols = exclude_cols or []

            # Validate input
            if len(columns) != len(row):
                raise ValueError(f"Column count ({len(columns)}) doesn't match row length ({len(row)})")
                
            # Map sorted column names to their original indices
            sorted_columns, index_map = DataProcessor._get_sorted_map(tuple(columns), tuple(exclude_cols))
            sorted_row = [row[i] for i in index_map]
            
            return sorted_columns, sorted_row
            
        except Exception as e:
            raise UtilsError(f"Failed to sort row: {e}") from e
    
    @staticmethod
    def get_position(columns: List[str], search_for: str) -> int:
        """
        Get position of column in list.
        
        Args:
            columns: List of column names.
            search_for: Column name to find.
            
        Returns:
            Index of column or -1 if not found.
        """
        try:
            position = columns.index(search_for)
            return position
        except ValueError:
            return -1


class ExecutionTimer:
    def __init__(self):
        self._start_time = None
        self._end_time = None

    def start(self) -> datetime:
        self._start_time = datetime.now()
        self._end_time = None
        return self._start_time

    def stop(self) -> datetime:
        self._end_time = datetime.now()
        return self._end_time

    @property
    def start_time(self) -> datetime | None:
        return self._start_time

    @property
    def end_time(self) -> datetime | None:
        return self._end_time

    def elapsed(self) -> tuple[float | None, str]:
        elapsed, unit = None, 'sec'
        if self.start_time and self.end_time:
            elapsed = (self.end_time - self.start_time).total_seconds()

        if elapsed and elapsed >= 60:
            elapsed, unit = elapsed / 60, 'min'     

        return elapsed, unit
    
    def elapsed_formatted(self) -> str:
        elapsed, unit = self.elapsed()
        if elapsed:
            return f"{elapsed:.2f} {unit}"
        return "N/A"

    def summary(self) -> dict:
        start_str = self.start_time.strftime('%Y-%m-%d %H:%M:%S') \
            if self.start_time else 'N/A'
        finish_str = self.end_time.strftime('%Y-%m-%d %H:%M:%S') \
            if self.end_time else 'N/A'

        elapsed, unit = self.elapsed()
        if elapsed:
            elapsed_str = f"{elapsed:.2f} {unit}"
        else:
            elapsed_str = 'N/A'

        return dict(
            start_time_fmt=start_str,
            end_time_fmt=finish_str,
            execution_time_fmt=elapsed_str,
            start_time=self.start_time,
            end_time=self.end_time,
            execution_time=(elapsed, unit)
        )

execution_timer = ExecutionTimer()

# Backward compatibility - expose functions at module level
file_exists = FileOperations.file_exists
read_file = FileOperations.read_file
remove_file = FileOperations.remove_file

open_config = ConfigManager.open_config

base_path = PathUtils.base_path
path_join = PathUtils.path_join
get_all_files = PathUtils.read_files_from_path
cut_filename = PathUtils.get_filename_without_extension

open_sql_file = SQLProcessor.open_sql_file
extract_code_block = SQLProcessor.extract_code_block
has_dyn_query = SQLProcessor.has_dyn_query
is_hash_query = SQLProcessor.is_hash_query
create_temp_file = SQLProcessor.create_temp_file

sort_row_by_columns = DataProcessor.sort_row_by_columns
get_position = DataProcessor.get_position

save_as_csv = CSVManager.save_as_csv
read_csv_file = CSVManager.read_csv_file
read_csv_file_chunk = CSVManager.read_csv_chunk
get_csv_info = CSVManager.get_csv_info

timer_start = execution_timer.start
timer_stop = execution_timer.stop
elapsed_time_formatted = execution_timer.elapsed_formatted
elapsed_time = execution_timer.elapsed