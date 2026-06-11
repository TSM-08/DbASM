from app_source.app_base import AppBase
from app_source.as_schema import SchemaProcessor
from app_source import app_utils as utils
from typing import Dict, List
from enum import Enum


# Constants
INSERTED = 'Inserted'
UPDATED = 'Updated'
DELETED = 'Deleted'


class ActionType(Enum):
    INSERT = 'INSERT',
    UPDATE = 'UPDATE',
    DELETE = 'DELETE'


class DataSync:
    def __init__(self, schemas: Dict[str, SchemaProcessor], 
                 changes: List, tabmaps: List, colmaps: List) -> None:
        self._schema_src = schemas['src']
        self._schema_trg = schemas['trg']
        self._change_lst = changes
        self._changes: Dict = DataSync._group_changes_by_table_action(changes)
        self._tabmaps: Dict = DataSync._group_mapping_by_table_name(tabmaps)
        self._colmaps: Dict = DataSync._group_mapping_by_table_column(colmaps)
        self._results: Dict = {}

    def _update_results(self, table_name: str, action: ActionType, count: int):
        if table_name not in self._results:
            self._results[table_name] = {
                INSERTED: 0, UPDATED: 0, DELETED: 0}
        if action == ActionType.INSERT:
            self._results[table_name][INSERTED] += count
        elif action == ActionType.UPDATE:
            self._results[table_name][UPDATED] += count
        elif action == ActionType.DELETE:
            self._results[table_name][DELETED] += count
    
    def _get_results(self, table_name: str) -> str:
        stats = self._results.get(table_name, {})
        nonzero = {k: v for k, v in stats.items() if v > 0}
        if nonzero:
            actions = ', '.join(f"{k} = {v}" for k, v in nonzero.items())
            return f"{table_name}: {actions}"
        return f"{table_name}: No change applied"

    def total_changes(self) -> int:
        return len(self._change_lst)
    
    def total_applied(self) -> int:
        total = 0
        for stats in self._results.values():
            total += stats.get(INSERTED, 0)
            total += stats.get(UPDATED, 0)
            total += stats.get(DELETED, 0)
        return total
    
    def report_updates(self) -> None:
        for k in self._results.keys():
            print(self._get_results(table_name=k))

    def apply_changes(self) -> None:
        """Apply detected changes from target to source database."""
        table_list: List[str] = []
        try:
            self.pre_update_event()
            table_list = self._apply_changes_in_source()
        except Exception as e:
            print(f"Error applying changes: {e}")
            raise
        finally:
            self.post_update_event(table_list)
    
    def pre_update_event(self) -> None:
        """Pre-update event hook for any necessary preparations."""
        scripts = [{'name': 'disable_fkeys.sql', 
                    'description': 'Disable foreign keys in source database'}]
        print("- Pre-update events...")
        for script in scripts:
            file_name = script['name']
            description = script['description'] 
            file_path = AppBase.get_ora_path(file_name)
            print(f"{description}.")
            self._schema_src.db.execute_sql(file_path)

    def post_update_event(self, table_list: List[str]) -> None:
        """Post-update event hook for any necessary cleanup or verification."""
        print("\n- Post-update events...")
        scripts = [{'name': 'adjust_seqs.sql', 'description': 'Adjust sequences in source database', 
                    'use_tables': True}, 
                   {'name': 'enable_fkeys.sql', 'description': 'Enable foreign keys in source database', 
                    'use_tables': False}]

        for script in scripts:
            file_name = script['name']
            description = script['description'] 
            file_path = AppBase.get_ora_path(file_name)
            print(f"{description}.")

            is_temp_file = False
            if script.get('use_tables'):
                table_names = ', '.join(f"'{table}'" for table in table_list or [])
                file_path = utils.create_temp_file(file_path, {'<TABLE_NAMES>': table_names})
                is_temp_file = True

            self._schema_src.db.execute_sql(file_path)
            if is_temp_file:
                utils.remove_file(file_path)

    @staticmethod
    def _group_changes_by_table_action(changes) -> Dict[str, List]:
        """Group changes by table_name|action composite key."""
        grouped = {}
        for item in changes:
            table_name = item.get('TABLE_NAME')
            action = item.get('ACTION')
            key = f"{table_name}|{action}"
            
            if key not in grouped:
                grouped[key] = []
            grouped[key].append(item)
        
        return grouped

    @staticmethod
    def _group_mapping_by_table_name(tabmaps) -> Dict[str, Dict]:
        """Group changes by table_name key."""
        grouped = {}
        for item in tabmaps:
            table_name = item.get('TABLE_NAME')
            key = table_name
            grouped[key] = item
        
        return grouped

    @staticmethod
    def _group_mapping_by_table_column(colmaps) -> Dict[str, Dict]:
        """Group changes by table_name|column_name composite key."""
        grouped = {}
        for item in colmaps:
            table_name = item.get('TABLE_NAME')
            column_name = item.get('COLUMN_NAME')
            key = f"{table_name}|{column_name}"
            grouped[key] = item
        
        return grouped    

    def _save_table_action(self, action: ActionType, table_name: str, cols: list, rows: list, 
                           pk_fields_list: list, pk_values_list: list):
        ora_rows = []
        for row in rows:
            converted = self._convert_postgres_to_oracle(table_name, cols, row)
            ora_rows.append(tuple(converted))
        
        cols = [self._get_orig_col_name(table_name, col) for col in cols]
        pk_fields_list = [self._get_orig_col_name(table_name, col) for col in pk_fields_list]
        table_name = self._get_orig_tab_name(table_name)
        action_rows = len(pk_values_list) 
        print(f"\nApplying {action.name} on table {table_name} for {action_rows} row(s)")

        count = 0
        if action == ActionType.INSERT:
            count = self._insert_rows(table_name, cols, ora_rows)
        elif action == ActionType.DELETE:
            count = self._delete_rows(table_name, pk_fields_list, pk_values_list)                
        elif action == ActionType.UPDATE:
            count = self._update_rows(table_name, cols, ora_rows, pk_fields_list)
        else:
            raise ValueError(f"Unknown action type: {action}")
        
        if count > 0:
            self._update_results(table_name, action, count)

        print(f"Action {action.name} completed successfully.")

    def _convert_pk_values(self, pk_values: List[str]) -> List:
        converted_values = []
        for val in pk_values:
            try:
                # Try converting to integer for numeric columns
                converted_values.append(int(val))
            except (ValueError, TypeError):
                # Keep as string if conversion fails
                converted_values.append(val)
        return converted_values

    def _apply_changes_in_source(self) -> List[str]:
        table_list: List[str] = []
        print("\n- Applying detected changes to source ...")
        self._schema_src.db.connect()
        self._schema_src.db.Table_Autocommit = False
        self._schema_trg.db.connect()
        try:
            for _, changes in self._changes.items():
                schema = changes[0].get('SCHEMA_NAME')
                table_name = changes[0].get('TABLE_NAME')
                action_name = changes[0].get('ACTION')
                pk_field = changes[0].get('PK_COL')

                action = ActionType[action_name]    
                # Collect all PK values for the IN clause
                pk_values_list = [self._convert_pk_values(item.get('PK_VALUE', '').split('|')) for item in changes]
                pk_fields_list = pk_field.split('|')

                if action in (ActionType.INSERT, 
                              ActionType.UPDATE):
                    cols, rows = self._schema_trg.db.table_select(
                                    table_name=f"{schema}.{table_name}", cols=[],
                                    pk_fields=pk_fields_list,
                                    pk_values=pk_values_list)
                else:
                    cols, rows = [], []

                self._save_table_action(action, table_name, cols, rows, 
                                        pk_fields_list, pk_values_list)
                
                if table_name not in table_list:
                    table_list.append(table_name)
            
            self._schema_src.db.commit()
        except Exception as e:
            self._schema_src.db.rollback()
            raise RuntimeError(f"Error applying changes in source: {e}") from e
        finally:
            self._schema_trg.db.close()
            self._schema_src.db.Table_Autocommit = True
            self._schema_src.db.close()
        return table_list

    def _get_orig_tab_name(self, table_name: str) -> str:
        orig_name = "" 
        key = table_name
        if key in self._tabmaps.keys():
            orig_name = self._tabmaps[key]["TAB_NAME_SRC"]
        if not orig_name:
            orig_name = table_name
        return orig_name

    def _get_orig_col_name(self, table_name: str, col_name: str) -> str:
        orig_name = "" 
        key = f"{table_name}|{col_name}"
        if key in self._colmaps.keys():
            orig_name = self._colmaps[key]["COL_NAME_SRC"]
        if not orig_name:
            orig_name = table_name
        return orig_name    

    def _insert_rows(self, table_name, cols, rows) -> int:
        """Insert rows into the source table."""
        if not rows:
            return 0
        count = self._schema_src.db.table_insert(table_name, rows, cols)
        return count

    def _update_rows(self, table_name, cols, rows, pk_fields_list: list) -> int:
        """Update rows based on primary key field."""
        if not rows:
            return 0
        count = self._schema_src.db.table_update(table_name, rows, cols, pk_fields_list)
        return count
    
    def _delete_rows(self, table_name, pk_fields_list: list, pk_values: List[str]) -> int:
        """Delete rows based on primary key values."""
        if not pk_values:
            return 0
        count = self._schema_src.db.table_delete(table_name, pk_fields_list, pk_values)
        return count

    def _get_col_type(self, tbl: str, col: str) -> str:
        key = f"{tbl}|{col}"
        if key in self._colmaps and self._colmaps[key]:
            return self._colmaps[key].get('DATA_TYPE_TRG')
        return "VARCHAR"

    def _convert_postgres_to_oracle(self, table_name, cols, row):
        ora_row = []
        for i, val in enumerate(row):
            # column names returned by connectors are upper-cased
            col_name = cols[i] if cols else f"col{i}"
            pg_type = self._get_col_type(table_name, col_name)
            ora_row.append(PgToOraConvert.convert(val, pg_type))
        return ora_row


