import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/category_model.dart';

class CategoryService {
  static CategoryData? _categoryData;

  /// تحميل التصنيفات من ملف JSON
  static Future<CategoryData> loadCategories() async {
    //اذا  كانت البيانات موجودة رجعها
    if (_categoryData != null) return _categoryData!;

    final String jsonString = await rootBundle.loadString('assets/categories.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);
    _categoryData = CategoryData.fromJson(jsonData);
    return _categoryData!;
  }

  /// الحصول على جميع التصنيفات الرئيسية
  static Future<List<String>> getMainCategories() async {
    final data = await loadCategories();
    return data.categories.map((e) => e.mainCategory).toList();
  }

  /// الحصول على التصنيفات الفرعية بناءً على التصنيف الرئيسي
  static Future<List<String>> getSubCategories(String mainCategory) async {
    final data = await loadCategories();
    final main = data.categories.firstWhere(
      (e) => e.mainCategory == mainCategory,
      orElse: () => throw Exception('التصنيف الرئيسي غير موجود'),
    );
    return main.subCategories.map((e) => e.name).toList();
  }

  /// الحصول على تصنيفات الملف بناءً على التصنيف الرئيسي والفرعي
  static Future<List<String>> getFileClassifications(
    String mainCategory,
    String subCategory,
  ) async {
    final data = await loadCategories();
    final main = data.categories.firstWhere(
      (e) => e.mainCategory == mainCategory,
    );
    final sub = main.subCategories.firstWhere(
      (e) => e.name == subCategory,
    );
    return sub.fileClassifications.map((e) => e.name).toList();
  }

  /// الحصول على الحقول الديناميكية بناءً على جميع الاختيارات
  static Future<List<DynamicField>> getFields(
    String mainCategory,
    String subCategory,
    String fileClassification,
  ) async {
    final data = await loadCategories();
    final main = data.categories.firstWhere(
      (e) => e.mainCategory == mainCategory,
    );
    final sub = main.subCategories.firstWhere(
      (e) => e.name == subCategory,
    );
    final file = sub.fileClassifications.firstWhere(
      (e) => e.name == fileClassification,
    );
    return file.fields;
  }
}
