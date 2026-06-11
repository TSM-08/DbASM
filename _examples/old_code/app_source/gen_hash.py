import hashlib
import concurrent.futures
import time
import threading
from . import app_utils as utils
from .app_base import AppBase
from .as_schema import SchemaProcessor


class HashMaker:
    """Generates hashes for database table rows."""

    EXCLUDED_COLS = ["SCHEMA_NAME", "TABLE_NAME", "PK_COL", "PK_VALUE"]
    HASH_COLS = ["SCHEMA_NAME", "TABLE_NAME", "PK_COL", "PK_VALUE", "ROW_HASH"]
    _print_lock = threading.Lock()  # Thread-safe print lock

    def __init__(self, schema: SchemaProcessor, config: dict, debug: bool=False):
        self._schema = schema
        self._config = config
        self._debug: bool = debug

        self._fetch_rows = config.get('hashing', {}).get('dbs_chunk_rows', 10_000)

        self._qry_id = schema.assessment.hash_qry_id
        if not self._qry_id:
            raise ValueError("No hash query defined in the schema processor.")

    def generate_table_hashes_old(self, schema_name, table_name, title, data, hash_path, chunk_num=1):
        """Generate and save hashes for a table chunk."""
        pkey_pos = utils.get_position(title, 'PK_VALUE')
        if pkey_pos == -1:
            raise ValueError("PK_VALUE column not found in columns.")

        hash_rows = [
            [schema_name, table_name, row[pkey_pos], 
             self.hash_row(table_name, utils.sort_row_by_columns(title, row, self.EXCLUDED_COLS))]
            for row in data or []
        ]

        utils.save_as_csv(hash_path, hash_rows, self.HASH_COLS, add_mode=(chunk_num > 1))
        return len(hash_rows)

    def generate_table_hashes(self, schema_name, table_name, title, data, hash_path, chunk_num=1):
        """Generate and save hashes for a table chunk, using parallel processing if configured."""
        pkey_col_pos = utils.get_position(title, 'PK_COL')
        pkey_val_pos = utils.get_position(title, 'PK_VALUE')
        if pkey_col_pos == -1:
            raise ValueError("PK_COL column not found in columns.")
        if pkey_val_pos == -1:
            raise ValueError("PK_VALUE column not found in columns.")

        def hash_row_batch(rows_batch):
            """Process a batch of rows and return hashed results."""
            thread_id = threading.get_ident()
            batch_start = time.time()
            with self._print_lock:
                print(f"   [Thread {thread_id}] Processing {len(rows_batch)} rows...")

            result = [
                [schema_name, table_name, row[pkey_col_pos], row[pkey_val_pos],
                self.hash_row(table_name, utils.sort_row_by_columns(title, row, self.EXCLUDED_COLS))]
                for row in rows_batch
            ]

            elapsed = time.time() - batch_start
            with self._print_lock:
                print(f"   [Thread {thread_id}] Completed in {elapsed:.2f}s")
            return result

        data_list = data or []

        if not data_list:
            utils.save_as_csv(hash_path, [], self.HASH_COLS, add_mode=(chunk_num > 1))
            return 0

        hash_workers = self._config.get('hashing', {}).get('hash_workers') or {}
        num_workers = hash_workers.get(table_name, 1)

        start_time = time.time()

        if num_workers and num_workers > 1:
            with self._print_lock:
                print(f"Using {num_workers} parallel workers")
            total_rows = len(data_list)
            bucket_size = (total_rows + num_workers - 1) // num_workers

            buckets = [
                data_list[i:i + bucket_size] 
                for i in range(0, total_rows, bucket_size)
            ]

            with self._print_lock:
                print(f"Split {total_rows} rows into {len(buckets)} buckets")

            hash_rows = []
            with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as executor:
                futures = [executor.submit(hash_row_batch, bucket) for bucket in buckets]
                
                for future in concurrent.futures.as_completed(futures):
                    try:
                        hash_rows.extend(future.result())
                    except Exception as e:
                        with self._print_lock:
                            print(f"Error processing bucket for table {table_name}: {e}")
                        raise
        else:
            with self._print_lock:
                print(f"Using single-threaded processing")
            hash_rows = hash_row_batch(data_list)

        total_time = time.time() - start_time
        if total_time > 0:
            with self._print_lock:
                print(f"Total hashing time: {total_time:.2f}s ({len(hash_rows)/total_time:.0f} rows/sec)")
        else:
            with self._print_lock:
                print(f"Total hashing time: {total_time:.2f}s")

        utils.save_as_csv(hash_path, hash_rows, self.HASH_COLS, add_mode=(chunk_num > 1))
        return len(hash_rows)

    def generate_empty_hash_file(self, schema_name, table_name, hash_path):
        """Create an empty hash file with headers for empty tables."""
        utils.save_as_csv(hash_path, [], HashMaker.HASH_COLS, add_mode=False)

    def generate_hashes(self):
        """
        Generate hashes for all tables defined in the schema assessment.
        Ensures a hash file is created even for empty tables.
        """
        with self._schema.db as db:
            if not isinstance(self._qry_id, str) or not self._qry_id:
                raise ValueError("Hash QueryID must be a non-empty string.")

            cols, rows = self._schema.assessment.get_metadata(self._qry_id)
            col_map = {col: utils.get_position(cols, col) for col in ['SQL', 'SCHEMA_NAME', 'TABLE_NAME']}
            for key, pos in col_map.items():
                if pos == -1:
                    raise ValueError(f"{key} column not found in columns.")

            for row in rows:
                sql_query = row[col_map['SQL']]
                schema_name = row[col_map['SCHEMA_NAME']]
                table_name = row[col_map['TABLE_NAME']]
                hash_path = AppBase.get_hashes_path(self._schema.direction, f'{table_name}.csv')

                print(f"\nGenerating hashes for table: {table_name}")
                chunk_num = 1
                any_data = False

                for title, data in db.read_data_chunks(sql_query, chunk_size=self._fetch_rows):
                    any_data = True
                    hash_count = self.generate_table_hashes(schema_name, table_name, title, data, hash_path, chunk_num)
                    print(f"Retrieved {len(data)} rows, generated {hash_count} hashes.")
                    chunk_num += 1

                if not any_data:
                    # Create an empty hash file with headers if table is empty
                    self.generate_empty_hash_file(schema_name, table_name, hash_path)
                    print(f"Retrieved 0 rows, generated 0 hashes.")

                self._schema.assessment.add_hashfile(table_name, hash_path)
                print(f"Data saved to {hash_path}")

    def hash_row(self, table_name, sorted_row):
        """
        Generate SHA256 hash for a row.
        """
        cols = sorted_row[0]
        row = sorted_row[1]
        conv = getattr(self._schema.db, 'converter', None)
        if conv is None:
            raise ValueError("Database converter is not defined.")

        row_str = '|'.join(conv.convert_row(table_name, cols, row))
        if AppBase.is_debug():
            print(f"Row string for hashing: {row_str}")

        return hashlib.sha256(row_str.encode('utf-8')).hexdigest()