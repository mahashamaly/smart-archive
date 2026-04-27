import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ai_analyzer_service.dart';

class AIAnalyticsPage extends StatefulWidget {
  @override
  _AIAnalyticsPageState createState() => _AIAnalyticsPageState();
}

class _AIAnalyticsPageState extends State<AIAnalyticsPage> {
  String? fetchedData;
  String? fileName;
  bool isLoading = false;
  final TextEditingController _queryController = TextEditingController();
  final AIAnalyzerService _aiService = AIAnalyzerService();
  String aiResponse = "قم بجلب البيانات من قاعدة بيانات البلدية (Oracle) للبدء في التحليل الذكي.";
  Map<String, dynamic>? powerAiData; 
  String currentChartType = "pie";

  //  جلب البيانات الحقيقية من خادم البلدية 
  Future<void> fetchFromOracle() async {
    setState(() {
      fileName = "جاري جلب البيانات من البلدية...";
      aiResponse = "⏳ جاري الاتصال بخادم البلدية (Oracle)...";
      isLoading = true;
    });

    try {
      final url = Uri.parse('http://localhost:3000/api/apps_2016');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final parsed = json.decode(response.body);
        final dataStr = json.encode(parsed['data']); 
        
        setState(() {
          isLoading = false;
          fetchedData = dataStr; 
          fileName = "بيانات البلدية الحقيقية (Oracle)";
          aiResponse = "✅ تم استيراد (${parsed['count']}) سجل من البلدية بنجاح! الذكاء الاصطناعي جاهز لتحليلها وبناء المخططات.";
          powerAiData = null;
        });
      } else {
        setState(() {
          isLoading = false;
          aiResponse = "❌ فشل الاتصال بالخادم: الكود ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        aiResponse = "❌ حدث خطأ في الاتصال بالخادم الوسيط: يرجى التأكد من تشغيل node server.js\n$e";
      });
    }
  }

//التحقق من وجود الملف والسؤال
  Future<void> sendQuestion() async {
    if (fetchedData == null || _queryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("برجاء تحميل الملف وكتابة السؤال أولاً."))
      );
      return;
    }

    setState(() { 
      isLoading = true; 
      aiResponse = "⏳ جاري تحليل البيانات ورسم المخططات البيانية...";
      powerAiData = null;
    });

    try {
      final fullResponse = await _aiService.askAIAboutData(fetchedData!, _queryController.text);
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
    Map<String, dynamic> combinedData = {
      "executiveSummary": null,
      "charts": [],
      "criticalAnomalies": [],
      "proactiveRecommendations": []
    };

    try {
      bool foundAnyData = false;
      int startIndex = fullResponse.indexOf('{');
      int endIndex = fullResponse.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        String jsonStr = fullResponse.substring(startIndex, endIndex + 1);
        try {
          final Map<String, dynamic> jsonData = json.decode(jsonStr);
          foundAnyData = true;

          // دمج البيانات المستخرجة في الكائن الموحد
          if (jsonData.containsKey('executiveSummary')) {
            combinedData['executiveSummary'] = jsonData['executiveSummary'];
          }
          if (jsonData.containsKey('charts')) {
            combinedData['charts'].addAll(jsonData['charts']);
          }
          if (jsonData.containsKey('criticalAnomalies')) {
            combinedData['criticalAnomalies'].addAll(jsonData['criticalAnomalies']);
          }
          if (jsonData.containsKey('proactiveRecommendations')) {
            combinedData['proactiveRecommendations'].addAll(jsonData['proactiveRecommendations']);
          }
        } catch (e) {
             debugPrint("Error parsing extracted JSON string: $e");
        }
      }

      // 2. تنظيف النص المعروض من كافة كتل الكود والعلامات التقنية
      cleanResponse = fullResponse
          .replaceAll(RegExp(r'```json[\s\S]*?```'), '')
          .replaceAll(RegExp(r'\{[\s\S]*?\}'), '') // أحياناً قد يزيل أجزاء فقط، لكن بما أننا نستخرج ما بين قوسين، لا بأس
          .replaceAll(RegExp(r'#{1,6}\s+'), '') // تنظيف عناوين الماركدون
          .trim();

      if (foundAnyData) {
        setState(() {
          powerAiData = combinedData;
        });
      }
    } catch (e) {
      debugPrint("Error parsing Power AI data: $e");
    }

    setState(() {
      aiResponse = cleanResponse.isEmpty || cleanResponse.length < 5 
          ? (powerAiData != null ? "تم تحليل البيانات بنجاح." : "لم يتم العثور على تحليل.") 
          : cleanResponse;
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
              // الزر المباشر للربط مع قاعدة البيانات
              ElevatedButton.icon(
                onPressed: fetchFromOracle,
                icon: Icon(Icons.cloud_download, color: Colors.white),
                label: Text("استيراد البيانات من البلدية (Oracle)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
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
  //منطقة عرض النتائج

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
                  if (powerAiData != null) _buildPowerAIView(),
                  if (powerAiData == null)
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
        //زر النسخ (Copy Button)
        if (!isLoading && fetchedData != null && aiResponse.length > 30)
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

  Widget _buildPowerAIView() {
    if (powerAiData == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. الملخص التنفيذي - Executive Summary
        if (powerAiData!['executiveSummary'] != null)
          _buildExecutiveSummary(powerAiData!['executiveSummary']),

        // 2. الرسوم البيانية - Dynamic Charts
        if (powerAiData!['charts'] != null)
          ... (powerAiData!['charts'] as List).map((chart) => _buildPowerChart(chart)).toList(),

        // 3. التنبيهات الذكية - Critical Anomalies
        if (powerAiData!['criticalAnomalies'] != null && (powerAiData!['criticalAnomalies'] as List).isNotEmpty)
          _buildAlertsSection("تنبيهات ذكية وتحليل الشذوذ", powerAiData!['criticalAnomalies'], Colors.amber),

        // 4. التوصيات الاستباقية - Proactive Recommendations
        if (powerAiData!['proactiveRecommendations'] != null && (powerAiData!['proactiveRecommendations'] as List).isNotEmpty)
          _buildAlertsSection("توصيات استباقية (Power AI)", powerAiData!['proactiveRecommendations'], Colors.green),

        SizedBox(height: 20),
        // عرض الرد النصي الأصلي إذا وجد
        if (aiResponse.isNotEmpty && aiResponse != "تم تحليل البيانات بنجاح.")
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Text(
              aiResponse,
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.blueGrey[800]),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    );
  }

  Widget _buildExecutiveSummary(String summary) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text("الملخص التنفيذي الذكي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(width: 10),
              Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
            ],
          ),
          SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, height: 1.6),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildPowerChart(Map<String, dynamic> chart) {
    String type = chart['type'] ?? 'bar';
    String title = chart['title'] ?? 'تحليل البيانات';
    List<String> labels = List<String>.from(chart['labels'] ?? []);
    List<dynamic> series = chart['series'] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 25),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blueGrey[900])),
          if (chart['description'] != null)
             Padding(
               padding: const EdgeInsets.only(top: 4, bottom: 15),
               child: Text(chart['description'], style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.right),
             ),
          SizedBox(height: 10),
          if (type == 'bar') _buildAdvancedBarChart(labels, series),
          if (type == 'pie') _buildAdvancedPieChart(labels, series),
          if (type == 'line') _buildAdvancedLineChart(labels, series),
        ],
      ),
    ).animate().fadeIn().scale(begin: Offset(0.9, 0.9));
  }

  Widget _buildAdvancedBarChart(List<String> labels, List<dynamic> series) {
    if (series.isEmpty) return Container();
    final data = series[0]['data'] as List;
    final double maxVal = data.map((e) => (e as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return Column(
      children: List.generate(labels.length, (index) {
        final val = (data[index] as num).toDouble();
        final ratio = maxVal > 0 ? val / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  Text(labels[index], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("${val.toInt()}", style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 6),
              Stack(
                children: [
                  Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5))),
                  AnimatedContainer(
                    duration: 1000.ms,
                    height: 8,
                    width: (MediaQuery.of(context).size.width - 100) * ratio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blueAccent, Colors.blue[300]!]),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAdvancedPieChart(List<String> labels, List<dynamic> series) {
     if (series.isEmpty) return Container();
     final data = series[0]['data'] as List;
     final colors = [Colors.blue, Colors.cyan, Colors.indigo, Colors.orange, Colors.pink];

     return Column(
       children: [
         SizedBox(
           height: 200,
           child: PieChart(
             PieChartData(
               sections: List.generate(labels.length, (i) => PieChartSectionData(
                 value: (data[i] as num).toDouble(),
                 color: colors[i % colors.length],
                 radius: 40,
                 title: "",
               )),
             ),
           ),
         ),
         SizedBox(height: 20),
         Wrap(
           spacing: 15,
           runSpacing: 10,
           alignment: WrapAlignment.end,
           children: List.generate(labels.length, (i) => Row(
             mainAxisSize: MainAxisSize.min,
             textDirection: TextDirection.rtl,
             children: [
               Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
               SizedBox(width: 5),
               Text(labels[i], style: TextStyle(fontSize: 11)),
             ],
           )),
         )
       ],
     );
  }

  Widget _buildAdvancedLineChart(List<String> labels, List<dynamic> series) {
    if (series.isEmpty || labels.isEmpty) {
      return Container(
        height: 150,
        child: Center(child: Text("لا توجد بيانات كافية للرسم", style: TextStyle(color: Colors.grey))),
      );
    }

    // ألوان المسارات
    final List<Color> lineColors = [
      Colors.blueAccent,
      Colors.orange,
      Colors.green,
      Colors.pink,
      Colors.purple,
    ];

    // بناء LineBarsData لكل series
    final List<LineChartBarData> lineBars = [];
    for (int s = 0; s < series.length; s++) {
      final rawData = series[s]['data'] as List? ?? [];
      final color = lineColors[s % lineColors.length];
      final spots = <FlSpot>[];
      for (int i = 0; i < rawData.length && i < labels.length; i++) {
        spots.add(FlSpot(i.toDouble(), (rawData[i] as num).toDouble()));
      }
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 4,
            color: Colors.white,
            strokeWidth: 2,
            strokeColor: color,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.08),
        ),
      ));
    }

    // حساب القيمة القصوى لمحور Y
    double maxY = 0;
    for (final bar in lineBars) {
      for (final spot in bar.spots) {
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    final double yInterval = maxY > 0 ? (maxY / 5).ceilToDouble() : 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= labels.length) return const SizedBox();
                      // عرض تسميات مختصرة إذا كانت كثيرة
                      final label = labels.length > 8
                          ? labels[idx].replaceAll(RegExp(r'[^\d]+'), '') // أرقام فقط
                          : labels[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: lineBars,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.blueGrey[800]!,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                    final label = spot.x.toInt() < labels.length ? labels[spot.x.toInt()] : '';
                    return LineTooltipItem(
                      '$label\n${spot.y.toInt()}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // مفتاح الألوان (Legend)
        if (series.length > 1) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: List.generate(series.length, (i) {
              final name = series[i]['name']?.toString() ?? 'مسار ${i + 1}';
              final color = lineColors[i % lineColors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 24, height: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(name, style: TextStyle(fontSize: 11, color: Colors.blueGrey[700])),
                ],
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertsSection(String title, List<dynamic> alerts, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 10),
            child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.withOpacity(0.8))),
          ),
          ...alerts.map((alert) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(color == Colors.amber ? Icons.warning_amber_rounded : Icons.lightbulb_outline, color: color, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text(alert.toString(), style: TextStyle(fontSize: 13, height: 1.5), textAlign: TextAlign.right)),
              ],
            ),
          )).toList(),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }
}
