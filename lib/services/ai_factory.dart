import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'gemini_service.dart';
import 'chatgpt_service.dart';

class AIFactory {
  static bool _hasPdf(List<String> filePaths) =>
      filePaths.any((path) => path.toLowerCase().endsWith('.pdf'));

  /// 🧠 المدير الذكي (Smart Router)
  /// PDF والصور يبدآن عبر Gemini كمسار أساسي، مع ChatGPT كخطة احتياط عند الفشل.
  static AIService _getSmartAgentByFileType(List<String> filePaths) {
    if (filePaths.isEmpty) return GeminiService();

    if (_hasPdf(filePaths)) {
      debugPrint(
        '🧠 مصنع الذكاء: PDF — يستخدم Gemini (دعم PDF الكامل في التطبيق).',
      );
    } else {
      debugPrint(
        '🧠 مصنع الذكاء: صور فقط — يستخدم Gemini كمسار افتراضي؛ ChatGPT احتياط للصور عند الفشل.',
      );
    }
    return GeminiService();
  }

  /// 🛡️ نقطة الإطلاق للمشروع: تنفذ التوجيه الذكي + نظام الطوارئ معاً!
  /// هذه الدالة تناديها من واجهة التطبيق بكل اطمئنان ولا داعي للقيام بشيء آخر.
  static Future<Map<String, dynamic>> executeWithFallback(
    List<String> filePaths, {
    String? targetEmployeeId,
  }) async {
    
    // 1. التوجيه الذكي (اختيار أفضل موظف لهذه المعاملة بالتحديد)
    AIService primaryAgent = _getSmartAgentByFileType(filePaths);

    try {
      // 2. المحاولة الأولى: شغل الذكاء الاصطناعي الأنسب
      return await primaryAgent.processDocument(filePaths, targetEmployeeId: targetEmployeeId);
      
    } catch (e) {
      debugPrint(
        '⚠️ الوكيل الأساسي فشل؛ التحقق من إمكانية الاحتياطي (Fallback)...',
      );

      final AIService backupAgent = primaryAgent is GeminiService
          ? ChatGPTService()
          : GeminiService();

      return await backupAgent.processDocument(
        filePaths,
        targetEmployeeId: targetEmployeeId,
      );
    }
  }

  // دوال إضافية تم الاحتفاظ بها إن أردت الاختيار يدوياً مستقبلاً:
  static AIService getManualService(String agentName) {
    if (agentName == 'chatgpt') return ChatGPTService();
    return GeminiService();
  }
}
