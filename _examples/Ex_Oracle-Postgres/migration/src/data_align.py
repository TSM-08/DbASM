from typing import Any, List, Optional, Tuple
from source_code.data_align import BaseAdjuster, DataAdjustmentError, adjustment


@adjustment("03")
class DefaultValueAdjuster(BaseAdjuster):
    """Handles adjustments for DATA_DEFAULT columns (query 03)."""

    def adjust(self, raw_data: List[Tuple], columns: List[str], direction: str) -> Optional[List[Tuple]]:
        """
        Adjust DATA_DEFAULT values for character types.

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
            pos_type, pos_def, pos_table, pos_col = self._column_positions(columns)
            adjusted_data: List[Tuple] = []

            print("Adjusting DATA_DEFAULT values ...")
            for row in raw_data:
                row_list = list(row)
                original_val = row_list[pos_def]
                type_val = row_list[pos_type]
                table_name = row_list[pos_table]
                column_name = row_list[pos_col]

                adjusted_val = self._adjust_default_value(original_val, type_val)
                if adjusted_val != original_val:
                    print(
                        f"Table: {table_name}, Column: {column_name} ({type_val}): {original_val!r} -> {adjusted_val!r}"
                    )

                row_list[pos_def] = adjusted_val
                adjusted_data.append(tuple(row_list))

            return adjusted_data
        except Exception as e:
            raise DataAdjustmentError(f"Default value adjustment failed: {e}") from e

    def _column_positions(self, columns: List[str]) -> Tuple[int, int, int, int]:
        return (
            self._get_column_position(columns, 'DATA_TYPE'),
            self._get_column_position(columns, 'DATA_DEFAULT'),
            self._get_column_position(columns, 'TABLE_NAME'),
            self._get_column_position(columns, 'COLUMN_NAME'),
        )

    def _adjust_default_value(self, val: Any, type_val: str) -> Optional[str]:
        """
        Normalize a default value based on the column data type.

        Returns:
            Adjusted default value, or None when the original value was None.
        """
        if val is None:
            return None

        normalized_value = self._normalize_value(val)
        if 'CHAR' in type_val and normalized_value.isdigit():
            normalized_value = f"'{normalized_value}'"

        return normalized_value.rstrip()