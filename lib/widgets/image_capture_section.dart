import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io; // استخدام alias للمنصات الأخرى

class ImageCaptureSection extends StatefulWidget {
  final List<XFile> selectedImages;
  final bool isProcessing;
  final Function(ImageSource) onImagePicked;
  final VoidCallback onDocumentPicked;
  final Function(int) onImageRemoved;
  final VoidCallback? onStartScan;
  final bool miniMode;

  const ImageCaptureSection({
    super.key,
    required this.selectedImages,
    required this.isProcessing,
    required this.onImagePicked,
    required this.onDocumentPicked,
    required this.onImageRemoved,
    this.onStartScan,
    this.miniMode = false,
  });

  @override
  State<ImageCaptureSection> createState() => _ImageCaptureSectionState();
}

class _ImageCaptureSectionState extends State<ImageCaptureSection> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void didUpdateWidget(ImageCaptureSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImages.length > oldWidget.selectedImages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            widget.selectedImages.length - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(XFile file) {
    if (kIsWeb) {
      return NetworkImage(file.path);
    } else {
      return FileImage(io.File(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.miniMode ? const EdgeInsets.all(12) : const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: Column(
        children: [
          if (!widget.miniMode) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, color: Color(0xFF0096D6), size: 28),
                const SizedBox(width: 12),
                Text(
                  'صور المستند',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يمكنك إضافة عدة صفحات للمستند الواحد',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],

          Container(
            height: widget.miniMode ? 550 : 420,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() {}),
                    itemCount: widget.selectedImages.length,
                    itemBuilder: (context, index) {
                      final isPdf = widget.selectedImages[index].path.toLowerCase().endsWith('.pdf');
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isPdf ? const Color(0xFFF0F2F5) : Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF0096D6), width: 2),
                              image: isPdf ? null : DecorationImage(
                                image: _getImageProvider(widget.selectedImages[index]),
                                fit: BoxFit.contain,
                              ),
                            ),
                            child: isPdf ? const Center(child: Icon(Icons.picture_as_pdf, size: 60, color: Colors.red)) : null,
                          ),
                          //زر حذف الصورة
                          if (!widget.isProcessing)
                            Positioned(
                              top: 10, left: 10,
                              child: IconButton(
                                icon: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 18)),
                                onPressed: () => widget.onImageRemoved(index),
                              ),
                            ),
                           Positioned(
                            bottom: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                              child: Text('صفحة ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                //هذا الجزء يعرض الصور المصغرة اسفل البيج فيو
                if (widget.selectedImages.length > 1)
                  Container(
                    height: 80,
                    margin: const EdgeInsets.only(top: 15),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.selectedImages.length,
                      itemBuilder: (context, index) {
                        bool isActive = false;
                        if (_pageController.hasClients) {
                          isActive = _pageController.page?.round() == index;
                        } else {
                          isActive = index == 0;
                        }
                        
                        return GestureDetector(
                          onTap: () => _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? const Color(0xFF0096D6) : Colors.transparent,
                                width: 2.5,
                              ),
                              image: DecorationImage(
                                image: _getImageProvider(widget.selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isProcessing
                      ? null
                      : () => widget.onImagePicked(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(
                    'كاميرا',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0096D6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isProcessing
                      ? null
                      : () => widget.onImagePicked(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: Text(
                    'معرض',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF607D8B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.isProcessing
                      ? null
                      : widget.onDocumentPicked,
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  label: Text(
                    'PDF',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          //زر بدء المسح الذكي
          if (widget.selectedImages.isNotEmpty && !widget.isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onStartScan,
                  icon: const Icon(Icons.auto_awesome, size: 24),
                  label: Text(
                    'بدء المسح الذكي لجميع الصفحات',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF00C853).withOpacity(0.5),
                  ),
                ),
              ),
            ),
       //عرض مؤشر التحميل أثناء المعالجة
          if (widget.isProcessing)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFEB1555),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🤖 جاري تحليل المستند المكون من ${widget.selectedImages.length} صفحات...',
                    style: GoogleFonts.cairo(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
