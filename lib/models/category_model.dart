class CategoryData {
  final List<MainCategory> categories;

  CategoryData({required this.categories});

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    return CategoryData(
      categories: (json['categories'] as List?)
          ?.map((e) => MainCategory.fromJson(e))
          .toList() ?? [],
    );
  }
}

class MainCategory {
  final String id;
  final String mainCategory;
  final List<SubCategory> subCategories;

  MainCategory({
    required this.id,
    required this.mainCategory,
    required this.subCategories,
  });

  factory MainCategory.fromJson(Map<String, dynamic> json) {
    return MainCategory(
      id: json['id'],
      mainCategory: json['mainCategory'],
      subCategories: (json['subCategories'] as List?)
          ?.map((e) => SubCategory.fromJson(e))
          .toList() ?? [],
    );
  }
}

class SubCategory {
  final String id;
  final String name;
  final List<FileClassification> fileClassifications;

  SubCategory({
    required this.id,
    required this.name,
    required this.fileClassifications,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'],
      name: json['name'],
      fileClassifications: (json['fileClassifications'] as List?)
          ?.map((e) => FileClassification.fromJson(e))
          .toList() ?? [],
    );
  }
}

class FileClassification {
  final String id;
  final String name;
  final List<DynamicField> fields;

  FileClassification({
    required this.id,
    required this.name,
    required this.fields,
  });

  factory FileClassification.fromJson(Map<String, dynamic> json) {
    return FileClassification(
      id: json['id'],
      name: json['name'],
      fields: (json['fields'] as List?)
          ?.map((e) => DynamicField.fromJson(e))
          .toList() ?? [],
    );
  }
}

class DynamicField {
  final String id;
  final String label;
  final String type;
  final bool required;
  final List<String>? options;

  DynamicField({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    this.options,
  });

  factory DynamicField.fromJson(Map<String, dynamic> json) {
    return DynamicField(
      id: json['id'],
      label: json['label'],
      type: json['type'],
      required: json['required'],
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
    );
  }
}
