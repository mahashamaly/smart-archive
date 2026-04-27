import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ai_prompt_bank.dart';

class AIAnalyzerService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _openAiApiKey = dotenv.env['CHATGPT_API_KEY'] ?? '';
  static Future<void> _requestQueue = Future.value();

  Future<String> askAIAboutData(String fetchedData, String userQuestion) async {
    // تسلسل الطلبات يمنع إطلاق عدة طلبات Power AI بالتوازي لنفس المفتاح.
    final task = _requestQueue.then(
      (_) => _runPowerAIRequest(fetchedData, userQuestion),
    );
    _requestQueue = task.then((_) {}, onError: (_) {});
    return task;
  }

  Future<String> _runPowerAIRequest(
    String fetchedData,
    String userQuestion,
  ) async {
    int retryCount = 0;
    const int maxRetries = 4;
    const models = <String>[
      'gemini-2.5-flash',
    ];
//حلقة المحاولة
    while (retryCount < maxRetries) {
      try {
        final modelName = models[
            retryCount < models.length ? retryCount : (models.length - 1)];

        final model = GenerativeModel(
          model: modelName,
          apiKey: _apiKey,
        );

        final prompt = AIPromptBank.getPowerAIPrompt(fetchedData, userQuestion);
        final response = await model.generateContent([Content.text(prompt)]);
        
        if (response.text != null) return response.text!;
        throw Exception("Empty response");
        
      } catch (e) {
        retryCount++;
        if (_isRetryableGeminiError(e) && retryCount < maxRetries) {
          final waitSeconds = _getBackoffDelaySeconds(e, retryCount);
          debugPrint(
            "🔄 Gemini مشغول/مقيّد مؤقتاً — إعادة المحاولة $retryCount من $maxRetries بعد $waitSeconds ث.",
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        // إذا كانت مشكلة زحمة/كوتا، جرّب المزود الاحتياطي بدل إسقاط Power AI.
        if (_isRetryableGeminiError(e)) {
          debugPrint('🛟 التحويل إلى ChatGPT كخطة احتياط لـ Power AI...');
          try {
            return await _askChatGptAboutData(fetchedData, userQuestion);
          } catch (fallbackError) {
            return "حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e\n\nوفشل الاحتياطي أيضاً: $fallbackError";
          }
        }
        return "حدث خطأ أثناء الاتصال بالذكاء الاصطناعي: $e";
      }
    }
    return "السيرفر مشغول حالياً، يرجى المحاولة بعد قليل.";
  }

  bool _isRetryableGeminiError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('503') ||
        message.contains('429') ||
        message.contains('quota exceeded') ||
        message.contains('rate limit') ||
        message.contains('unavailable') ||
        message.contains('high demand');
  }

  int _getBackoffDelaySeconds(Object error, int retryCount) {
    final retryAfter = _extractRetryAfterSeconds(error.toString());
    if (retryAfter != null) return retryAfter;

    final fallback = retryCount * 6;
    if (fallback < 6) return 6;
    if (fallback > 30) return 30;
    return fallback;
  }

  int? _extractRetryAfterSeconds(String rawError) {
    final match = RegExp(
      r'retry in\s+([0-9]+(?:\.[0-9]+)?)s',
      caseSensitive: false,
    ).firstMatch(rawError);
    if (match == null) return null;

    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;

    final rounded = value.ceil() + 1;
    if (rounded < 5) return 5;
    if (rounded > 120) return 120;
    return rounded;
  }

  Future<String> _askChatGptAboutData(String fetchedData, String userQuestion) async {
    final prompt = AIPromptBank.getPowerAIPrompt(fetchedData, userQuestion);

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAiApiKey',
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": prompt,
              }
            ]
          }
        ],
        "temperature": 0.0,
        "max_tokens": 1500,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('فشل الطلب مع ChatGPT: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final content = data['choices']?[0]?['message']?['content']?.toString();
    if (content == null || content.trim().isEmpty) {
      throw Exception('ChatGPT returned empty content');
    }
    return content;
  }
}
