from source_code.dbconnectors import mssql_connector


class TrgConverter(mssql_connector.MssqlConvert):
    def __init__(self, debug: bool = False):
        super().__init__(debug)


class TrgConnector(mssql_connector.MssqlConnect):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = TrgConverter()