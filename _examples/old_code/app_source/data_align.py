from abc import ABC, abstractmethod
from .app_utils import Dict, Optional, Tuple, List, Any

from . import app_utils as utils


class DataAdjustmentError(Exception):
    """Custom exception for data adjustment errors."""
    pass


class BaseAdjuster(ABC):
    """Abstract base class for data adjusters."""
    
    @abstractmethod
    def adjust(self, raw_data: List[Tuple], columns: List[str], direction: str) -> Optional[List[Tuple]]:
        """Adjust data for a specific query."""
        pass
    
    @staticmethod
    def get_column_position(columns: List[str], column_name: str) -> int:
        """Get column position with error handling."""
        position = utils.get_position(columns, column_name)
        if position == -1:
            raise DataAdjustmentError(f"Column '{column_name}' not found in columns: {columns}")
        return position


class DefaultValueAdjuster(BaseAdjuster):
    """Handles adjustments for DATA_DEFAULT columns (query 02)."""
    
    def adjust(self, raw_data: List[Tuple], columns: List[str], direction: str) -> Optional[List[Tuple]]:
        """
        Adjust DATA_DEFAULT values for character types and PostgreSQL-specific formatting.
        
        Args:
            raw_data: Raw data rows from database query.
            columns: Column names corresponding to the data.
            direction: Database direction ('src' or 'trg').
            
        Returns:
            Adjusted data or None if no adjustments needed.
        """
        if not raw_data:
            return None
        
        try:
            pos_type = self.get_column_position(columns, 'DATA_TYPE')
            pos_def = self.get_column_position(columns, 'DATA_DEFAULT')
            pos_table = self.get_column_position(columns, 'TABLE_NAME')
            pos_col = self.get_column_position(columns, 'COLUMN_NAME')
            
            adjusted_data = []
            adjustments_made = 0

            print(f"Adjusting DATA_DEFAULT values ...")
            for row in raw_data:
                row_list = list(row)
                original_val = row_list[pos_def]
                type_val = row_list[pos_type]
                table_name = row_list[pos_table]
                column_name = row_list[pos_col]
                
                adjusted_val = self._adjust_default_value(original_val, type_val, direction, 
                                                          table_name, column_name)

                if adjusted_val != original_val:
                    adjustments_made += 1
                
                row_list[pos_def] = adjusted_val
                adjusted_data.append(tuple(row_list))
           
            return adjusted_data
            
        except Exception as e:
            raise DataAdjustmentError(f"Default value adjustment failed: {e}") from e

    def _adjust_default_value(self, val: Any, type_val: str, direction: str, table_name: str, column_name: str) -> str:
        """
        Adjust a single default value based on data type and direction.
        
        Args:
            val: Original default value.
            type_val: Data type of the column.
            direction: Database direction ('src' or 'trg').
            row_index: Row index for debugging.
            
        Returns:
            Adjusted default value.
        """
        if val is None:
            return val
        
        original_val = val
        
        # Convert to string for processing
        if not isinstance(val, str):
            val = str(val)

          # 1. Remove newlines
        if '\n' in val:
            val = val.replace("\n", "").strip()
            print(f"Table: {table_name}, column: {column_name}: {original_val!r} -> {val!r}")

        # 2. Handle character types with numeric defaults
        if 'CHAR' in type_val and val and val.strip().isdigit():
            val = f"'{val.strip()}'"
            print(f"Table: {table_name}, column: {column_name}: {original_val!r} -> {val!r}")

        # 3. Handle PostgreSQL-specific casting (::type)
        if direction == 'trg' and "::" in val:
            val = self._remove_postgres_cast(val)
            print(f"Table: {table_name}, column: {column_name}: {original_val!r} -> {val!r}")
        
        # 4. Remove trailing spaces
        val = val.rstrip()
       
        return val
    
    def _remove_postgres_cast(self, val: str) -> str:
        """
        Remove PostgreSQL type casting (::type) from default values.
        
        Args:
            val: Default value string potentially containing ::type cast.
            
        Returns:
            Default value with cast removed.
        """
        if val.endswith(")"):
            # Handle function calls like nextval('seq'::regclass)
            cast_pos = val.rfind("::")
            if cast_pos > 0:
                return val[:cast_pos].strip() + ")"
        else:
            # Handle simple values like 'value'::text
            return val.split("::")[0].strip()
        
        return val


class DataAdjustment:
    """
    Enhanced data adjustment system with pluggable adjusters.
    
    This class provides a flexible framework for adjusting raw database query results
    based on query ID, data type, and database direction.
    """
    
    # Registry of adjusters by query ID
    _adjusters: Dict[str, BaseAdjuster] = {
        '03': DefaultValueAdjuster(),
    }
    
    @classmethod
    def register_adjuster(cls, query_id: str, adjuster: BaseAdjuster) -> None:
        """
        Register a custom adjuster for a specific query ID.
        
        Args:
            query_id: Query identifier.
            adjuster: Adjuster instance implementing BaseAdjuster.
        """
        cls._adjusters[query_id] = adjuster
    
    @classmethod
    def get_registered_adjusters(cls) -> Dict[str, str]:
        """Get list of registered adjusters."""
        return {qid: adj.__class__.__name__ for qid, adj in cls._adjusters.items()}
    
    @classmethod
    def adjust(cls, qry_id: str, raw_data: List[Tuple], columns: List[str], 
              direction: str = 'src') -> Optional[List[Tuple]]:
        """
        Adjust raw data based on query ID and direction.
        
        Args:
            qry_id: Query identifier (e.g., '02', '05').
            raw_data: Raw data rows from database query.
            columns: Column names corresponding to the data.
            direction: Database direction ('src' or 'trg').
            
        Returns:
            Adjusted data or None if no adjustments needed.
            
        Raises:
            DataAdjustmentError: If adjustment fails.
        """
        if not raw_data:
            return None
        
        # Check if adjuster exists for this query
        if qry_id not in cls._adjusters:
            return None
        
        try:
            adjuster = cls._adjusters[qry_id]
            adjusted_data = adjuster.adjust(raw_data, columns, direction)
            
            if not adjusted_data:
                return None
            
            return adjusted_data
                
        except Exception as e:
            raise DataAdjustmentError(f"Adjustment failed for query {qry_id}: {e}") from e
    
    @classmethod
    def validate_adjustment_result(cls, original_data: List[Tuple], 
                                 adjusted_data: Optional[List[Tuple]], 
                                 qry_id: str) -> bool:
        """
        Validate that adjustment didn't break data integrity.
        
        Args:
            original_data: Original data before adjustment.
            adjusted_data: Data after adjustment.
            qry_id: Query identifier for logging.
            
        Returns:
            True if validation passes.
        """
        if adjusted_data is None:
            return True
        
        if len(original_data) != len(adjusted_data):
            return False
        
        # Check that each row has the same number of columns
        for i, (orig_row, adj_row) in enumerate(zip(original_data, adjusted_data)):
            if len(orig_row) != len(adj_row):
                return False
        return True