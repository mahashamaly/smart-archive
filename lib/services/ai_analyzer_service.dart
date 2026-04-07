import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

class AIAnalyzerService {
  // استخدام نفس المفتاح الموجود في GeminiService
  final String _apiKey = 'AIzaSyCg50D6WtafKiyzyJoEfqlgeZSqgVY8AzA';

  Future<String> askAIAboutData(String csvContent, String userQuestion) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: _apiKey,
      );

      final prompt = """
      أنت محلل بيانات خبير في أنظمة الأرشفة لبلدية غزة.
      إليك بيانات المراسلات المستخرجة من ملف CSV:
      ---
      $csvContent
      ---
      المطلوب منك: تحليل هذه البيانات والإجابة على سؤال المستخدم باللغة العربية بأسلوب مهني.
      
      إضافة هامة: إذا كان سؤال المستخدم يتطلب إحصائيات أو مقارنات يمكن رسمها بيانياً (مثل أعداد المراسلات لكل دائرة أو حالة)، 
      فقم بإضافة كتلة كود في نهاية ردك بتنسيق JSON حصراً كالتالي:
      ```json
      {
        "chart_type": "bar", 
        "data": {"الفئة1": 10, "الفئة2": 20}
      }
      ```
      - استخدم "bar" للمقارنات بين الدوائر أو الأنواع (وهو المفضل حالياً).
      - استخدم "pie" للنسب المئوية من المجموع الكلي.
      - اجعل أسماء الفئات قصيرة ومختصرة جداً (كلمتين بحد أقصى). 
      - إذا لم يكن هناك حاجة لرسم بياني، لا تضف كتلة الـ JSON.

      سؤال المستخدم: $userQuestion
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'لم يتم العثور على إجابة دقيقة.';
    } catch (e) {
      return "حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e";
    }
  }
}
