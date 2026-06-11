
from source_code.dbconnectors import oracle_connector


class SrcConverter(oracle_connector.OracleConvert):
    def __init__(self, debug: bool = False):
        super().__init__(debug)


class SrcConnector(oracle_connector.OracleConnect):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = SrcConverter()