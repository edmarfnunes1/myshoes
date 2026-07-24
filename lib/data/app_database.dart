import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';


class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'myshoes.db');

    return openDatabase(
      path,
      version: 8,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await _createProductsTable(database);
        await _createCustomersTable(database);
        await _createOrdersTable(database);
        await _createOrderItemsTable(database);
        await _createProductionBatchTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCustomersTable(database);
        }
        if (oldVersion < 3) {
          await _createLegacyOrdersTable(database);
        }
        if (oldVersion < 4) {
          await _migrateOrdersToInlineCustomer(database);
        }
        if (oldVersion < 5) {
          await _migrateOrdersToItems(database);
        }
        if (oldVersion < 6) {
          await database.execute(
            'ALTER TABLE order_items ADD COLUMN color TEXT',
          );
        }
        if (oldVersion < 7) {
          await database.execute(
            "UPDATE orders SET created_at = substr(created_at, 1, 10)",
          );
        }
        if (oldVersion < 8) {
          await _createProductionBatchTables(database);
        }
      },
    );
  }

  Future<void> _createProductsTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        minimum_size INTEGER NOT NULL,
        maximum_size INTEGER NOT NULL,
        cost_price REAL NOT NULL,
        sale_price REAL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createCustomersTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT
      )
    ''');
  }

  Future<void> _createLegacyOrdersTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        product_id INTEGER NOT NULL,
        shoe_size INTEGER NOT NULL,
        color TEXT,
        quantity INTEGER NOT NULL,
        with_box INTEGER NOT NULL DEFAULT 0,
        sale_value REAL NOT NULL,
        payment_status TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createOrdersTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        payment_status TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createOrderItemsTable(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        shoe_size INTEGER NOT NULL,
        color TEXT,
        quantity INTEGER NOT NULL,
        with_box INTEGER NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)',
    );
  }

  Future<void> _migrateOrdersToInlineCustomer(Database database) async {
    await database.transaction((transaction) async {
      await transaction.execute('ALTER TABLE orders RENAME TO orders_old');
      await transaction.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          customer_phone TEXT,
          product_id INTEGER NOT NULL,
          shoe_size INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          with_box INTEGER NOT NULL DEFAULT 0,
          sale_value REAL NOT NULL,
          payment_status TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await transaction.execute('''
        INSERT INTO orders (
          id, customer_name, customer_phone, product_id, shoe_size, quantity,
          with_box, sale_value, payment_status, notes, created_at
        )
        SELECT
          o.id,
          COALESCE(c.name, 'Cliente não informado'),
          c.phone,
          o.product_id,
          o.shoe_size,
          o.quantity,
          o.with_box,
          o.sale_value,
          o.payment_status,
          o.notes,
          o.created_at
        FROM orders_old o
        LEFT JOIN customers c ON c.id = o.customer_id
      ''');
      await transaction.execute('DROP TABLE orders_old');
    });
  }

  Future<void> _migrateOrdersToItems(Database database) async {
    await database.transaction((transaction) async {
      await transaction.execute('ALTER TABLE orders RENAME TO orders_old');
      await _createOrdersTable(transaction);
      await _createOrderItemsTable(transaction);

      await transaction.execute('''
        INSERT INTO orders (
          id, customer_name, customer_phone, payment_status, notes, created_at
        )
        SELECT
          id, customer_name, customer_phone, payment_status, notes, created_at
        FROM orders_old
      ''');

      await transaction.execute('''
        INSERT INTO order_items (
          order_id, product_id, shoe_size, quantity, with_box, unit_price
        )
        SELECT
          id, product_id, shoe_size, quantity, with_box, sale_value
        FROM orders_old
      ''');

      await transaction.execute('DROP TABLE orders_old');
    });
  }

  Future<void> _createProductionBatchTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS production_batch_orders (
        batch_id INTEGER NOT NULL,
        order_id INTEGER NOT NULL UNIQUE,
        PRIMARY KEY (batch_id, order_id),
        FOREIGN KEY (batch_id) REFERENCES production_batches(id) ON DELETE CASCADE,
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE RESTRICT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_batch_orders_batch_id ON production_batch_orders(batch_id)',
    );
  }
}
