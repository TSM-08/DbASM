import argparse
import source_code.app_base as AppBase


class BaseMigrationArgs:
    """Parent class enforcing mandatory arguments."""

    def __init__(self, description: str = 'Post Migration Tool'):
        self._description = description
        self._config = self._load_config()
        parser = self.build_parser()
        self.args = parser.parse_args()

    def get_args(self):
        return self.args

    def _load_config(self) -> dict:
        """Load connection configuration from YAML file."""
        try:
            return AppBase.open_connection_config()
        except Exception as e:
            raise RuntimeError(f"Error loading connection configuration: {e}")

    def _get_database_keys(self) -> dict:
        """Extract all keys from src and trg database configurations."""
        keys = {'src': set(), 'trg': set()}
        
        if 'database' not in self._config:
            return {k: sorted(list(v)) for k, v in keys.items()}
        
        db_config = self._config['database']
        
        if 'src' in db_config and isinstance(db_config['src'], dict):
            keys['src'] = set(db_config['src'].keys())
        
        if 'trg' in db_config and isinstance(db_config['trg'], dict):
            keys['trg'] = set(db_config['trg'].keys())
        
        return {k: sorted(list(v)) for k, v in keys.items()}

    def _add_database_args(self, parser: argparse.ArgumentParser, direction: str, keys: list[str]):
        """Add database-specific arguments to the parser for a given direction."""
        for key in keys:
            parser.add_argument(
                f'--{direction}-{key.replace("_", "-")}',
                type=str,
                dest=f'{direction}_{key}',
                help=f'{direction.upper()} {key} (overrides config file)'
            )

    def build_parser(self):
        """Build parser with dynamic arguments based on connection.yaml."""
        parser = argparse.ArgumentParser(
            description=self._description,
            formatter_class=argparse.RawDescriptionHelpFormatter
        )

        parser.add_argument(
            '--test-connection-only',
            action='store_true',
            help='Test source and target database connections and exit'
        )

        # Get dynamic keys from config file
        db_keys = self._get_database_keys()

        self._add_database_args(parser, 'src', db_keys['src'])
        self._add_database_args(parser, 'trg', db_keys['trg'])

        return parser

    @staticmethod
    def _get_database_conf(config_conn, direction: str):
        if 'database' not in config_conn:
            return None
        root = config_conn['database']
        if direction not in root:
            return None
        return root[direction]

    def _override_credentials(self, config_conn: dict, direction: str, prefix: str):
        """
        Dynamically override configuration values based on parsed arguments.
        
        Args:
            config_conn: Configuration dictionary
            direction: 'src' or 'trg'
            prefix: 'src_' or 'trg_'
        """
        conn = self._get_database_conf(config_conn, direction)
        if not conn:
            return

        # Get all attributes with the given prefix
        for attr_name in vars(self.args):
            if attr_name.startswith(prefix) and getattr(self.args, attr_name) is not None:
                # Extract the key name by removing the prefix
                key = attr_name[len(prefix):]
                conn[key] = getattr(self.args, attr_name)

    def _override_source_credentials(self, config_conn: dict):
        """Override source database configuration."""
        self._override_credentials(config_conn, 'src', 'src_')

    def _override_target_credentials(self, config_conn: dict):
        """Override target database configuration."""
        self._override_credentials(config_conn, 'trg', 'trg_')