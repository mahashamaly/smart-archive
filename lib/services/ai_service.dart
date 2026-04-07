abstract class AIService {
  /// الواجهة الموحدة لأي مزود ذكاء اصطناعي (Gemini, ChatGPT).
  Future<Map<String, dynamic>> processDocument(
    List<String> filePaths, {
    String? targetEmployeeId,
  });
}
