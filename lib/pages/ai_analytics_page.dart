import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ai_analyzer_service.dart';

class AIAnalyticsPage extends StatefulWidget {
  @override
  _AIAnalyticsPageState createState() => _AIAnalyticsPageState();
}

class _AIAnalyticsPageState extends State<AIAnalyticsPage> {
  String? csvContent;
  String? fileName;
  bool isLoading = false;
  final TextEditingController _queryController = TextEditingController();
  final AIAnalyzerService _aiService = AIAnalyzerService();
  String aiResponse = "قم بتحميل ملف المراسلات (CSV) ثم اسأل الذكاء الاصطناعي أي سؤال حوله.";
  Map<String, double>? chartData;
  String currentChartType = "pie";
//تحميل الملف csv
  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final bytes = result.files.single.bytes;
        
        if (bytes != null) {
          csvContent = utf8.decode(bytes);
        } else {
          final file = File(result.files.single.path!);
          csvContent = await file.readAsString();
        }

        setState(() {
          fileName = result.files.single.name;
          aiResponse = "✅ تم تحميل ملف ($fileName) بنجاح. الآن اسأل الذكاء الاصطناعي عن البيانات.";
          chartData = null;
        });
      }
    } catch (e) {
      setState(() {
        aiResponse = "❌ حدث خطأ أثناء تحميل الملف: $e";
      });
    }
  }
