import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _databaseLoading;

  // These small reference tables are requested by several screens at once
  // after login. Keeping them in memory avoids repeated SQLite round-trips;
  // every write below clears the affected entry, so the UI always sees fresh
  // data after an edit.
  List<Map<String, dynamic>>? _companiesCache;
  Future<List<Map<String, dynamic>>>? _companiesLoading;
  List<Map<String, dynamic>>? _materialsCache;
  Future<List<Map<String, dynamic>>>? _materialsLoading;
  List<Map<String, dynamic>>? _productsCache;
  Future<List<Map<String, dynamic>>>? _productsLoading;
  List<Map<String, dynamic>>? _unitsCache;
  Future<List<Map<String, dynamic>>>? _unitsLoading;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    return _databaseLoading ??= _initDB('business_manager.db').then((db) {
      _database = db;
      return db;
    });
  }

  Future<void> warmLookupCache() async {
    await Future.wait([getAllCompanies(), getAllMaterials(), getAllProducts(), getAllUnits()]);
  }

  void _clearCompaniesCache() => _companiesCache = null;
  void _clearMaterialsCache() => _materialsCache = null;
  void _clearProductsCache() => _productsCache = null;
  void _clearUnitsCache() => _unitsCache = null;
  void _clearLookupCaches() {
    _clearCompaniesCache();
    _clearMaterialsCache();
    _clearProductsCache();
    _clearUnitsCache();
  }

  Future<Database> _initDB(String fileName) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms need the FFI-based sqflite implementation.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // On Android/iOS, leave `databaseFactory` as the default, which uses
    // the platform's native SQLite via method channels.

    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, fileName);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 19,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        current_stock REAL NOT NULL DEFAULT 0,
        default_price REAL,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        current_stock REAL NOT NULL DEFAULT 0,
        default_price REAL,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        material_id INTEGER,
        product_id INTEGER,
        item_type TEXT NOT NULL DEFAULT 'material',
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL,
        paid INTEGER NOT NULL DEFAULT 1,
        transaction_date TEXT NOT NULL,
        transaction_number TEXT,
        attachment_path TEXT,
        notes TEXT,
        FOREIGN KEY (company_id) REFERENCES companies (id),
        FOREIGN KEY (material_id) REFERENCES materials (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        balance_id INTEGER,
        FOREIGN KEY (balance_id) REFERENCES expense_balances (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        current_balance REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_balance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        balance_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (balance_id) REFERENCES expense_balances (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE business_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        business_name TEXT NOT NULL DEFAULT 'BizRise',
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        invoice_prefix TEXT NOT NULL DEFAULT 'INV',
        default_payment_days INTEGER NOT NULL DEFAULT 0,
        invoice_footer TEXT,
        logo_path TEXT,
        accent_color TEXT NOT NULL DEFAULT '#1F5AA6',
        invoice_template TEXT NOT NULL DEFAULT 'classic',
        default_invoice_terms TEXT,
        payment_instructions TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        invoice_number TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        issue_date TEXT NOT NULL,
        due_date TEXT,
        valid_until TEXT,
        document_type TEXT NOT NULL DEFAULT 'invoice',
        terms TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (company_id) REFERENCES companies (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        material_id INTEGER,
        product_id INTEGER,
        item_type TEXT NOT NULL DEFAULT 'material',
        quantity REAL NOT NULL,
        price REAL,
        transaction_id INTEGER,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id),
        FOREIGN KEY (material_id) REFERENCES materials (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    await _insertDefaultUnits(db);
    await _insertDefaultExpenseCategories(db);
    await _createIndexes(db);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_product_date ON transactions(product_id, transaction_date DESC)');
  }

  /// These indexes cover the foreign-key joins, common list ordering, and
  /// aggregate lookups used throughout the app. SQLite does not automatically
  /// index foreign keys, so without them those operations slow down as the
  /// business data grows.
  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_companies_active_name ON companies(is_deleted, name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_active_name ON materials(is_deleted, name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_active_name ON products(is_deleted, name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_company_date ON transactions(company_id, transaction_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_material_date ON transactions(material_id, transaction_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type_date ON transactions(type, transaction_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_transaction ON payments(transaction_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_balance ON expenses(balance_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_balance_records_balance ON expense_balance_records(balance_id, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_company ON invoices(company_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_created ON invoices(created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_items_transaction ON invoice_items(transaction_id)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          unit TEXT NOT NULL,
          current_stock REAL NOT NULL DEFAULT 0,
          default_price REAL,
          created_at TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          low_stock_threshold REAL
        )
      ''');
    }
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      await _insertDefaultUnits(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN paid INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE materials ADD COLUMN default_price REAL');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE companies ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE materials ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE materials ADD COLUMN low_stock_threshold REAL');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (transaction_id) REFERENCES transactions (id)
        )
      ''');
      // Backfill: any transaction previously marked paid=1 gets a matching
      // payment recorded now, so it still shows as fully paid under the new
      // payments-based system instead of reverting to "unpaid".
      final paidTransactions = await db.query(
        'transactions',
        where: 'paid = 1 AND price IS NOT NULL',
      );
      for (final t in paidTransactions) {
        final quantity = (t['quantity'] as num).toDouble();
        final price = (t['price'] as num).toDouble();
        await db.insert('payments', {
          'transaction_id': t['id'],
          'amount': quantity * price,
          'payment_date': t['transaction_date'],
          'notes': 'Migrated from old paid status',
        });
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          company_id INTEGER NOT NULL,
          invoice_number TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'draft',
          issue_date TEXT NOT NULL,
          due_date TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (company_id) REFERENCES companies (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE invoice_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          material_id INTEGER NOT NULL,
          quantity REAL NOT NULL,
          price REAL,
          transaction_id INTEGER,
          FOREIGN KEY (invoice_id) REFERENCES invoices (id),
          FOREIGN KEY (material_id) REFERENCES materials (id),
          FOREIGN KEY (transaction_id) REFERENCES transactions (id)
        )
      ''');
    }
    if (oldVersion < 9) {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='invoices'");
      if (tables.isEmpty) {
        await db.execute('''          CREATE TABLE invoices (            id INTEGER PRIMARY KEY AUTOINCREMENT,            company_id INTEGER NOT NULL,            invoice_number TEXT NOT NULL,            status TEXT NOT NULL DEFAULT 'draft',            issue_date TEXT NOT NULL,            due_date TEXT,            notes TEXT,            created_at TEXT NOT NULL,            FOREIGN KEY (company_id) REFERENCES companies (id)          )        ''');
        await db.execute('''          CREATE TABLE invoice_items (            id INTEGER PRIMARY KEY AUTOINCREMENT,            invoice_id INTEGER NOT NULL,            material_id INTEGER NOT NULL,            quantity REAL NOT NULL,            price REAL,            transaction_id INTEGER,            FOREIGN KEY (invoice_id) REFERENCES invoices (id),            FOREIGN KEY (material_id) REFERENCES materials (id),            FOREIGN KEY (transaction_id) REFERENCES transactions (id)          )        ''');
      }
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          description TEXT,
          amount REAL NOT NULL,
          expense_date TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE expense_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
      await db.execute('''
        CREATE TABLE expense_balances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          current_balance REAL NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('ALTER TABLE expenses ADD COLUMN balance_id INTEGER');
      await db.execute('''
        INSERT OR IGNORE INTO expense_categories (name)
        SELECT DISTINCT category FROM expenses WHERE TRIM(category) != ''
      ''');
      await _insertDefaultExpenseCategories(db);
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE expense_balance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          balance_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (balance_id) REFERENCES expense_balances (id)
        )
      ''');
      await db.execute('''
        INSERT INTO expense_balance_records (balance_id, type, amount, notes, created_at)
        SELECT id, 'opening_balance', current_balance, 'Balance when history tracking was enabled', ?
        FROM expense_balances
      ''', [DateTime.now().toIso8601String()]);
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE business_profile (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          business_name TEXT NOT NULL DEFAULT 'BizRise',
          contact_person TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          tax_number TEXT,
          invoice_prefix TEXT NOT NULL DEFAULT 'INV',
          default_payment_days INTEGER NOT NULL DEFAULT 0,
          invoice_footer TEXT
        )
      ''');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE business_profile ADD COLUMN logo_path TEXT');
    }
    if (oldVersion < 15) {
      await db.execute("ALTER TABLE invoices ADD COLUMN valid_until TEXT");
      await db.execute("ALTER TABLE invoices ADD COLUMN document_type TEXT NOT NULL DEFAULT 'invoice'");
      await db.execute("ALTER TABLE invoices ADD COLUMN terms TEXT");
      await db.execute("ALTER TABLE business_profile ADD COLUMN accent_color TEXT NOT NULL DEFAULT '#1F5AA6'");
      await db.execute("ALTER TABLE business_profile ADD COLUMN invoice_template TEXT NOT NULL DEFAULT 'classic'");
      await db.execute("ALTER TABLE business_profile ADD COLUMN default_invoice_terms TEXT");
      await db.execute("ALTER TABLE business_profile ADD COLUMN payment_instructions TEXT");
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE transactions ADD COLUMN transaction_number TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN attachment_path TEXT');
    }
    if (oldVersion < 18) {
      await _createIndexes(db);
    }
    if (oldVersion < 19) {
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE transactions RENAME TO transactions_old');
        await txn.execute('ALTER TABLE invoice_items RENAME TO invoice_items_old');
        await txn.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER NOT NULL,
            material_id INTEGER,
            product_id INTEGER,
            item_type TEXT NOT NULL DEFAULT 'material',
            type TEXT NOT NULL,
            quantity REAL NOT NULL,
            price REAL,
            paid INTEGER NOT NULL DEFAULT 1,
            transaction_date TEXT NOT NULL,
            transaction_number TEXT,
            attachment_path TEXT,
            notes TEXT,
            FOREIGN KEY (company_id) REFERENCES companies (id),
            FOREIGN KEY (material_id) REFERENCES materials (id),
            FOREIGN KEY (product_id) REFERENCES products (id)
          )
        ''');
        await txn.execute('''
          INSERT INTO transactions (id, company_id, material_id, product_id, item_type, type, quantity, price, paid, transaction_date, transaction_number, attachment_path, notes)
          SELECT id, company_id, material_id, NULL, 'material', type, quantity, price, paid, transaction_date, transaction_number, attachment_path, notes
          FROM transactions_old
        ''');
        await txn.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            material_id INTEGER,
            product_id INTEGER,
            item_type TEXT NOT NULL DEFAULT 'material',
            quantity REAL NOT NULL,
            price REAL,
            transaction_id INTEGER,
            FOREIGN KEY (invoice_id) REFERENCES invoices (id),
            FOREIGN KEY (material_id) REFERENCES materials (id),
            FOREIGN KEY (product_id) REFERENCES products (id),
            FOREIGN KEY (transaction_id) REFERENCES transactions (id)
          )
        ''');
        await txn.execute('''
          INSERT INTO invoice_items (id, invoice_id, material_id, product_id, item_type, quantity, price, transaction_id)
          SELECT id, invoice_id, material_id, NULL, 'material', quantity, price, transaction_id
          FROM invoice_items_old
        ''');
        await txn.execute('DROP TABLE invoice_items_old');
        await txn.execute('DROP TABLE transactions_old');
      });
      await db.execute('PRAGMA foreign_keys = ON');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_active_name ON products(is_deleted, name)');
      }
  }

  Future<void> _insertDefaultUnits(Database db) async {
    final defaults = ['kg', 'g', 'liters', 'ml', 'pieces', 'boxes', 'meters', 'bags'];
    for (final unit in defaults) {
      await db.insert('units', {'name': unit});
    }
  }

  Future<void> _insertDefaultExpenseCategories(Database db) async {
    const defaults = ['Rent', 'Transport', 'Utilities', 'Salaries', 'Equipment', 'Marketing', 'Other'];
    for (final category in defaults) {
      await db.insert('expense_categories', {'name': category}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // Companies
  Future<int> insertCompany(Map<String, dynamic> company) async {
    final db = await instance.database;
    final id = await db.insert('companies', company);
    _clearCompaniesCache();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final cached = _companiesCache;
    if (cached != null) return cached;
    return _companiesLoading ??= () async {
      final db = await instance.database;
      final rows = await db.query('companies', where: 'is_deleted = 0', orderBy: 'name ASC');
      _companiesCache = rows;
      _companiesLoading = null;
      return rows;
    }();
  }

  Future<void> updateCompany(int id, Map<String, dynamic> company) async {
    final db = await instance.database;
    await db.update('companies', company, where: 'id = ?', whereArgs: [id]);
    _clearCompaniesCache();
  }

  Future<void> softDeleteCompany(int id) async {
    final db = await instance.database;
    await db.update('companies', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    _clearCompaniesCache();
  }

  Future<void> hardDeleteCompanyWithTransactions(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Deleting a transaction through the UI reverses its stock effect.
      // Apply the same rule here before permanently deleting every one of a
      // company's transactions (including ones created by confirmed invoices).
      final transactions = await txn.query(
        'transactions',
        columns: ['material_id', 'product_id', 'item_type', 'type', 'quantity'],
        where: 'company_id = ?',
        whereArgs: [id],
      );
      for (final transaction in transactions) {
        final quantity = (transaction['quantity'] as num).toDouble();
        final reverseAmount = transaction['type'] == 'in' ? -quantity : quantity;
        if ((transaction['item_type'] ?? 'material') == 'material') {
          final itemId = transaction['material_id'];
          await txn.rawUpdate(
            'UPDATE materials SET current_stock = current_stock + ? WHERE id = ?',
            [reverseAmount, itemId],
          );
        }
      }

      // Remove invoices as well, so neither invoices nor line items retain a
      // reference to the company being permanently deleted.
      await txn.delete(
        'invoice_items',
        where: 'invoice_id IN (SELECT id FROM invoices WHERE company_id = ?)',
        whereArgs: [id],
      );
      await txn.delete('invoices', where: 'company_id = ?', whereArgs: [id]);
      await txn.delete(
        'payments',
        where: 'transaction_id IN (SELECT id FROM transactions WHERE company_id = ?)',
        whereArgs: [id],
      );
      await txn.delete('transactions', where: 'company_id = ?', whereArgs: [id]);
      await txn.delete('companies', where: 'id = ?', whereArgs: [id]);
    });
    _clearLookupCaches();
  }

  // Materials
  Future<int> insertMaterial(Map<String, dynamic> material) async {
    final db = await instance.database;
    final id = await db.insert('materials', material);
    _clearMaterialsCache();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllMaterials() async {
    final cached = _materialsCache;
    if (cached != null) return cached;
    return _materialsLoading ??= () async {
      final db = await instance.database;
      final rows = await db.query('materials', where: 'is_deleted = 0', orderBy: 'name ASC');
      _materialsCache = rows;
      _materialsLoading = null;
      return rows;
    }();
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    final id = await db.insert('products', product);
    _clearProductsCache();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final cached = _productsCache;
    if (cached != null) return cached;
    return _productsLoading ??= () async {
      final db = await instance.database;
      final rows = await db.query('products', where: 'is_deleted = 0', orderBy: 'name ASC');
      _productsCache = rows;
      _productsLoading = null;
      return rows;
    }();
  }

  Future<void> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await instance.database;
    await db.update('products', product, where: 'id = ?', whereArgs: [id]);
    _clearProductsCache();
  }

  Future<void> softDeleteProduct(int id) async {
    final db = await instance.database;
    await db.update('products', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    _clearProductsCache();
  }

  Future<void> hardDeleteProductWithTransactions(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('invoice_items', where: 'product_id = ?', whereArgs: [id]);
      await txn.delete('payments', where: 'transaction_id IN (SELECT id FROM transactions WHERE product_id = ?)', whereArgs: [id]);
      await txn.delete('transactions', where: 'product_id = ?', whereArgs: [id]);
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
    _clearProductsCache();
  }


  Future<List<Map<String, dynamic>>> getLowStockMaterials() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT * FROM materials
      WHERE is_deleted = 0
        AND low_stock_threshold IS NOT NULL
        AND current_stock <= low_stock_threshold
      ORDER BY name ASC
    ''');
  }

  Future<void> updateMaterial(int id, Map<String, dynamic> material) async {
    final db = await instance.database;
    await db.update('materials', material, where: 'id = ?', whereArgs: [id]);
    _clearMaterialsCache();
  }

  Future<void> softDeleteMaterial(int id) async {
    final db = await instance.database;
    await db.update('materials', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
    _clearMaterialsCache();
  }

  Future<void> hardDeleteMaterialWithTransactions(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('invoice_items', where: 'material_id = ?', whereArgs: [id]);
      await txn.delete(
        'payments',
        where: 'transaction_id IN (SELECT id FROM transactions WHERE material_id = ?)',
        whereArgs: [id],
      );
      await txn.delete('transactions', where: 'material_id = ?', whereArgs: [id]);
      await txn.delete('materials', where: 'id = ?', whereArgs: [id]);
    });
    _clearMaterialsCache();
  }

  Future<void> updateMaterialStock(int materialId, double changeAmount) async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE materials
      SET current_stock = current_stock + ?
      WHERE id = ?
    ''', [changeAmount, materialId]);
    _clearMaterialsCache();
  }

  /// Copies a selected bill image into storage owned by the app. The original
  /// file can therefore be moved or deleted without breaking the transaction.
  Future<String> saveTransactionAttachment(String sourcePath) async {
    final databaseDirectory = await databaseFactory.getDatabasesPath();
    final attachmentsDirectory = Directory(join(databaseDirectory, 'transaction_attachments'));
    await attachmentsDirectory.create(recursive: true);
    final source = File(sourcePath);
    if (!await source.exists()) throw Exception('The selected bill image could not be found.');
    final sourceExtension = extension(sourcePath);
    final fileName = 'bill_${DateTime.now().microsecondsSinceEpoch}${sourceExtension.isEmpty ? '.jpg' : sourceExtension}';
    final destination = File(join(attachmentsDirectory.path, fileName));
    await source.copy(destination.path);
    return destination.path;
  }

  // Transactions
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction);
  }

  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid
        FROM payments
        GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      ORDER BY transaction_date DESC
    ''');
  }

  /// Small, bounded data set for the Overview page. Keeping this separate
  /// prevents the dashboard from loading every transaction just to show six.
  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 6}) async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      ORDER BY transactions.transaction_date DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<Map<String, double>> getCurrentMonthTransactionTotals() async {
    final db = await instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'in' AND price IS NOT NULL THEN quantity * price ELSE 0 END), 0) AS bought,
        COALESCE(SUM(CASE WHEN type = 'out' AND price IS NOT NULL THEN quantity * price ELSE 0 END), 0) AS sold
      FROM transactions
      WHERE transaction_date >= ? AND transaction_date < ?
    ''', [start.toIso8601String(), nextMonth.toIso8601String()]);
    final row = rows.first;
    return {
      'bought': (row['bought'] as num).toDouble(),
      'sold': (row['sold'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getTransactionsByCompany(int companyId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      WHERE transactions.company_id = ?
      ORDER BY transaction_date DESC
    ''', [companyId]);
  }

  Future<List<Map<String, dynamic>>> getMaterialTotalsByCompany(int companyId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT
        CASE WHEN transactions.item_type = 'product' THEN products.id ELSE materials.id END AS material_id,
        COALESCE(materials.name, products.name) AS material_name,
        COALESCE(materials.unit, products.unit) AS material_unit,
        transactions.item_type,
        SUM(CASE WHEN transactions.type = 'in' THEN transactions.quantity ELSE 0 END) AS bought_qty,
        SUM(CASE WHEN transactions.type = 'out' THEN transactions.quantity ELSE 0 END) AS sold_qty,
        SUM(CASE WHEN transactions.type = 'in' AND transactions.price IS NOT NULL THEN transactions.quantity * transactions.price ELSE 0 END) AS bought_amount,
        SUM(CASE WHEN transactions.type = 'out' AND transactions.price IS NOT NULL THEN transactions.quantity * transactions.price ELSE 0 END) AS sold_amount
      FROM transactions
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      WHERE transactions.company_id = ?
      GROUP BY transactions.item_type, CASE WHEN transactions.item_type = 'product' THEN products.id ELSE materials.id END
      ORDER BY material_name ASC
    ''', [companyId]);
  }

  Future<List<Map<String, dynamic>>> getCompanyBalances() async {
    final db = await instance.database;
    return await db.rawQuery('''
      WITH transaction_totals AS (
        SELECT company_id,
          SUM(CASE WHEN type = 'in' AND price IS NOT NULL THEN quantity * price ELSE 0 END) AS in_total,
          SUM(CASE WHEN type = 'out' AND price IS NOT NULL THEN quantity * price ELSE 0 END) AS out_total
        FROM transactions
        GROUP BY company_id
      ), payment_totals AS (
        SELECT transactions.company_id,
          SUM(CASE WHEN transactions.type = 'in' THEN payments.amount ELSE 0 END) AS in_paid,
          SUM(CASE WHEN transactions.type = 'out' THEN payments.amount ELSE 0 END) AS out_paid
        FROM payments
        JOIN transactions ON transactions.id = payments.transaction_id
        GROUP BY transactions.company_id
      )
      SELECT companies.id AS company_id,
        COALESCE(transaction_totals.in_total, 0) AS in_total,
        COALESCE(transaction_totals.out_total, 0) AS out_total,
        COALESCE(payment_totals.in_paid, 0) AS in_paid,
        COALESCE(payment_totals.out_paid, 0) AS out_paid
      FROM companies
      LEFT JOIN transaction_totals ON transaction_totals.company_id = companies.id
      LEFT JOIN payment_totals ON payment_totals.company_id = companies.id
      WHERE companies.is_deleted = 0
    ''');
  }

  Future<List<Map<String, dynamic>>> getTransactionsByMaterial(int materialId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      WHERE transactions.material_id = ? AND transactions.item_type = 'material'
      ORDER BY transaction_date DESC
    ''', [materialId]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByProduct(int productId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, products.name AS material_name, products.unit AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      WHERE transactions.product_id = ? AND transactions.item_type = 'product'
      ORDER BY transaction_date DESC
    ''', [productId]);
  }

  /// Transactions that are unpaid or partially paid, with the due date
  /// pulled from a linked invoice when one exists (a transaction created
  /// directly, not via an invoice, will have a null due_date here).
  /// Ordered so overdue items surface first, then oldest unpaid first.
  Future<List<Map<String, dynamic>>> getUnpaidTransactions() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String();
    return db.rawQuery('''
      SELECT transactions.*, companies.name AS company_name, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid, due_dates.due_date
      FROM transactions
      JOIN companies ON transactions.company_id = companies.id
      LEFT JOIN materials ON transactions.material_id = materials.id
      LEFT JOIN products ON transactions.product_id = products.id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      LEFT JOIN (
        SELECT invoice_items.transaction_id, MIN(invoices.due_date) AS due_date
        FROM invoice_items
        JOIN invoices ON invoices.id = invoice_items.invoice_id
        WHERE invoices.due_date IS NOT NULL
        GROUP BY invoice_items.transaction_id
      ) AS due_dates ON due_dates.transaction_id = transactions.id
      WHERE transactions.price IS NOT NULL
        AND companies.is_deleted = 0
        AND COALESCE(payment_totals.amount_paid, 0) < (transactions.quantity * transactions.price) - 0.01
      ORDER BY CASE WHEN due_dates.due_date IS NOT NULL AND due_dates.due_date < ? THEN 0 ELSE 1 END,
        COALESCE(due_dates.due_date, transactions.transaction_date) ASC
    ''', [today]);
  }

  Future<int> getUnpaidTransactionCount() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM transactions
      JOIN companies ON companies.id = transactions.company_id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      WHERE transactions.price IS NOT NULL
        AND companies.is_deleted = 0
        AND COALESCE(payment_totals.amount_paid, 0) < (transactions.quantity * transactions.price) - 0.01
    ''');
    return (rows.first['count'] as num).toInt();
  }

  /// Whether the unpaid-payments reminder should be shown: there's at
  /// least one overdue (or long-outstanding, if no due date) unpaid
  /// transaction, and we haven't already prompted today.
  Future<bool> shouldShowUnpaidReminder() async {
    final lastPromptText = await getAppSetting('unpaid_reminder_last_prompt');
    if (lastPromptText != null) {
      final lastPrompt = DateTime.tryParse(lastPromptText);
      if (lastPrompt != null && DateTime.now().difference(lastPrompt) < const Duration(hours: 20)) {
        return false;
      }
    }

    final today = DateTime.now();
    final staleDate = today.subtract(const Duration(days: 14));
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT 1
      FROM transactions
      JOIN companies ON companies.id = transactions.company_id
      LEFT JOIN (
        SELECT transaction_id, SUM(amount) AS amount_paid FROM payments GROUP BY transaction_id
      ) AS payment_totals ON payment_totals.transaction_id = transactions.id
      LEFT JOIN (
        SELECT invoice_items.transaction_id, MIN(invoices.due_date) AS due_date
        FROM invoice_items
        JOIN invoices ON invoices.id = invoice_items.invoice_id
        WHERE invoices.due_date IS NOT NULL
        GROUP BY invoice_items.transaction_id
      ) AS due_dates ON due_dates.transaction_id = transactions.id
      WHERE transactions.price IS NOT NULL
        AND companies.is_deleted = 0
        AND COALESCE(payment_totals.amount_paid, 0) < (transactions.quantity * transactions.price) - 0.01
        AND (
          (due_dates.due_date IS NOT NULL AND due_dates.due_date < ?)
          OR (due_dates.due_date IS NULL AND transactions.transaction_date < ?)
        )
      LIMIT 1
    ''', [today.toIso8601String(), staleDate.toIso8601String()]);
    return rows.isNotEmpty;
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> transaction) async {
    final db = await instance.database;
    await db.update('transactions', transaction, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await instance.database;
    await db.delete('payments', where: 'transaction_id = ?', whereArgs: [id]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Payments
  Future<int> insertPayment(Map<String, dynamic> payment) async {
    final db = await instance.database;
    return await db.insert('payments', payment);
  }

  Future<List<Map<String, dynamic>>> getPaymentsForTransaction(int transactionId) async {
    final db = await instance.database;
    return await db.query('payments', where: 'transaction_id = ?', whereArgs: [transactionId], orderBy: 'payment_date ASC');
  }

  Future<void> deletePayment(int id) async {
    final db = await instance.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // Expenses
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT expenses.*, expense_balances.name AS balance_name
      FROM expenses
      LEFT JOIN expense_balances ON expense_balances.id = expenses.balance_id
      ORDER BY expense_date DESC, expenses.id DESC
    ''');
  }

  Future<double> getCurrentMonthExpensesTotal() async {
    final db = await instance.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
    ''', [start.toIso8601String(), nextMonth.toIso8601String()]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<void> updateExpense(int id, Map<String, dynamic> expense) async {
    final db = await instance.database;
    await db.update('expenses', expense, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> createExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final expenseId = await txn.insert('expenses', expense);
      final balanceId = expense['balance_id'];
      if (balanceId != null) {
        await txn.rawUpdate(
          'UPDATE expense_balances SET current_balance = current_balance - ? WHERE id = ?',
          [expense['amount'], balanceId],
        );
        await txn.insert('expense_balance_records', {
          'balance_id': balanceId,
          'type': 'expense',
          'amount': -(expense['amount'] as num).toDouble(),
          'notes': 'Expense #$expenseId: ${expense['category']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> updateExpenseAndBalance(int id, Map<String, dynamic> expense) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final previous = await txn.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (previous.isEmpty) throw Exception('Expense not found.');
      final oldExpense = previous.first;
      if (oldExpense['balance_id'] != null) {
        await txn.rawUpdate(
          'UPDATE expense_balances SET current_balance = current_balance + ? WHERE id = ?',
          [oldExpense['amount'], oldExpense['balance_id']],
        );
        await txn.insert('expense_balance_records', {
          'balance_id': oldExpense['balance_id'],
          'type': 'expense_reversal',
          'amount': (oldExpense['amount'] as num).toDouble(),
          'notes': 'Expense #$id was edited',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.update('expenses', expense, where: 'id = ?', whereArgs: [id]);
      if (expense['balance_id'] != null) {
        await txn.rawUpdate(
          'UPDATE expense_balances SET current_balance = current_balance - ? WHERE id = ?',
          [expense['amount'], expense['balance_id']],
        );
        await txn.insert('expense_balance_records', {
          'balance_id': expense['balance_id'],
          'type': 'expense',
          'amount': -(expense['amount'] as num).toDouble(),
          'notes': 'Expense #$id: ${expense['category']}',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> deleteExpenseAndRestoreBalance(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      final expense = rows.first;
      if (expense['balance_id'] != null) {
        await txn.rawUpdate(
          'UPDATE expense_balances SET current_balance = current_balance + ? WHERE id = ?',
          [expense['amount'], expense['balance_id']],
        );
        await txn.insert('expense_balance_records', {
          'balance_id': expense['balance_id'],
          'type': 'expense_reversal',
          'amount': (expense['amount'] as num).toDouble(),
          'notes': 'Expense #$id was deleted',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getAllExpenseCategories() async {
    final db = await instance.database;
    return db.query('expense_categories', orderBy: 'name ASC');
  }

  /// Monthly income (sales) vs expenses for the last [months] months
  /// (oldest first), for the Overview trend chart. Income is sales
  /// (transactions.type = 'out'), matching how the dashboard already
  /// treats 'out' as receivable/sales elsewhere. Expenses is the
  /// `expenses` table, matching the existing "This Month Expenses" card
  /// — material purchases ('in' transactions) are tracked separately as
  /// payable and intentionally excluded here to avoid double meaning.
  Future<List<Map<String, dynamic>>> getMonthlyIncomeExpenseTrend({int months = 6}) async {
    final db = await instance.database;
    final now = DateTime.now();
    final monthKeys = List.generate(months, (i) {
      final d = DateTime(now.year, now.month - (months - 1 - i));
      return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    });

    final incomeRows = await db.rawQuery('''
      SELECT strftime('%Y-%m', transaction_date) AS ym,
        COALESCE(SUM(CASE WHEN price IS NOT NULL THEN quantity * price ELSE 0 END), 0) AS total
      FROM transactions
      WHERE type = 'out'
      GROUP BY ym
    ''');
    final expenseRows = await db.rawQuery('''
      SELECT strftime('%Y-%m', expense_date) AS ym, COALESCE(SUM(amount), 0) AS total
      FROM expenses
      GROUP BY ym
    ''');

    final incomeByMonth = {for (final r in incomeRows) r['ym'] as String: (r['total'] as num).toDouble()};
    final expenseByMonth = {for (final r in expenseRows) r['ym'] as String: (r['total'] as num).toDouble()};

    return monthKeys
        .map((ym) => {
              'month': ym,
              'income': incomeByMonth[ym] ?? 0.0,
              'expense': expenseByMonth[ym] ?? 0.0,
            })
        .toList();
  }

  /// Expense totals grouped by category (all-time), for the Overview
  /// donut chart. Ordered largest first.
  Future<List<Map<String, dynamic>>> getExpenseCategoryTotals() async {
    final db = await instance.database;
    return db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) AS total
      FROM expenses
      GROUP BY category
      HAVING total > 0
      ORDER BY total DESC
    ''');
  }

  Future<int> insertExpenseCategory(String name) async {
    final db = await instance.database;
    return db.insert('expense_categories', {'name': name});
  }

  Future<void> deleteExpenseCategory(int id) async {
    final db = await instance.database;
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllExpenseBalances() async {
    final db = await instance.database;
    return db.query('expense_balances', orderBy: 'name ASC');
  }

  Future<int> insertExpenseBalance(String name, double currentBalance) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      final id = await txn.insert('expense_balances', {'name': name, 'current_balance': currentBalance});
      await txn.insert('expense_balance_records', {
        'balance_id': id,
        'type': 'opening_balance',
        'amount': currentBalance,
        'notes': 'Opening balance',
        'created_at': DateTime.now().toIso8601String(),
      });
      return id;
    });
  }

  Future<void> updateExpenseBalance(int id, String name, double currentBalance) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final previous = await txn.query('expense_balances', where: 'id = ?', whereArgs: [id]);
      if (previous.isEmpty) throw Exception('Balance not found.');
      final oldAmount = (previous.first['current_balance'] as num).toDouble();
      await txn.update('expense_balances', {'name': name, 'current_balance': currentBalance}, where: 'id = ?', whereArgs: [id]);
      final difference = currentBalance - oldAmount;
      if (difference != 0) {
        await txn.insert('expense_balance_records', {
          'balance_id': id,
          'type': 'manual_adjustment',
          'amount': difference,
          'notes': 'Balance manually adjusted',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> addToExpenseBalance(int id, double amount) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE expense_balances SET current_balance = current_balance + ? WHERE id = ?',
        [amount, id],
      );
      await txn.insert('expense_balance_records', {
        'balance_id': id,
        'type': 'funds_added',
        'amount': amount,
        'notes': 'Funds added',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getExpenseBalanceRecords(int balanceId) async {
    final db = await instance.database;
    return db.query('expense_balance_records', where: 'balance_id = ?', whereArgs: [balanceId], orderBy: 'id DESC');
  }

  Future<void> deleteExpenseBalance(int id) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM expenses WHERE balance_id = ?', [id]);
    final count = (result.first['count'] as num?)?.toInt() ?? 0;
    if (count > 0) throw Exception('This balance is used by existing expenses and cannot be deleted.');
    await db.delete('expense_balances', where: 'id = ?', whereArgs: [id]);
  }

  // Invoices
  Future<int> insertInvoice(Map<String, dynamic> invoice) async {
    final db = await instance.database;
    return await db.insert('invoices', invoice);
  }

  Future<String> generateNextInvoiceNumber() async {
    final db = await instance.database;
    final profile = await getBusinessProfile();
    final prefix = (profile['invoice_prefix'] as String).trim().isEmpty ? 'INV' : (profile['invoice_prefix'] as String).trim();

    // Base the next number on the highest existing numeric suffix for this
    // prefix (not a row count), so deleting an invoice never causes the
    // next auto-suggested number to collide with one that's still in use.
    final rows = await db.query(
      'invoices',
      columns: ['invoice_number'],
      where: 'invoice_number LIKE ?',
      whereArgs: ['$prefix-%'],
    );

    var maxNumber = 0;
    for (final row in rows) {
      final invoiceNumber = row['invoice_number'] as String;
      final suffix = invoiceNumber.substring(prefix.length + 1);
      final parsed = int.tryParse(suffix);
      if (parsed != null && parsed > maxNumber) maxNumber = parsed;
    }

    var next = maxNumber + 1;
    var candidate = '$prefix-${next.toString().padLeft(4, '0')}';
    // Guard against any remaining edge case (e.g. a manually entered number
    // that doesn't match the padded format) by walking forward until free.
    while (await invoiceNumberExists(candidate)) {
      next++;
      candidate = '$prefix-${next.toString().padLeft(4, '0')}';
    }
    return candidate;
  }

  Future<bool> invoiceNumberExists(String invoiceNumber, {int? excludingId}) async {
    final db = await instance.database;
    final rows = await db.query(
      'invoices',
      where: excludingId == null ? 'invoice_number = ?' : 'invoice_number = ? AND id != ?',
      whereArgs: excludingId == null ? [invoiceNumber] : [invoiceNumber, excludingId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, dynamic>> getBusinessProfile() async {
    final db = await instance.database;
    final rows = await db.query('business_profile', where: 'id = 1');
    if (rows.isNotEmpty) return rows.first;
    return {
      'id': 1,
      'business_name': 'BizRise',
      'contact_person': '',
      'phone': '',
      'email': '',
      'address': '',
      'tax_number': '',
      'invoice_prefix': 'INV',
      'default_payment_days': 0,
      'invoice_footer': '',
      'logo_path': '',
      'accent_color': '#1F5AA6',
      'invoice_template': 'classic',
      'default_invoice_terms': '',
      'payment_instructions': '',
    };
  }

  Future<void> saveBusinessProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;
    await db.insert('business_profile', {'id': 1, ...profile}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllInvoices() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT invoices.*, companies.name AS company_name,
        COALESCE(item_totals.total_amount, 0) AS total_amount,
        COALESCE(payment_totals.amount_paid, 0) AS amount_paid
      FROM invoices
      JOIN companies ON invoices.company_id = companies.id
      LEFT JOIN (
        SELECT invoice_id, SUM(quantity * COALESCE(price, 0)) AS total_amount
        FROM invoice_items GROUP BY invoice_id
      ) AS item_totals ON item_totals.invoice_id = invoices.id
      LEFT JOIN (
        SELECT invoice_items.invoice_id, SUM(payments.amount) AS amount_paid
        FROM invoice_items
        JOIN payments ON payments.transaction_id = invoice_items.transaction_id
        GROUP BY invoice_items.invoice_id
      ) AS payment_totals ON payment_totals.invoice_id = invoices.id
      ORDER BY invoices.created_at DESC
    ''');
  }

  Future<double> getConfirmedInvoiceDue() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE
          WHEN COALESCE(item_totals.total_amount, 0) > COALESCE(payment_totals.amount_paid, 0)
          THEN COALESCE(item_totals.total_amount, 0) - COALESCE(payment_totals.amount_paid, 0)
          ELSE 0
        END
      ), 0) AS total_due
      FROM invoices
      LEFT JOIN (
        SELECT invoice_id, SUM(quantity * COALESCE(price, 0)) AS total_amount
        FROM invoice_items GROUP BY invoice_id
      ) AS item_totals ON item_totals.invoice_id = invoices.id
      LEFT JOIN (
        SELECT invoice_items.invoice_id, SUM(payments.amount) AS amount_paid
        FROM invoice_items
        JOIN payments ON payments.transaction_id = invoice_items.transaction_id
        GROUP BY invoice_items.invoice_id
      ) AS payment_totals ON payment_totals.invoice_id = invoices.id
      WHERE invoices.status = 'confirmed'
    ''');
    return (rows.first['total_due'] as num).toDouble();
  }

  Future<void> recordInvoicePayment(int invoiceId, double amount, {String notes = ''}) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      final transactionRows = await txn.rawQuery('''
        SELECT transactions.id, transactions.quantity, transactions.price,
          COALESCE(SUM(payments.amount), 0) AS amount_paid
        FROM invoice_items
        JOIN transactions ON transactions.id = invoice_items.transaction_id
        LEFT JOIN payments ON payments.transaction_id = transactions.id
        WHERE invoice_items.invoice_id = ?
        GROUP BY transactions.id
        ORDER BY invoice_items.id ASC
      ''', [invoiceId]);

      var remainingPayment = amount;
      for (final row in transactionRows) {
        if (remainingPayment <= 0) break;
        if (row['price'] == null) continue;

        final total = (row['quantity'] as num).toDouble() * (row['price'] as num).toDouble();
        final alreadyPaid = (row['amount_paid'] as num).toDouble();
        final due = total - alreadyPaid;
        if (due <= 0) continue;

        final applied = remainingPayment < due ? remainingPayment : due;
        await txn.insert('payments', {
          'transaction_id': row['id'],
          'amount': applied,
          'payment_date': DateTime.now().toIso8601String(),
          'notes': notes,
        });
        remainingPayment -= applied;
      }

      if (remainingPayment > 0.01) {
        throw Exception('Payment exceeds the invoice balance.');
      }
    });
  }

  Future<Map<String, dynamic>?> getInvoiceById(int id) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT invoices.*, companies.name AS company_name, companies.contact_person, companies.phone, companies.address
      FROM invoices
      JOIN companies ON invoices.company_id = companies.id
      WHERE invoices.id = ?
    ''', [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateInvoice(int id, Map<String, dynamic> invoice) async {
    final db = await instance.database;
    await db.update('invoices', invoice, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInvoice(int id) async {
    final db = await instance.database;
    final items = await getInvoiceItems(id);
    await db.transaction((txn) async {
      for (final item in items) {
        if (item['transaction_id'] != null) {
          final quantity = (item['quantity'] as num).toDouble();
          if ((item['item_type'] ?? 'material') == 'material') {
            await txn.rawUpdate('UPDATE materials SET current_stock = current_stock + ? WHERE id = ?', [quantity, item['material_id']]);
          }
          await txn.delete('payments', where: 'transaction_id = ?', whereArgs: [item['transaction_id']]);
          await txn.delete('transactions', where: 'id = ?', whereArgs: [item['transaction_id']]);
        }
      }
      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
    _clearMaterialsCache();
    _clearProductsCache();
  }

  Future<void> confirmInvoice(int invoiceId) async {
    final db = await instance.database;
    final items = await getInvoiceItems(invoiceId);
    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) throw Exception('Invoice not found');

    await db.transaction((txn) async {
      for (final item in items) {
        final quantity = (item['quantity'] as num).toDouble();
        final itemType = item['item_type'] ?? 'material';
        final transactionId = await txn.insert('transactions', {
          'company_id': invoice['company_id'],
          'material_id': itemType == 'material' ? item['material_id'] : null,
          'product_id': itemType == 'product' ? item['product_id'] : null,
          'item_type': itemType,
          'type': 'out',
          'quantity': quantity,
          'price': item['price'],
          'paid': 0,
          'transaction_date': invoice['issue_date'],
          'notes': 'Invoice ${invoice['invoice_number']}',
        });
        if (itemType == 'material') {
          await txn.rawUpdate('UPDATE materials SET current_stock = current_stock - ? WHERE id = ?', [quantity, item['material_id']]);
        }
        await txn.update('invoice_items', {'transaction_id': transactionId}, where: 'id = ?', whereArgs: [item['id']]);
      }
      await txn.update('invoices', {'status': 'confirmed'}, where: 'id = ?', whereArgs: [invoiceId]);
    });
    _clearMaterialsCache();
    _clearProductsCache();
  }

  // Invoice items
  Future<int> insertInvoiceItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    return await db.insert('invoice_items', item);
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT invoice_items.*, COALESCE(materials.name, products.name) AS material_name, COALESCE(materials.unit, products.unit) AS material_unit
      FROM invoice_items
      LEFT JOIN materials ON invoice_items.material_id = materials.id
      LEFT JOIN products ON invoice_items.product_id = products.id
      WHERE invoice_items.invoice_id = ?
      ORDER BY invoice_items.id ASC
    ''', [invoiceId]);
  }

  Future<void> updateInvoiceItem(int id, Map<String, dynamic> item) async {
    final db = await instance.database;
    await db.update('invoice_items', item, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInvoiceItem(int id) async {
    final db = await instance.database;
    await db.delete('invoice_items', where: 'id = ?', whereArgs: [id]);
  }

  // Units
  Future<int> insertUnit(String name) async {
    final db = await instance.database;
    final id = await db.insert('units', {'name': name});
    _clearUnitsCache();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllUnits() async {
    final cached = _unitsCache;
    if (cached != null) return cached;
    return _unitsLoading ??= () async {
      final db = await instance.database;
      final rows = await db.query('units', orderBy: 'name ASC');
      _unitsCache = rows;
      _unitsLoading = null;
      return rows;
    }();
  }

  Future<void> deleteUnit(int id) async {
    final db = await instance.database;
    await db.delete('units', where: 'id = ?', whereArgs: [id]);
    _clearUnitsCache();
  }

  static const _backupTables = [
    'companies',
    'materials',
    'units',
    'expense_categories',
    'expense_balances',
    'business_profile',
    'transactions',
    'payments',
    'invoices',
    'invoice_items',
    'expenses',
    'expense_balance_records',
  ];

  Future<Map<String, List<Map<String, dynamic>>>> exportBackupData() async {
    final db = await instance.database;
    final data = <String, List<Map<String, dynamic>>>{};
    for (final table in _backupTables) {
      data[table] = await db.query(table);
    }
    return data;
  }

  Future<void> restoreBackupData(Map<String, dynamic> tables) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in const [
        'invoice_items',
        'payments',
        'transactions',
        'invoices',
        'expenses',
        'expense_balance_records',
        'companies',
        'materials',
        'units',
        'expense_categories',
        'expense_balances',
        'business_profile',
      ]) {
        await txn.delete(table);
      }

      for (final table in _backupTables) {
        final rows = tables[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is Map) await txn.insert(table, Map<String, dynamic>.from(row));
        }
      }
    });
    _clearLookupCaches();
  }

  Future<void> updateBusinessLogoPath(String logoPath) async {
    final db = await instance.database;
    await db.update('business_profile', {'logo_path': logoPath}, where: 'id = 1');
  }

  Future<String?> getAppSetting(String key) async {
    final db = await instance.database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert('app_settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> shouldShowBackupReminder() async {
    final lastBackupText = await getAppSetting('last_backup_at');
    final lastPromptText = await getAppSetting('backup_reminder_last_prompt');
    final now = DateTime.now();
    if (lastPromptText != null) {
      final lastPrompt = DateTime.tryParse(lastPromptText);
      if (lastPrompt != null && now.difference(lastPrompt).inHours < 24) return false;
    }
    final lastBackup = lastBackupText == null ? null : DateTime.tryParse(lastBackupText);
    return lastBackup == null || now.difference(lastBackup).inDays >= 7;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