class PgToOraConvert:
    @staticmethod
    def convert(value, pg_type: str):
        """
        Convert Postgres data value to Oracle equivalent format.
        """
         # Handle NULL value
        if value is None:
            return None
        
        pg_type_normalized = pg_type.upper().strip()
        # BOOLEAN to CHAR(1) conversion
        if pg_type_normalized == "BOOLEAN":
            return PgToOraConvert._convert_boolean(value)
        # SMALLINT, BIGINT, NUMERIC conversions
        if pg_type_normalized in ("SMALLINT", "BIGINT") or pg_type_normalized.startswith("NUMERIC"):
            return PgToOraConvert._convert_numeric(value)
        # BYTEA to BLOB conversion (keep as bytes)
        if pg_type_normalized == "BYTEA":
            return PgToOraConvert._convert_bytea(value)
        # VARCHAR and CHARACTER types (string conversions)
        if pg_type_normalized.startswith("CHARACTER VARYING") or pg_type_normalized.startswith("CHARACTER("):
            return PgToOraConvert._convert_string(value)
        # TEXT to CLOB conversion (keep as string)
        if pg_type_normalized == "TEXT":
            return PgToOraConvert._convert_string(value)
        # TIMESTAMP and DATE conversions (return as-is, DB handles conversion)
        if "TIMESTAMP" in pg_type_normalized or "DATE" in pg_type_normalized:
            return value
        return value
    
    @staticmethod
    def _convert_boolean(value):
        if isinstance(value, bool):
            return '1' if value else '0'
        elif isinstance(value, str):
            return '1' if value.lower() in ('true', 't', '1', 'yes') else '0'
        return '0'
    
    @staticmethod
    def _convert_numeric(value):
        if isinstance(value, str):
            try:
                return float(value) if '.' in value else int(value)
            except (ValueError, TypeError):
                pass
        return value

    @staticmethod
    def _convert_bytea(value):
        if isinstance(value, memoryview):
            # Convert memoryview to bytes
            return value.tobytes()
        elif isinstance(value, bytearray):
            # Convert bytearray to bytes
            return bytes(value)
        elif isinstance(value, bytes):
            # Already bytes
            return value
        elif isinstance(value, str):
            # If it's a hex string, convert to bytes
            try:
                return bytes.fromhex(value.replace('\\x', ''))
            except (ValueError, AttributeError):
                return value.encode() if isinstance(value, str) else value
        return value
    
    @staticmethod
    def _convert_string(value):
        return value if isinstance(value, str) else str(value)
