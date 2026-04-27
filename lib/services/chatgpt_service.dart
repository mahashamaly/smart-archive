import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai_service.dart';
import 'ai_prompt_bank.dart';

class ChatGPTService implements AIService {
  // المفتاح الذي قمتي بلصقه
  final String _apiKey = dotenv.env['CHATGPT_API_KEY'] ?? ''; 

  @override
  //استقبال الملفات
  Future<Map<String, dynamic>> processDocument(
    List<String> filePaths, {
    String? targetEmployeeId,
  }) async {
    try {
      debugPrint("🤖 جاري إرسال المستند إلى ChatGPT 4o-mini...");

      // 1. جلب البرومبت الأساسي من البنك المركزي المشترك بين جميع الموديلات
      String basePrompt = AIPromptBank.getBasePrompt(targetEmployeeId: targetEmployeeId);

      // 2. الكلمة السحرية لترويض ChatGPT (الرد فقط بجيسون)
      String chatGptStrictInstruction = """
      
      تنبيه صارم جداً (إعدادات الـ API): 
      أنت تعمل كخادم واجهة برمجية للبيانات.
      عليك إرجاع النص بصيغة JSON صافي وقم ببدء الرد برمز `{` مباشرة وانتهي برمز `}`.
      ممنوع منعاً باتاً كتابة أي كلمة ترحيبية، أو أي شرح، أو استخدام علامات Markdown مثل ```json.
      """;
//دمج البرومبت الأساسي مع التعليمة الصارمة
      final finalPrompt = '$basePrompt\n$chatGptStrictInstruction';

      // 3. تجهيز محتوى الرسالة (النص + الصور المشفرة)
      List<Map<String, dynamic>> messagesContent = [
        {
          "type": "text", 
          "text": finalPrompt
        }
      ];
//يحول كل صفحة PDF إلى صورة JPEG
//يشفر الصورة إلى Base64 → لكي يستطيع ChatGPT قراءتها كصورة
      for (var path in filePaths) {
        if (path.toLowerCase().endsWith('.pdf')) {
          final pdfImages = await _convertPdfToJpegPages(path);
          //تشفير الصور إلى Base64
          for (final pageBytes in pdfImages) {
            final base64Page = base64Encode(pageBytes);
            messagesContent.add({
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Page"},
            });
          }
          continue;
        }

        // ضغط الصورة وتحويلها لـ Base64 لكي يستطيع ChatGPT قراءتها
        final compressedBytes = await _compressImage(path);
        final base64Image = base64Encode(compressedBytes);

        messagesContent.add({
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,$base64Image"
          }
        });
      }

      // 4. إعداد وإرسال الطلب عبر بروتوكول HTTP
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", // الموديل الذكي والسريع من OpenAI
          "messages": [
            {
              "role": "user",
              "content": messagesContent
            }
          ],
          "max_tokens": 1500, // أقصى حد للكلمات العائدة
          "temperature": 0.0 // صفر ليأتيك الرد دقيقاً جداً وصارماً
        }),
      );

      if (response.statusCode == 200) {
        // 5. استلام الرد وتنظيفه
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        final contentText = responseData['choices'][0]['message']['content'];
        
        debugPrint("✅ تم الاستلام بنجاح من ChatGPT!");
        final cleanJson = _cleanJsonResponse(contentText);
        return jsonDecode(cleanJson);
      } else {
        throw Exception('فشل الطلب مع ChatGPT: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("⛔ خطأ في ChatGPTService: $e");
      rethrow;
    }
  }

  // ---------------- الدوال المساعدة ----------------

  Future<Uint8List> _compressImage(String imagePath) async {
    final originalBytes = await File(imagePath).readAsBytes();
    if (kIsWeb) return originalBytes;
    
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        originalBytes, 
        minWidth: 1024, 
        minHeight: 1024, 
        quality: 75, 
        format: CompressFormat.jpeg,
      );
      return (compressed.isEmpty) ? originalBytes : compressed;
    } catch (e) {
      return originalBytes; // إذا فشل الضغط، أرسل الصورة بأصلها
    }
  }
//الدالة تحول ملف PDF إلى قائمة من الصور بصيغة JPEG
  Future<List<Uint8List>> _convertPdfToJpegPages(String pdfPath) async {
    const int maxPages = 10;
    final images = <Uint8List>[];
    final document = await PdfDocument.openFile(pdfPath);
//تحديد عدد الصفحات التي سنعالجها
    try {
      final pageCount = document.pagesCount > maxPages
          ? maxPages
          : document.pagesCount;
//المرور على كل صفحة PDF
      for (var i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        //تحويل الصفحة إلى صورة
        try {
          final rendered = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
//استخراج البايتات وإضافتها للقائمة
          final bytes = rendered?.bytes;
          if (bytes != null && bytes.isNotEmpty) {
            images.add(bytes);
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    if (images.isEmpty) {
      throw Exception('تعذر تحويل PDF إلى صور للإرسال إلى ChatGPT.');
    }
    return images;
  }

  String _cleanJsonResponse(String text) {
    if (text.contains('{')) {
      int start = text.indexOf('{');
      int end = text.lastIndexOf('}') + 1;
      return text.substring(start, end);
    }
    return '{}';
  }
}
