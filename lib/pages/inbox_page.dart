import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import '../models/processed_document.dart';
import '../services/database_service.dart';
import 'dynamic_archive_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<ProcessedDocument> allDocuments = []; // لتخزين الأصل
  List<ProcessedDocument> filteredDocuments = []; // للعرض المفلتر
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final docs = await DatabaseService.instance.getAllDocuments();
      if (!mounted) return;
      setState(() {
        allDocuments = docs;
        filteredDocuments = docs;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterDocuments(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredDocuments = allDocuments;
      } else {
        filteredDocuments = allDocuments.where((doc) {
          final employeeName = doc.fieldValues['employee_name']?.toLowerCase() ?? '';
          final employeeId = doc.fieldValues['employee_id']?.toLowerCase() ?? '';
          final lowerQuery = query.toLowerCase();
          return employeeName.contains(lowerQuery) || employeeId.contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0096D6),
        elevation: 2,
        title: Text(
          'سجل الأرشفة والتدقيق',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDocuments,
            tooltip: 'تحديث القائمة',
          ),
          IconButton(
            icon: const Icon(Icons.add_a_photo, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DynamicArchivePage()),
              );
              _loadDocuments();
            },
            tooltip: 'مسح مستند جديد',
          ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0096D6)))
          : Column(
              children: [
                _buildStatsBar(),
                
                // شريط البحث الذكي
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: TextField(
                    onChanged: (value) => _filterDocuments(value),
                    style: GoogleFonts.cairo(),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الهوية أو اسم الموظف...',
                      hintStyle: GoogleFonts.cairo(color: Colors.black26),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF0096D6)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredDocuments.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredDocuments.length,
                          itemBuilder: (context, index) {
                            return _buildDocumentCard(index + 1, filteredDocuments[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Colors.black12),
          const SizedBox(height: 16),
          Text(
            'الصندوق فارغ حالياً',
            style: GoogleFonts.cairo(
              color: Colors.black38,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بمسح مستند جديد باستخدام أيقونة الكاميرا',
            style: GoogleFonts.cairo(color: Colors.black26),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    int pendingCount = allDocuments.where((d) => d.status == 'pending').length;
    int reviewedCount = allDocuments.where((d) => d.status == 'reviewed' || d.status == 'archived').length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('إجمالي العمل', '${allDocuments.length}', Colors.blue),
          _buildStatItem('بانتظار التدقيق', '$pendingCount', Colors.orange),
          _buildStatItem('مكتمل', '$reviewedCount', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.cairo(color: Colors.black54, fontSize: 13)),
        Text(value, style: GoogleFonts.cairo(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDocumentCard(int index, ProcessedDocument doc) {
    bool isReviewed = doc.status == 'reviewed' || doc.status == 'archived';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0096D6),
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    doc.fileClassification ?? 'مستند غير مصنف',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                _buildStatusBadge(isReviewed),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: isReviewed ? Icons.visibility : Icons.edit_document,
                  label: isReviewed ? 'عرض البيانات' : 'بدء التدقيق',
                  color: isReviewed ? const Color(0xFF0096D6) : Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DynamicArchivePage(document: doc),
                      ),
                    ).then((_) => _loadDocuments());
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'حذف',
                  color: Colors.redAccent,
                  onTap: () async {
                    final confirm = await _showDeleteConfirmation();
                    if (confirm == true) {
                      await DatabaseService.instance.deleteDocument(doc.id);
                      _loadDocuments();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isReviewed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReviewed ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isReviewed ? 'مـدقق' : 'جاري العمل',
        style: GoogleFonts.cairo(
          color: isReviewed ? Colors.green[700] : Colors.orange[700],
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف المستند', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف هذا المسودة؟ هذه العملية لا يمكن التراجع عنها.', style: GoogleFonts.cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف نهائياً', style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
