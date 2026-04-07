import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category_model.dart'; // Make sure path is correct relative to lib/widgets/

class DynamicFormSection extends StatefulWidget {
  final List<DynamicField> fields;
  final Map<String, TextEditingController> controllers;
  final String buttonLabel; // مسمى الزر المتغير
  final VoidCallback onSave;

  const DynamicFormSection({
    super.key,
    required this.fields,
    required this.controllers,
    required this.buttonLabel,
    required this.onSave,
  });

  @override
  State<DynamicFormSection> createState() => _DynamicFormSectionState();
}

class _DynamicFormSectionState extends State<DynamicFormSection> {
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
            '📝 بيانات المستند المستخرجة',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          // عرض الحقول الديناميكية
          ...widget.fields.map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDynamicField(field),
            );
          }),
          
          const SizedBox(height: 32),
          
          // زر الحفظ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onSave,
              icon: const Icon(Icons.save, size: 24),
              label: Text(
                widget.buttonLabel,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853), 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء حقل ديناميكي
  Widget _buildDynamicField(DynamicField field) {
    if (field.type == 'dropdown' && field.options != null) {
      return _buildDynamicDropdown(field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              field.label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (field.required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controllers[field.id],
          style: GoogleFonts.cairo(color: Colors.black87),
          keyboardType: field.type == 'date'
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0096D6), width: 2),
            ),
            hintText: 'أدخل ${field.label}',
            hintStyle: GoogleFonts.cairo(color: Colors.black26),
          ),
        ),
      ],
    );
  }

  /// بناء قائمة منسدلة ديناميكية
  Widget _buildDynamicDropdown(DynamicField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              field.label,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (field.required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
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
              value: (widget.controllers[field.id]!.text.isNotEmpty &&
                      field.options!.contains(widget.controllers[field.id]!.text))
                  ? widget.controllers[field.id]!.text
                  : null,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0096D6)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              hint: Text(
                'اختر ${field.label}',
                style: GoogleFonts.cairo(color: Colors.black26),
              ),
              items: field.options!.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: GoogleFonts.cairo(color: Colors.black87),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  widget.controllers[field.id]!.text = value ?? '';
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