//التحقق من وجود الملف والسؤال
  Future<void> sendQuestion() async {
    if (csvContent == null || _queryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("برجاء تحميل الملف وكتابة السؤال أولاً."))
      );
      return;
    }

    setState(() { 
      isLoading = true; 
      aiResponse = "⏳ جاري تحليل البيانات ورسم المخططات البيانية...";
      chartData = null;
    });

    try {
      final fullResponse = await _aiService.askAIAboutData(csvContent!, _queryController.text);
      _parseResponse(fullResponse);
    } catch (e) {
      setState(() {
        aiResponse = "❌ حدث خطأ: $e";
        isLoading = false;
      });
    }
  }

  void _parseResponse(String fullResponse) {
    String cleanResponse = fullResponse;
    Map<String, double>? extractedData;
    String extractedType = "pie";

    try {
      final jsonRegex = RegExp(r'```json\s*(\{[\s\S]*?\}|\[[\s\S]*?\])\s*```');
      final match = jsonRegex.firstMatch(fullResponse);
      
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final jsonData = json.decode(jsonStr);
          if (jsonData['data'] != null) {
            extractedData = (jsonData['data'] as Map).map(
              (key, value) => MapEntry(key.toString(), (value as num).toDouble())
            );
            extractedType = jsonData['chart_type'] ?? "pie";
            cleanResponse = fullResponse.replaceFirst(match.group(0)!, '').trim();
          }
        }
      }
    } catch (e) {
      debugPrint("Error parsing chart data: $e");
    }

    setState(() {
      aiResponse = cleanResponse.isEmpty ? "تم تحليل البيانات بنجاح." : cleanResponse;
      chartData = extractedData;
      currentChartType = extractedType;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("المحلل الذكي للمراسلات", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildUploadCard(),
            SizedBox(height: 20),
            _buildSearchBox(),
            SizedBox(height: 20),
            Expanded(child: _buildResponseArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_rounded, size: 50, color: Colors.blueAccent),
          SizedBox(height: 10),
          Text(
            fileName ?? "لم يتم تحميل ملف بعد",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: pickFile,
            icon: Icon(Icons.file_upload_outlined, color: Colors.white,),
            label: Text("تحميل ملف المراسلات (CSV)", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildSearchBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: "مثلاً: ما هي أكثر أنواع المراسلات تداولاً؟",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
            SizedBox(width: 10),
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.send_rounded, color: Colors.white),
                onPressed: sendQuestion,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _buildQuickSuggestions(),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildQuickSuggestions() {
    final List<String> suggestions = [
      "ملخص عام للملف",
      "أكثر المراسلات تداولاً",
      "أكثر 3 دوائر نشاطاً",
      "حالة المراسلات العاجلة",
      "توزيع المراسلات حسب"
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: suggestions.map((suggestion) {
        return ActionChip(
          label: Text(
            suggestion,
            style: TextStyle(fontSize: 12, color: Colors.blueAccent[700]),
          ),
          backgroundColor: Colors.blue[50],
          side: BorderSide(color: Colors.blueAccent.withOpacity(0.1)),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          onPressed: () {
            _queryController.text = suggestion;
            sendQuestion();
          },
        );
      }).toList(),
    );
  }

  Widget _buildResponseArea() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isLoading)
                  _buildLoadingView()
                else ...[
                  if (chartData != null) _buildChartViewer(),
                  Text(
                    aiResponse,
                    style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isLoading && csvContent != null && aiResponse.length > 30)
          Positioned(
            left: 10,
            top: 10,
            child: IconButton(
              icon: Icon(Icons.copy_rounded, color: Colors.blueAccent),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: aiResponse));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تم نسخ الإجابة إلى الحافظة")),
                );
              },
              tooltip: "نسخ الإجابة",
            ),
          ),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 50),
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("المحلل الذكي يقرأ بياناتك ويستنتج الإجابة...", style: TextStyle(color: Colors.grey[600]))
        ],
      ),
    );
  }

  Widget _buildChartViewer() {
    final total = chartData!.values.isNotEmpty ? chartData!.values.reduce((a, b) => a + b) : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    "تحليل بياني ذكي",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey[900]),
                  ),
                   Text(
                    "المجموع الإجمالي: ${total.toInt()} سجلات",
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 16, color: Colors.blueAccent),
                    SizedBox(width: 4),
                    Text(
                      currentChartType == "bar" ? "مخطط أعمدة" : "مخطط دائري",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          _buildQuickStatsCards(),
          SizedBox(height: 25),
          SizedBox(
            child: currentChartType == "bar" ? _buildBarChart() : SizedBox(height: 220, child: _buildPieChart()),
          ),
          if (currentChartType == "pie") ...[
            SizedBox(height: 30),
            _buildChartLegend(total.toDouble()),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: Offset(0.95, 0.95));
  }

  Widget _buildQuickStatsCards() {
    if (chartData == null || chartData!.isEmpty) return Container();
    
    final sortedData = chartData!.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final highest = sortedData.first;
    final lowest = sortedData.last;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          _buildMiniStatCard(
            "الأكثر نشاطاً",
            highest.key,
            Icons.trending_up_rounded,
            Colors.green,
          ),
          SizedBox(width: 12),
          _buildMiniStatCard(
            "الأقل نشاطاً",
            lowest.key,
            Icons.trending_down_rounded,
            Colors.orange,
          ),
          SizedBox(width: 12),
          _buildMiniStatCard(
            "عدد الفئات",
            "${chartData!.length} دوائر",
            Icons.grid_view_rounded,
            Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxVal = chartData!.values.reduce((a, b) => a > b ? a : b);
    final colors = [
      [Color(0xFF2196F3), Color(0xFF64B5F6)],
      [Color(0xFF009688), Color(0xFF4DB6AC)],
      [Color(0xFF673AB7), Color(0xFF9575CD)],
      [Color(0xFFFF9800), Color(0xFFFFB74D)],
      [Color(0xFFE91E63), Color(0xFFF06292)],
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: chartData!.length,
      itemBuilder: (context, index) {
        final entry = chartData!.entries.elementAt(index);
        final gradient = colors[index % colors.length];
        final ratio = entry.value / maxVal;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[800]),
                  ),
                  Text(
                    "${entry.value.toInt()} سجل",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: gradient[0]),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 800 + (index * 200)),
                    curve: Curves.easeOutQuart,
                    height: 12,
                    width: (MediaQuery.of(context).size.width - 80) * ratio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradient),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart() {
    final total = chartData!.values.reduce((a, b) => a + b);
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 65,
            sections: _generatePieSections(),
            pieTouchData: PieTouchData(enabled: true),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "الإجمالي",
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            Text(
              "${total.toInt()}",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent[700]),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _generatePieSections() {
    final colors = [
      Color(0xFF2196F3), // Blue
      Color(0xFF00BCD4), // Cyan
      Color(0xFF009688), // Teal
      Color(0xFF673AB7), // Deep Purple
      Color(0xFFFF9800), // Orange
    ];

    return chartData!.entries.indexed.map((entry) {
      final index = entry.$1;
      final e = entry.$2;
      final color = colors[index % colors.length];
      
      return PieChartSectionData(
        color: color,
        value: e.value,
        title: "", // Title hidden for cleaner look, value is in center/legend
        radius: 20,
        showTitle: false,
      );
    }).toList();
  }

  Widget _buildBadge(int index, Color color) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(Icons.circle, color: color, size: 8),
    );
  }

  Widget _buildChartLegend(double total) {
    final colors = [
      Color(0xFF2196F3),
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF673AB7),
      Color(0xFFFF9800),
    ];

    return Column(
      children: chartData!.entries.indexed.map((entry) {
        final index = entry.$1;
        final e = entry.$2;
        final color = colors[index % colors.length];
        final percentage = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : "0";
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)]
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Text(
                  e.key,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
                  textAlign: TextAlign.right,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${e.value.toInt()} مراسلة",
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "$percentage%",
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

}
