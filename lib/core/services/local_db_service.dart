import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/products/data/models/product_model.dart';
import '../../features/products/data/models/product_unit_model.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'NCH POS_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Master Data Tables
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        sku TEXT,
        category_id TEXT,
        brand_id TEXT,
        base_unit_id TEXT,
        name TEXT NOT NULL,
        barcode TEXT,
        selling_price_base REAL NOT NULL,
        cost_price REAL,
        base_stock_quantity INTEGER NOT NULL,
        reorder_level_base INTEGER NOT NULL,
        attributes TEXT,
        image_url TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        category_name TEXT,
        brand_name TEXT,
        base_unit_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE product_units (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        unit_id TEXT NOT NULL,
        base_quantity_multiplier INTEGER NOT NULL,
        barcode TEXT,
        selling_price REAL NOT NULL,
        is_default_sales_unit INTEGER NOT NULL,
        is_default_purchase_unit INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        unit_name TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // 2. Offline Queue
    await db.execute('''
      CREATE TABLE offline_sales_queue (
        id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Pending',
        error_message TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ==========================================
  // Master Data Downsync Methods
  // ==========================================

  Future<void> clearAndInsertProducts(List<ProductModel> products) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');
      for (var p in products) {
        await txn.insert('products', {
          'id': p.id,
          'sku': p.sku,
          'category_id': p.categoryId,
          'brand_id': p.brandId,
          'base_unit_id': p.baseUnitId,
          'name': p.name,
          'barcode': p.barcode,
          'selling_price_base': p.sellingPriceBase,
          'cost_price': p.costPrice,
          'base_stock_quantity': p.baseStockQuantity,
          'reorder_level_base': p.reorderLevelBase,
          'attributes': jsonEncode(p.attributes),
          'image_url': p.imageUrl,
          'status': p.status,
          'created_at': p.createdAt.toIso8601String(),
          'updated_at': p.updatedAt.toIso8601String(),
          'category_name': p.categoryName,
          'brand_name': p.brandName,
          'base_unit_name': p.baseUnitName,
        });
      }
    });
  }

  Future<void> clearAndInsertProductUnits(List<ProductUnitModel> units) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('product_units');
      for (var u in units) {
        await txn.insert('product_units', {
          'id': u.id,
          'product_id': u.productId,
          'unit_id': u.unitId,
          'base_quantity_multiplier': u.baseQuantityMultiplier,
          'barcode': u.barcode,
          'selling_price': u.sellingPrice,
          'is_default_sales_unit': u.isDefaultSalesUnit ? 1 : 0,
          'is_default_purchase_unit': u.isDefaultPurchaseUnit ? 1 : 0,
          'is_active': u.isActive ? 1 : 0,
          'created_at': u.createdAt.toIso8601String(),
          'updated_at': u.updatedAt.toIso8601String(),
          'unit_name': u.unitName,
        });
      }
    });
  }

  // ==========================================
  // Offline Master Data Queries
  // ==========================================

  Future<List<ProductModel>> searchLocalProducts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'status = ? AND (name LIKE ? OR barcode LIKE ? OR sku LIKE ?)',
      whereArgs: ['Active', '%\$query%', '%\$query%', '%\$query%'],
      limit: 20,
    );

    return maps.map((e) => ProductModel(
      id: e['id'] as String,
      sku: e['sku'] as String,
      categoryId: e['category_id'] as String?,
      brandId: e['brand_id'] as String?,
      baseUnitId: e['base_unit_id'] as String?,
      name: e['name'] as String,
      barcode: e['barcode'] as String?,
      sellingPriceBase: e['selling_price_base'] as double,
      costPrice: e['cost_price'] as double?,
      baseStockQuantity: e['base_stock_quantity'] as int,
      reorderLevelBase: e['reorder_level_base'] as int,
      attributes: e['attributes'] != null ? jsonDecode(e['attributes'] as String) : {},
      imageUrl: e['image_url'] as String?,
      status: e['status'] as String,
      createdAt: DateTime.parse(e['created_at'] as String),
      updatedAt: DateTime.parse(e['updated_at'] as String),
      categoryName: e['category_name'] as String?,
      brandName: e['brand_name'] as String?,
      baseUnitName: e['base_unit_name'] as String?,
    )).toList();
  }

  Future<List<ProductUnitModel>> getLocalProductUnits(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'product_units',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [productId],
      orderBy: 'base_quantity_multiplier ASC',
    );

    return maps.map((e) => ProductUnitModel(
      id: e['id'] as String,
      productId: e['product_id'] as String,
      unitId: e['unit_id'] as String,
      baseQuantityMultiplier: e['base_quantity_multiplier'] as int,
      barcode: e['barcode'] as String?,
      sellingPrice: e['selling_price'] as double,
      isDefaultSalesUnit: e['is_default_sales_unit'] == 1,
      isDefaultPurchaseUnit: e['is_default_purchase_unit'] == 1,
      isActive: e['is_active'] == 1,
      createdAt: DateTime.parse(e['created_at'] as String),
      updatedAt: DateTime.parse(e['updated_at'] as String),
      unitName: e['unit_name'] as String?,
    )).toList();
  }

  // ==========================================
  // Offline Queue Upsync
  // ==========================================

  Future<void> enqueueSale(String saleId, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('offline_sales_queue', {
      'id': saleId,
      'payload': jsonEncode(payload),
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final db = await database;
    return await db.query(
      'offline_sales_queue',
      where: 'status = ?',
      whereArgs: ['Pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateQueueStatus(String id, String status, {String? errorMessage}) async {
    final db = await database;
    await db.update(
      'offline_sales_queue',
      {'status': status, 'error_message': errorMessage},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFromQueue(String id) async {
    final db = await database;
    await db.delete('offline_sales_queue', where: 'id = ?', whereArgs: [id]);
  }
}
