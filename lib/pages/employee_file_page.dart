import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/processed_document.dart';
import '../services/database_service.dart';
import 'dynamic_archive_page.dart';
import '../services/employee_service.dart';

class EmployeeFilePage extends StatefulWidget {
  final String employeeName;
  final String employeeId;

  const EmployeeFilePage({
    super.key, 
    required this.employeeName, 
    required this.employeeId
  });

  @override
  State<EmployeeFilePage> createState() => _EmployeeFilePageState();
}

class _EmployeeFilePageState extends State<EmployeeFilePage> {
  List<ProcessedDocument> personDocuments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonArchive();
  }
//تحميل أرشيف الموظف
  Future<void> _loadPersonArchive() async {
    final allDocs = await DatabaseService.instance.getAllDocuments();
    
    // دالة لتوحيد النصوص العربية لتسهيل البحث
    String normalize(String text) {
      return text
          .replaceAll('أ', 'ا')
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا')
          .replaceAll('ة', 'ه')
          .replaceAll('ى', 'ي')
          .replaceAll(RegExp(r'\s+'), ' ') // توحيد المسافات
          .trim()
          .toLowerCase();
    }

    final searchName = normalize(widget.employeeName);
    final searchId = widget.employeeId.trim();

    setState(() {
      personDocuments = allDocs.where((doc) {
        // البحث عن الاسم أو الرقم في كافة قيم المستند لضمان ظهور النتائج
        final allValuesCombined = normalize(doc.fieldValues.values.join(' '));
        final docId = doc.fieldValues['employee_id']?.trim() ?? '';
        //شرط البحث
        return allValuesCombined.contains(searchName) || 
               allValuesCombined.contains(searchId) ||
               docId == searchId;
      }).toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0096D6),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الملف الإلكتروني للموظف', style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70)),
            Text(widget.employeeName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : personDocuments.isEmpty 
              ? _buildEmptyArchive()
              : _buildArchiveList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // فتح صفحة الأرشفة مع تمرير بيانات الموظف الحالي تلقائياً
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DynamicArchivePage(
                initialEmployee: Employee(
                  id: widget.employeeId,
                  name: widget.employeeName,
                  department: 'الشؤون الإدارية', // قيمة افتراضية
                ),
              ),
            ),
          );
          
          if (result == true) {
            _loadPersonArchive(); // تحديث القائمة إذا تم حفظ مستند جديد
          }
        },
        backgroundColor: const Color(0xFF0096D6),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: Text('أرشفة لهذا الموظف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyArchive() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 80, color: Colors.black12),
          const SizedBox(height: 16),
          Text('لا يوجد مستندات مؤرشفة لهذا الموظف حالياً', style: GoogleFonts.cairo(color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildArchiveList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: personDocuments.length,
      itemBuilder: (context, index) {
        //الحصول على المستند
        final doc = personDocuments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF0F7FF),
              radius: 16,
              child: Text(
                '${personDocuments.length - index}', // الترقيم التنازلي  .
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0096D6),
                ),
              ),
            ),
            title: Text(
              doc.fileClassification ?? 'نوع ملف غير معروف',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: const Color(0xFF2D3133),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black26),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DynamicArchivePage(document: doc)),
              );
              if (result == true) {
                _loadPersonArchive(); // تحديث القائمة فور الاعتماد
              }
            },
          ),
        );
      },
    );
  }
}
