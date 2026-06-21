from source_code.dbbase_cls import DbConverter
from source_code.dbconnectors import postgres_connector


class SrcConverter(postgres_connector.PostgreConvert):
    def __init__(self, debug: bool = False):
        super().__init__(debug)

    @staticmethod
    def _is_purchase_orders_active_flag(table_name: str, col: str) -> bool:
        return table_name.casefold() == "purchase_orders" and col.casefold() == "is_active"

    def _convert_purchase_orders_active_flag(self, value) -> str:
        if value is None:
            return DbConverter.NULL_VALUE
        return "Y" if value else "N"

    # Override the to_str_value method to handle the special cases
    def to_str_value(self, table_name: str, col: str, value) -> str:
        if self._is_purchase_orders_active_flag(table_name, col):
            return self._convert_purchase_orders_active_flag(value)
        return super().to_str_value(table_name, col, value)


class SrcConnector(postgres_connector.PostgreConnect):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = SrcConverter()