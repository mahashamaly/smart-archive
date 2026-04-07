import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_service.dart';
import 'ai_prompt_bank.dart';

class GeminiService implements AIService {
  // 🔑 مفتاح API
  final String _apiKey = 'AIzaSyCg50D6WtafKiyzyJoEfqlgeZSqgVY8AzA';

  /// الدالة الرئيسية لمعالجة المستند (طلب واحد يجمع التصنيف والاستخراج)
  @override
  Future<Map<String, dynamic>> processDocument(
    List<String> filePaths, {
    String? targetEmployeeId,
  }) async {
    try {
      debugPrint("📡 إرسال طلب واحد للتصنيف والاستخراج معاً...");
      return await _classifyAndExtract(
        filePaths,
        targetEmployeeId: targetEmployeeId,
      );
    } catch (e) {
      debugPrint("⛔ GeminiService Error: $e");
      rethrow;
    }
  }

  /// طلب واحد يجمع التصنيف والاستخراج معاً
  Future<Map<String, dynamic>> _classifyAndExtract(
    List<String> filePaths, {
    String? targetEmployeeId,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.0, // 👈 0.0 يعني لا مجال للإبداع، فقط التزم بالنص حرفياً
        topK: 1, // 👈 اختر دائماً الإجابة الأكثر احتمالاً والأكثر صرامة
        topP: 0.1, // 👈 التركيز فقط على الكلمات المباشرة الموجودة في المستند
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    // 1. جلب البرومبت الأساسي من البنك المركزي بدلاً من كتابته هنا!
    final basePrompt = AIPromptBank.getBasePrompt(targetEmployeeId: targetEmployeeId);

    // 2. تجهيز القائمة التي تحتوي على البرومبت والملفات
    final parts = <Part>[];
    parts.add(TextPart(basePrompt));

    // 3. تجهيز الملفات (ضغط الصور أو إضافة الـ PDF)
    for (var path in filePaths) {
      if (path.toLowerCase().endsWith('.pdf')) {
        final pdfBytes = await XFile(path).readAsBytes();
        parts.add(DataPart('application/pdf', pdfBytes));
        debugPrint("📄 تمت إضافة ملف PDF: $path");
      } else {
        final compressed = await _compressImage(path);
        parts.add(DataPart('image/jpeg', compressed));
      }
    }

    // 4. إرسال الطلب الى نموذج الجيمناي
    final response = await model.generateContent([Content.multi(parts)]);
    debugPrint("✅ استُلم الرد من الـ API بنجاح");
    
    // 5. تنظيف الرد المستلم من أي نصوص زائدة واستخراج الـ JSON
    final jsonStr = _cleanJsonResponse(response.text ?? '{}');
    return jsonDecode(jsonStr);
  }

  /// ضغط الصورة قبل إرسالها للـ API لتسريع الاستجابة
  Future<Uint8List> _compressImage(String imagePath) async {
    final originalBytes = await XFile(imagePath).readAsBytes();
    final originalSizeKB = originalBytes.lengthInBytes ~/ 1024;

    debugPrint("🖼️ ضغط الصورة: ($originalSizeKB KB)");

    try {
      if (kIsWeb) return originalBytes; // تجاوز الضغط على الويب لمنع انهيار المكتبة

      final compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      // إذا حدث خطأ ولم يتم ضغط الصورة → نرجع النسخة الأصلية بدون ضغط.
      if (compressed == null || compressed.isEmpty) {
        debugPrint("⚠️ فشل الضغط، سيتم إرسال الصورة الأصلية.");
        return originalBytes;
      }
      
      final compressedSizeKB = compressed.lengthInBytes ~/ 1024;
      final savings = originalSizeKB - compressedSizeKB;
      debugPrint("✅ بعد الضغط: $compressedSizeKB KB (وفّرنا $savings KB)");

      return compressed;
    } catch (e) {
      debugPrint("⚠️ الضغط غير مدعوم على هذه المنصة أو فشل ($e)، سيتم إرسال الصورة الأصلية.");
      return originalBytes;
    }
  }

  /// دالة لتنظيف الـ JSON
  String _cleanJsonResponse(String text) {
    if (text.contains('{')) {
      int start = text.indexOf('{');
      int end = text.lastIndexOf('}') + 1;
      return text.substring(start, end);
    }
    return '{}';
  }

  /// دالة احتياطية للحقول الديناميكية
  Future<Map<String, String>> processDocumentWithFields(
    String imagePath,
    List<dynamic> fields,
  ) async {
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
    final imageBytes = await File(imagePath).readAsBytes();
    final fieldDescriptions = fields
        .map((f) => "- ${f.id}: ${f.label}")
        .join('\n');
    final prompt = [
      Content.text("استخرج JSON فقط لهذه الحقول:\n$fieldDescriptions"),
      Content.data('image/jpeg', imageBytes),
    ];
    final response = await model.generateContent(prompt);
    final text = _cleanJsonResponse(response.text ?? '{}');
    final Map<String, dynamic> data = jsonDecode(text);
    Map<String, String> result = {};
    for (var f in fields) result[f.id] = data[f.id]?.toString() ?? 'غير متوفر';
    return result;
  }
}