from source_code.dbconnectors import postgres_connector


class SrcConverter(postgres_connector.PostgreConvert):
    def __init__(self, debug: bool = False):
        super().__init__(debug)


class SrcConnector(postgres_connector.PostgreConnect):
    def __init__(self, **params):
        super().__init__(**params)
        self.converter = SrcConverter()