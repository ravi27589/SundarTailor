class DatabaseSchema {
  const DatabaseSchema._();

  static const version = 4;

  static const createCustomers = '''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  customer_number TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  shirt_measurements TEXT NOT NULL DEFAULT '{}',
  trouser_measurements TEXT NOT NULL DEFAULT '{}',
  pajama_measurements TEXT NOT NULL DEFAULT '{}',
  suit_measurements TEXT NOT NULL DEFAULT '{}',
  shorts_measurements TEXT NOT NULL DEFAULT '{}',
  kurta_measurements TEXT NOT NULL DEFAULT '{}',
  safari_measurements TEXT NOT NULL DEFAULT '{}',
  notes TEXT NOT NULL DEFAULT '',
  created_date TEXT NOT NULL,
  updated_date TEXT NOT NULL,
  deleted_date TEXT
);
''';

  static const createOrders = '''
CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  order_number TEXT NOT NULL UNIQUE,
  customer_id TEXT NOT NULL,
  booking_date TEXT NOT NULL,
  delivery_date TEXT NOT NULL,
  order_details TEXT NOT NULL,
  comments TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL DEFAULT 1,
  amount REAL NOT NULL DEFAULT 0,
  advance_paid REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  created_date TEXT NOT NULL,
  updated_date TEXT NOT NULL,
  deleted_date TEXT,
  FOREIGN KEY(customer_id) REFERENCES customers(id)
);
''';

  static const createSyncQueue = '''
CREATE TABLE sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_date TEXT NOT NULL,
  last_attempt_date TEXT,
  error TEXT
);
''';

  static const createSyncState = '''
CREATE TABLE sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';

  static const indexes = [
    'CREATE INDEX idx_customers_number ON customers(customer_number);',
    'CREATE INDEX idx_customers_name ON customers(name);',
    'CREATE INDEX idx_customers_phone ON customers(phone);',
    'CREATE INDEX idx_orders_number ON orders(order_number);',
    'CREATE INDEX idx_orders_customer ON orders(customer_id);',
    'CREATE INDEX idx_orders_delivery ON orders(delivery_date);',
    'CREATE INDEX idx_orders_status ON orders(status);',
    'CREATE INDEX idx_sync_queue_created ON sync_queue(created_date);',
  ];
}
