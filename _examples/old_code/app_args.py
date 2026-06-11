import argparse


class BaseMigrationArgs:
    """Parent class enforcing mandatory arguments."""

    def __init__(self, description: str='Post Migration Tool'):
        self._descriprion = description
        parser = self.build_parser()
        self.args = parser.parse_args()

    def get_args(self):
        return self.args

    def build_parser(self):
        """Build parser with mandatory arguments."""
        parser = argparse.ArgumentParser(
            description=self._descriprion,
            formatter_class=argparse.RawDescriptionHelpFormatter
        )

        parser.add_argument(
            '--config-path',
            type=str,
            help='Path to configuration files (default: current directory)',
        )

        parser.add_argument(
            '--ora-user',
            type=str,
            help='Oracle username (overrides config file)'
        )
        
        parser.add_argument(
            '--ora-password',
            type=str,
            help='Oracle password (overrides config file)'
        )

        parser.add_argument(
            '--pgs-host',
            type=str,
            help='PostgreSQL host (overrides config file)'
        )

        parser.add_argument(
            '--pgs-port',
            type=str,
            help='PostgreSQL port (overrides config file)'
        )

        parser.add_argument(
            '--pgs-database',
            type=str,
            help='PostgreSQL database name (overrides config file)'
        )

        parser.add_argument(
            '--pgs-user',
            type=str,
            help='PostgreSQL username (overrides config file)'
        )
        
        parser.add_argument(
            '--pgs-password',
            type=str,
            help='PostgreSQL password (overrides config file)'
        )

        return parser
    
    @staticmethod
    def _get_database_conf(config_conn, direction: str):
        if 'database' not in config_conn:
            return None
        root = config_conn['database']
        if direction not in root:
            return None
        return root[direction]

    def _override_source_credentials(self, config_conn: dict):
        conn = self._get_database_conf(config_conn, 'src')

        # Override Oracle credentials
        if conn and conn.get('type') == 'Oracle':
            if self.args.ora_user:
                conn['username'] = self.args.ora_user
            if self.args.ora_password:
                conn['password'] = self.args.ora_password

    def _override_target_credentials(self, config_conn: dict):
        conn = self._get_database_conf(config_conn, 'trg')

        # Override PostgreSQL credentials
        if conn and conn.get('type') == 'Postgres':
            if self.args.pgs_host:
                conn['host'] = self.args.pgs_host
            if self.args.pgs_port:
                conn['port'] = self.args.pgs_port            
            if self.args.pgs_database:
                conn['database'] = self.args.pgs_database
            if self.args.pgs_user:
                conn['username'] = self.args.pgs_user
            if self.args.pgs_password:
                conn['password'] = self.args.pgs_password