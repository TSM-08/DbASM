from abc import ABC, abstractmethod
from .app_utils import Dict, Optional, Tuple, List, Any

from . import app_utils as utils
import importlib


def adjustment(query_id: str):
    """
    Decorator to specify the query ID for an adjuster class.
    
    Args:
        query_id: The query identifier this adjuster handles.
        
    Returns:
        Decorator function that sets the query_id on the class.
    """
    def decorator(cls):
        cls.query_id = query_id
        return cls
    return decorator


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
    def _get_column_position(columns: List[str], column_name: str) -> int:
        """Get column position with error handling."""
        position = utils.get_position(columns, column_name)
        if position == -1:
            raise DataAdjustmentError(f"Column '{column_name}' not found in columns: {columns}")
        return position

    @staticmethod
    def _normalize_value(val: Any) -> str:
        return str(val).replace("\n", "").strip()


class DataAdjustment:
    """
    Enhanced data adjustment system with pluggable adjusters.
    
    This class provides a flexible framework for adjusting raw database query results
    based on query ID, data type, and database direction. Adjusters are automatically
    discovered from migration.src.data_align and migration.trg.data_align modules.
    """
    
    # Registry of adjusters by direction and query ID
    _adjusters: Dict[str, BaseAdjuster] = {}
    _initialized: bool = False
    
    @classmethod
    def _discover_adjusters(cls) -> None:
        """
        Automatically discover and register adjusters from src and trg modules.
        This method is called automatically on first use.
        """
        if cls._initialized:
            return
        
        directions = ['src', 'trg']
        
        for direction in directions:
            try:
                # Import the module dynamically
                module_name = f'migration.{direction}.data_align'
                module = importlib.import_module(module_name)

                for adjuster_cls in cls._iter_adjuster_classes(module):
                    adjuster_instance = adjuster_cls()
                    if hasattr(adjuster_cls, 'query_id'):
                        query_id = getattr(adjuster_cls, 'query_id', None)
                        if query_id is not None:
                            query_key = f"{direction}:{query_id}"
                            cls._adjusters[query_key] = adjuster_instance
            except ImportError:
                # Module doesn't exist, skip
                continue
            except Exception as e:
                raise DataAdjustmentError(f"Failed to load adjusters for {direction}: {e}") from e
        
        cls._initialized = True

    @classmethod
    def _iter_adjuster_classes(cls, module: Any):
        """Yield adjuster classes defined in the given module."""
        for attr_name in dir(module):
            attr = getattr(module, attr_name)
            if isinstance(attr, type) and issubclass(attr, BaseAdjuster) and attr is not BaseAdjuster:
                yield attr

    @classmethod
    def register_adjuster(cls, key: str, adjuster: BaseAdjuster) -> None:
        """
        Register a custom adjuster with a specific key.
        
        Args:
            key: Unique identifier for the adjuster (e.g., 'src:03', 'trg:DefaultValueAdjuster').
            adjuster: Adjuster instance implementing BaseAdjuster.
        """
        cls._discover_adjusters()
        cls._adjusters[key] = adjuster
    
    @classmethod
    def get_registered_adjusters(cls) -> Dict[str, str]:
        """Get list of registered adjusters."""
        cls._discover_adjusters()
        return {key: adj.__class__.__name__ for key, adj in cls._adjusters.items()}
    
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
        
        cls._discover_adjusters()
        
        # Try different key patterns to find the adjuster
        possible_keys = [
            f"{direction}:{qry_id}",  # e.g., "src:03"
        ]
        
        adjuster = None
        for key in possible_keys:
            if key in cls._adjusters:
                adjuster = cls._adjusters[key]
                break
        
        if not adjuster:
            return None
        
        try:
            adjusted_data = adjuster.adjust(raw_data, columns, direction)
            
            if not adjusted_data:
                return None
            
            if not cls.validate_adjustment_result(raw_data, adjusted_data, qry_id):
                raise DataAdjustmentError(f"Validation failed for adjusted data of query {qry_id}")
            
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
        cls._discover_adjusters()
        
        if adjusted_data is None:
            return True
        
        if len(original_data) != len(adjusted_data):
            return False
        
        # Check that each row has the same number of columns
        for i, (orig_row, adj_row) in enumerate(zip(original_data, adjusted_data)):
            if len(orig_row) != len(adj_row):
                return False
        return True