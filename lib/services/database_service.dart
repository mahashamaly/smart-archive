import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import '../models/processed_document.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('documents.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      return await databaseFactoryFfiWeb.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    //لتسهيل إعادة الاستخدام والتعديل لاحقًا.
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    
    await db.execute('''
CREATE TABLE documents (
  id $idType,
  timestamp $textType,
  mainCategory $textTypeNull,
  subCategory $textTypeNull,
  fileClassification $textTypeNull,
  imagePaths $textType,
  fieldValues $textType,
  status $textType
)
''');
  }

  Future<void> saveDocument(ProcessedDocument doc) async {
    final db = await instance.database;
    
    final docMap = doc.toMap();
    // تحويل القوائم إلى نصوص ليتم حفظها في قاعدة البيانات
    docMap['imagePaths'] = json.encode(doc.imagePaths);
    docMap['fieldValues'] = json.encode(doc.fieldValues);
    docMap['timestamp'] = doc.timestamp.toIso8601String();

    await db.insert('documents', docMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProcessedDocument>> getAllDocuments() async {
    final db = await instance.database;
    final result = await db.query('documents', orderBy: 'timestamp DESC');

    return result.map((jsonMap) {
      final map = Map<String, dynamic>.from(jsonMap);
      map['imagePaths'] = json.decode(map['imagePaths'] as String).cast<String>();
      map['fieldValues'] = Map<String, String>.from(json.decode(map['fieldValues'] as String));
     //تحويل الماب ل اوبجكت
      return ProcessedDocument.fromMap(map);
    }).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await instance.database;
    await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDocumentStatus(String id, String status) async {
    final db = await instance.database;
    await db.update(
      'documents',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
