import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('store.db');
    return _database!;
  }

Future<Database> _initDB(String filePath) async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, filePath);

  return await openDatabase(
    path,
    version: 6, // 🆕 گۆڕینی لە 5 بۆ 6
    onCreate: _createDB,
    onUpgrade: _onUpgrade,
  );
}

Future _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      barcode TEXT,
      buy_price REAL NOT NULL,
      sell_price REAL NOT NULL,
      wholesale_price REAL, 
      quantity INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // خشتەی فرۆشتن - بە bulk_sale_id نوێ
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        buy_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        date TEXT NOT NULL,
        bulk_sale_id TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        amount REAL NOT NULL,
        paid REAL DEFAULT 0,
        remaining REAL NOT NULL,
        description TEXT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts (id)
      )
    ''');
  }


Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE sales ADD COLUMN product_name TEXT');
    await db.execute('ALTER TABLE sales ADD COLUMN buy_price REAL DEFAULT 0');
    
    final products = await db.query('products');
    final sales = await db.query('sales');
    
    for (var sale in sales) {
      final product = products.firstWhere(
        (p) => p['id'] == sale['product_id'],
        orElse: () => {'name': 'کاڵای سڕاوە', 'buy_price': 0},
      );
      
      await db.update(
        'sales',
        {
          'product_name': product['name'],
          'buy_price': product['buy_price'] ?? 0,
        },
        where: 'id = ?',
        whereArgs: [sale['id']],
      );
    }
  }
  
  // زیادکردنی bulk_sale_id
  if (oldVersion < 3) {
    await db.execute('ALTER TABLE sales ADD COLUMN bulk_sale_id TEXT');
  }

  // زیادکردنی خانەی barcode بۆ products
  if (oldVersion < 5) {
    try {
      await db.execute('ALTER TABLE products ADD COLUMN wholesale_price REAL');
      print('✅ خانەی wholesale_price زیادکرا');
    } catch (e) {
      print('❌ هەڵە لە زیادکردنی wholesale_price: $e');
    }
  }

  // 🆕 زیادکردنی خانەی wholesale_price بۆ products
  if (oldVersion < 6) {
    try {
      await db.execute('ALTER TABLE products ADD COLUMN wholesale_price REAL');
      print('✅ خانەی wholesale_price زیادکرا لە وەشانی 6');
    } catch (e) {
      print('❌ هەڵە لە زیادکردنی wholesale_price: $e');
    }
  }
}

    Future<bool> _checkIfBarcodeColumnExists(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info(products)');
      return result.any((column) => column['name'] == 'barcode');
    } catch (e) {
      print('هەڵە لە پشکنینی خانەی barcode: $e');
      return false;
    }
  }

 Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final hasBarcodeColumn = await _checkIfBarcodeColumnExists(db);
    
    final Map<String, dynamic> cleanProduct = {
      'name': product['name'],
      'buy_price': product['buy_price'],
      'sell_price': product['sell_price'],
      'quantity': product['quantity'],
      'created_at': product['created_at'],
    };
    
    if (hasBarcodeColumn && product['barcode'] != null) {
      cleanProduct['barcode'] = product['barcode'];
    }
    
    // 🆕 زیادکردنی نرخی جوملە
    if (product['wholesale_price'] != null) {
      cleanProduct['wholesale_price'] = product['wholesale_price'];
    }
    
    return await db.insert('products', cleanProduct);
}

Future<List<Map<String, dynamic>>> getProducts() async {
  final db = await database;
  return await db.query('products', orderBy: 'name ASC');
}

Future<int> updateProduct(int id, Map<String, dynamic> product) async {
  final db = await database;
  
  final Map<String, dynamic> cleanProduct = {
    'name': product['name'],
    'buy_price': product['buy_price'],
    'sell_price': product['sell_price'],
    'quantity': product['quantity'],
    'created_at': product['created_at'],
  };
  
  if (product['barcode'] != null) {
    cleanProduct['barcode'] = product['barcode'];
  } else {
    cleanProduct['barcode'] = null;
  }
  
  // 🆕 زیادکردنی نرخی جوملە
  if (product['wholesale_price'] != null) {
    cleanProduct['wholesale_price'] = product['wholesale_price'];
  }
  
  return await db.update(
    'products', 
    cleanProduct, 
    where: 'id = ?', 
    whereArgs: [id]
  );
}

  Future<int> insertPurchase(Map<String, dynamic> purchase) async {
    final db = await database;
    return await db.insert('purchases', purchase);
  }

  Future<List<Map<String, dynamic>>> getPurchases() async {
    final db = await database;
    return await db.query('purchases', orderBy: 'date DESC');
  }

  Future<int> insertSale(Map<String, dynamic> sale) async {
    final db = await database;
    return await db.insert('sales', sale);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    return await db.query('sales', orderBy: 'date DESC');
  }

  // ← نوێ: وەرگرتنی هەموو فرۆشتنەکانی یەک bulk_sale_id
  Future<List<Map<String, dynamic>>> getBulkSaleItems(String bulkSaleId) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'bulk_sale_id = ?',
      whereArgs: [bulkSaleId],
      orderBy: 'id ASC',
    );
  }

  Future<int> insertDebt(Map<String, dynamic> debt) async {
    final db = await database;
    return await db.insert('debts', debt);
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await database;
    return await db.query('debts', orderBy: 'date DESC');
  }

  Future<int> insertDebtPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.insert('debt_payments', payment);
  }

  Future<int> updateDebt(int id, Map<String, dynamic> debt) async {
    final db = await database;
    return await db.update('debts', debt, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProductsWithRefresh() async {
    final db = await database;
    return await db.query('products', orderBy: 'name ASC');
  }

Future<Map<String, double>> getFinancialReport() async {
  final db = await database;
  
  final purchasesResult = await db.rawQuery('SELECT SUM(total) as total FROM purchases');
  final totalPurchases = purchasesResult.first['total'] as double? ?? 0.0;

  final salesResult = await db.rawQuery('SELECT SUM(total) as total FROM sales');
  final totalSales = salesResult.first['total'] as double? ?? 0.0;

  final debtsResult = await db.rawQuery('SELECT SUM(remaining) as total FROM debts');
  final totalDebts = debtsResult.first['total'] as double? ?? 0.0;

  // 🆕 حیسابکردنی قازانجی راستەقینە (فرۆشتن - کڕین)
  final profitResult = await db.rawQuery('''
    SELECT 
      SUM((s.price - s.buy_price) * s.quantity) as total_profit
    FROM sales s
  ''');
  final profit = profitResult.first['total_profit'] as double? ?? 0.0;

  return {
    'totalPurchases': totalPurchases,
    'totalSales': totalSales,
    'totalDebts': totalDebts,
    'profit': profit, // 🆕 قازانجی راستەقینە
  };
}

  

  Future close() async {
    final db = await database;
    db.close();
  }
}