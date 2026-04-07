import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategorySelectionSection extends StatelessWidget {
  //القيم المختارة حاليا فى القوائم المنسدلة
  final String? selectedMainCategory;
  final String? selectedSubCategory;
  final String? selectedFileClassification;
  //القوائم التي ستظهر في Dropdown لكل تصنيف.
  final List<String> mainCategories;
  final List<String> subCategories;
  final List<String> fileClassifications;
  //Callbacks تُستدعى عند تغيير المستخدم للاختيار.
  final Function(String?) onMainCategoryChanged;
  final Function(String?) onSubCategoryChanged;
  final Function(String?) onFileClassificationChanged;

  const CategorySelectionSection({
    super.key,
    required this.selectedMainCategory,
    required this.selectedSubCategory,
    required this.selectedFileClassification,
    required this.mainCategories,
    required this.subCategories,
    required this.fileClassifications,
    required this.onMainCategoryChanged,
    required this.onSubCategoryChanged,
    required this.onFileClassificationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📂 اختر نوع المستند',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // التصنيف الرئيسي
          _buildDropdown(
            label: 'التصنيف الرئيسي',
            value: selectedMainCategory,
            items: mainCategories,
            onChanged: onMainCategoryChanged,
          ),
          const SizedBox(height: 16),

          // التصنيف الفرعي
          if (subCategories.isNotEmpty)
            _buildDropdown(
              label: 'التصنيف الفرعي',
              value: selectedSubCategory,
              items: subCategories,
              onChanged: onSubCategoryChanged,
            ),
          const SizedBox(height: 16),

          // تصنيف الملف
          if (fileClassifications.isNotEmpty)
            _buildDropdown(
              label: 'تصنيف الملف',
              value: selectedFileClassification,
              items: fileClassifications,
              onChanged: onFileClassificationChanged,
            ),
        ],
      ),
    );
  }

  /// بناء قائمة منسدلة
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0096D6)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              hint: Text(
                'اختر $label',
                style: GoogleFonts.cairo(color: Colors.black38),
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: GoogleFonts.cairo(color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
