import 'dart:convert';
import 'dart:io';

class ProcessedDocument {
  final String id;
  final DateTime timestamp;
  final String? mainCategory;
  final String? subCategory;
  final String? fileClassification;
  final List<String> imagePaths;
  final Map<String, String> fieldValues;
  final String status; // 'pending', 'approved', 'archived'

  ProcessedDocument({
    required this.id,
    required this.timestamp,
    this.mainCategory,
    this.subCategory,
    this.fileClassification,
    required this.imagePaths,
    required this.fieldValues,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'mainCategory': mainCategory,
      'subCategory': subCategory,
      'fileClassification': fileClassification,
      'imagePaths': imagePaths,
      'fieldValues': fieldValues,
      'status': status,
    };
  }

  factory ProcessedDocument.fromMap(Map<String, dynamic> map) {
    return ProcessedDocument(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      mainCategory: map['mainCategory'],
      subCategory: map['subCategory'],
      fileClassification: map['fileClassification'],
      imagePaths: List<String>.from(map['imagePaths']),
      fieldValues: Map<String, String>.from(map['fieldValues']),
      status: map['status'] ?? 'pending',
    );
  }
//يحول Object إلى نص JSON جاهز للإرسال أو التخزين.
  String toJson() => json.encode(toMap());

  factory ProcessedDocument.fromJson(String source) =>
      ProcessedDocument.fromMap(json.decode(source));
}
