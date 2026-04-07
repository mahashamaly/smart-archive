import 'package:flutter/foundation.dart';
import 'dart:io' as io; // استخدام alias فقط لتجنب الأخطاء في مناطق أخرى قد تحتاجها في الديسكتوب
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/category_model.dart';
import '../services/category_service.dart';
import '../services/ai_factory.dart';
import '../services/ai_service.dart';
import '../widgets/image_capture_section.dart';
import '../widgets/category_selection_section.dart';
import '../widgets/dynamic_form_section.dart';
import '../models/processed_document.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';
import '../services/employee_service.dart';
import 'employee_file_page.dart';
import 'ai_analytics_page.dart';

class DynamicArchivePage extends StatefulWidget {
  final ProcessedDocument? document;
  final Employee? initialEmployee; // دعم تمرير موظف من صفحة الملف

  const DynamicArchivePage({
    super.key, 
    this.document,
    this.initialEmployee,
  });

  @override
  State<DynamicArchivePage> createState() => _DynamicArchivePageState();
}

class _DynamicArchivePageState extends State<DynamicArchivePage> {
  // القوائم المنسدلة
  String? selectedMainCategory;
  String? selectedSubCategory;
  String? selectedFileClassification;

  // القوائم المتاحة
  List<String> mainCategories = [];
  List<String> subCategories = [];
  List<String> fileClassifications = [];

  // الحقول الديناميكية
  List<DynamicField> dynamicFields = [];
  Map<String, TextEditingController> fieldControllers = {};

  final TextEditingController targetEmployeeController = TextEditingController();
  final FocusNode targetEmployeeFocusNode = FocusNode();


  // الصور المختارة (استخدام XFile للويب والديسكتوب)
  List<XFile> selectedImages = [];
  bool isProcessing = false;
  Employee? selectedEmployee; // الموظف المختار حالياً

  @override
  void initState() {
    super.initState();
    // إذا تم تمرير موظف من صفحة الملف (مثل منال)، نقم بتعيينه فوراً
    if (widget.initialEmployee != null) {
      selectedEmployee = widget.initialEmployee;
      targetEmployeeController.text = widget.initialEmployee!.name;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadMainCategories();
    if (widget.document != null) {
      await _initializeForEditing();
    }
  }

  Future<void> _initializeForEditing() async {
    //أخذ المستند الذى أرسل للصفحة
    final doc = widget.document!;
    //تعبئة البيانات الاساسية
    if (mounted) {
      setState(() {
        selectedMainCategory = doc.mainCategory;
        selectedImages = doc.imagePaths.map((path) => XFile(path)).toList();
      });
    }
//التأكد من وجود Main Category
    if (doc.mainCategory != null) {
      final subs = await CategoryService.getSubCategories(doc.mainCategory!);
      if (!mounted) return;
      setState(() {
        subCategories = subs;
        selectedSubCategory = doc.subCategory;
      });

      if (doc.subCategory != null) {
        final files = await CategoryService.getFileClassifications(
          doc.mainCategory!,
          doc.subCategory!,
        );
        if (!mounted) return;
        setState(() {
          fileClassifications = files;
          selectedFileClassification = doc.fileClassification;
        });
        if (doc.fileClassification != null) {
          final fields = await CategoryService.getFields(
            doc.mainCategory!,
            doc.subCategory!,
            doc.fileClassification!,
          );
          if (!mounted) return;
          setState(() {
            //خزنا الحقول
            dynamicFields = fields;
            for (var field in fields) {
              final controller = TextEditingController(
                text: doc.fieldValues[field.id] ?? '',
              );
              fieldControllers[field.id] = controller;
            }
          });
        }
      }
    }

    // ✅ مهم جداً: تحميل بيانات الموظف المرتبط بهذا المستند
    final empName = doc.fieldValues['employee_name'];
    final empId = doc.fieldValues['employee_id'];
    //التأكد من وجود اسم الموظف:
    if (empName != null) {
      setState(() {
        targetEmployeeController.text = empName;
        // محاولة استعادة كائن الموظف للبحث
        if (empId != null) {
          selectedEmployee = Employee(id: empId, name: empName, department: '');
        }
      });
    }
  }

  @override
  void dispose() {
    // تنظيف الـ controllers
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    targetEmployeeController.dispose();
    targetEmployeeFocusNode.dispose();
    super.dispose();

  }

  /// تحميل التصنيفات الرئيسية
  Future<void> _loadMainCategories() async {
    final categories = await CategoryService.getMainCategories();
    if (mounted) {
      setState(() {
        mainCategories = categories;
      });
    }
  }

  /// عند اختيار التصنيف الرئيسي
  Future<void> _onMainCategoryChanged(String? value) async {
    if (value == null) return;

    setState(() {
      selectedMainCategory = value;
      //إلغاء اختيار التصنيف الفرعي والملف:
      selectedSubCategory = null;
      selectedFileClassification = null;
      subCategories = [];
      fileClassifications = [];
      dynamicFields = [];
      _clearControllers();
    });

    final subs = await CategoryService.getSubCategories(value);
    if (mounted) {
      setState(() {
        subCategories = subs;
      });
    }
  }

  /// عند اختيار التصنيف الفرعي
  Future<void> _onSubCategoryChanged(String? value) async {
    if (value == null || selectedMainCategory == null) return;

    setState(() {
      selectedSubCategory = value;
      //إلغاء أي File Classification محدد سابقًا:
      //لأن التصنيف الفرعي الجديد قد يكون له File Classifications مختلفة.
      selectedFileClassification = null;
      fileClassifications = [];
      dynamicFields = [];
      _clearControllers();
    });

    final files = await CategoryService.getFileClassifications(
      selectedMainCategory!,
      value,
    );
    if (mounted) {
      setState(() {
        fileClassifications = files;
      });
    }
  }

  /// عند اختيار تصنيف الملف
  Future<void> _onFileClassificationChanged(String? value) async {
    if (value == null ||
        selectedMainCategory == null ||
        selectedSubCategory == null) {
      return;
    }

    setState(() {
      selectedFileClassification = value;
      dynamicFields = [];
      _clearControllers();
    });
   //تحميل الحقول الديناميكية
    final fields = await CategoryService.getFields(
      selectedMainCategory!,
      selectedSubCategory!,
      value,
    );

    if (mounted) {
      setState(() {
        dynamicFields = fields;
        
        for (var field in fields) {
          fieldControllers[field.id] = TextEditingController();
        }
      });
    }
  }

  /// تنظيف الـ controllers
  void _clearControllers() {
    for (var controller in fieldControllers.values) {
      controller.dispose();
    }
    fieldControllers.clear();
  }

  /// اختيار صورة من الكاميرا أو المعرض
  Future<void> _pickImage(ImageSource source) async {
    // 🖥️ تحويل الطلب لمعرض الصور إذا كان النظام ويب أو ويندوز
    ImageSource effectiveSource = source;
    bool isWebOrWindows = kIsWeb || (defaultTargetPlatform == TargetPlatform.windows);
    if (isWebOrWindows && source == ImageSource.camera) {
      debugPrint("🖥️ تم تحويل طلب الكاميرا إلى معرض الصور لتوافقه مع المتصفح/الويندوز.");
      effectiveSource = ImageSource.gallery;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: effectiveSource,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
//التحقق إذا المستخدم اختار صورة
      if (pickedFile != null) {
        setState(() {
          selectedImages.add(pickedFile);
        });
        debugPrint("📸 تمت إضافة صورة: ${pickedFile.path}");
      }
    } catch (e) {
      debugPrint("⛔ خطأ أثناء التقاط الصورة: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل فتح الكاميرا. تأكد من منح الصلاحيات اللازمة.', 
              style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// اختيار ملف PDF
  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedImages.add(XFile(result.files.single.path!));
      });
    }
  }

  /// حذف صورة أو ملف
  void _removeImage(int index) {
      setState(() {
      selectedImages.removeAt(index);
    });
  }

  /// البحث عن أقرب تطابق في قائمة مع مراعاة خصائص اللغة العربية
  String? _findBestMatch(String searchTerm, List<String> options) {
    if (searchTerm.isEmpty || options.isEmpty) return null;

    // دالة لتنظيف النص العربي وتوحيده
    String normalize(String text) {
      return text
          .replaceAll('ال', '') // إزالة ال التعريف
          .replaceAll('أ', 'ا') // توحيد الألف
          .replaceAll('إ', 'ا')
          .replaceAll('آ', 'ا')
          .replaceAll('ة', 'ه') // توحيد التاء المربوطة والهاء
          .replaceAll('ى', 'ي') // توحيد الياء والألف المقصورة
          .replaceAll(RegExp(r'\s+'), '') // إزالة المسافات
          .trim();
    }
//توحيد كلمة البحث
    final normalizedSearch = normalize(searchTerm);

    // 1. البحث عن تطابق دقيق أولاً
    for (var option in options) {
      if (option.trim() == searchTerm.trim()) return option;
    }

    // 2. البحث عن تطابق بعد التوحيد 
    for (var option in options) {
      if (normalize(option) == normalizedSearch) {
        debugPrint("🔍 تطابق بعد التوحيد: '$searchTerm' ≈ '$option'");
        return option;
      }
    }

    // 3. البحث عن تطابق جزئي بعد التوحيد
    for (var option in options) {
      final normalizedOption = normalize(option);
      if (normalizedOption.contains(normalizedSearch) ||
          normalizedSearch.contains(normalizedOption)) {
        debugPrint("🔍 تطابق جزئي بعد التوحيد: '$searchTerm' ≈ '$option'");
        return option;
      }
    }

    return null;
  }

  /// تحليل الصورة وتحديد التصنيفات والحقول تلقائياً
  Future<void> _analyzeImageAndPopulateFields() async {
    if (selectedImages.isEmpty) return;

    setState(() {
      isProcessing = true;
    });
//إنشاء كائن الخدمة وتحليل الصور
    try {
      // 🚀 هنا نستخدم "المدير الذكي المطوّر" الذي يوجه الصور للوكيل المناسب مع نظام طوارئ!
      final extractedData = await AIFactory.executeWithFallback(
        selectedImages.map((e) => e.path).toList(),
        targetEmployeeId: targetEmployeeController.text.trim().isNotEmpty 
            ? targetEmployeeController.text.trim() 
            : null,
      );
      
      debugPrint("📊 البيانات المستخرجة: $extractedData");

      // تحديد التصنيفات بناءً على البيانات المستخرجة
      final mainCat = extractedData['mainCategory'] ?? '';
      final subCat = extractedData['subCategory'] ?? '';
      final fileCat = extractedData['fileClass'] ?? '';

      debugPrint("🔎 البحث عن: mainCat='$mainCat', subCat='$subCat', fileCat='$fileCat'");

      // تحميل التصنيفات المتاحة
      await _loadMainCategories();
      debugPrint("📋 التصنيفات الرئيسية المتاحة: $mainCategories");

      // البحث عن أقرب تطابق للتصنيف الرئيسي
      final matchedMainCat = _findBestMatch(mainCat, mainCategories);
      
      if (matchedMainCat != null) {
        debugPrint("✅ تم العثور على التصنيف الرئيسي: $matchedMainCat");
        await _onMainCategoryChanged(matchedMainCat);
        debugPrint("📋 التصنيفات الفرعية المتاحة: $subCategories");
        
        // البحث عن أقرب تطابق للتصنيف الفرعي
        final matchedSubCat = _findBestMatch(subCat, subCategories);
        
        if (matchedSubCat != null) {
          debugPrint("✅ تم العثور على التصنيف الفرعي: $matchedSubCat");
          await _onSubCategoryChanged(matchedSubCat);
          debugPrint("📋 تصنيفات الملف المتاحة: $fileClassifications");
          
          // البحث عن أقرب تطابق لتصنيف الملف
          final matchedFileCat = _findBestMatch(fileCat, fileClassifications);
          
          if (matchedFileCat != null) {
            debugPrint("✅ تم العثور على تصنيف الملف: $matchedFileCat");
            await _onFileClassificationChanged(matchedFileCat);
            
            // ملء الحقول بالبيانات المستخرجة
            debugPrint("📝 ملء الحقول: ${fieldControllers.keys.toList()}");
            setState(() {
              final fields = extractedData['fields'] as Map<String, dynamic>? ?? {};
              for (var entry in fields.entries) {
                if (fieldControllers.containsKey(entry.key) && fieldControllers[entry.key] != null) {
                  fieldControllers[entry.key]!.text = entry.value.toString();
                  debugPrint("✏️ تم ملء الحقل '${entry.key}' بالقيمة '${entry.value}'");
                }
              }
            });
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ تم تحليل المستند وملء الحقول بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            debugPrint("⚠️ لم يتم العثور على تطابق لتصنيف الملف: $fileCat");
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ لم يتم العثور على تصنيف الملف: $fileCat'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          debugPrint("⚠️ لم يتم العثور على تطابق للتصنيف الفرعي: $subCat");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ لم يتم العثور على التصنيف الفرعي: $subCat'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint("⚠️ لم يتم العثور على تطابق للتصنيف الرئيسي: $mainCat");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ لم يتم العثور على التصنيف الرئيسي: $mainCat'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ خطأ في تحليل المستند: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في تحليل المستند: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  /// زر الحفظ
  void _onSave() async {
    // تجهيز القيم للحفظ
    Map<String, String> fieldValues = {};
    fieldControllers.forEach((key, controller) {
      fieldValues[key] = controller.text;
    });

    // 🔗 تأمين ربط المستند بالموظف (مهم جداً للظهور في الملف)
    String? finalEmpName = targetEmployeeController.text.trim();
    String? finalEmpId = selectedEmployee?.id;

    // إذا لم يكن لدينا ID ولكن لدينا اسم، نحاول البحث عنه في الخدمة لضمان الربط
    if (finalEmpId == null && finalEmpName.isNotEmpty) {
      final matches = await EmployeeService.searchEmployees(finalEmpName);
      if (matches.isNotEmpty) {
        finalEmpId = matches.first.id;
        finalEmpName = matches.first.name; 
      }
    }

    if (finalEmpName.isNotEmpty) {
      fieldValues['employee_name'] = finalEmpName;
      if (finalEmpId != null) fieldValues['employee_id'] = finalEmpId;
    }

    final doc = ProcessedDocument(
      id: widget.document?.id ?? const Uuid().v4().substring(0, 8),
      timestamp: widget.document?.timestamp ?? DateTime.now(),
      mainCategory: selectedMainCategory,
      subCategory: selectedSubCategory,
      fileClassification: selectedFileClassification,
      imagePaths: selectedImages.map((f) => f.path).toList(),
      fieldValues: fieldValues,
      // إذا كان مستند جديد -> بانتظار التدقيق، إذا كان تعديل -> مدقق
      status: widget.document == null ? 'pending' : 'reviewed',
    );

    // حفظ في قاعدة البيانات المحلية
    await DatabaseService.instance.saveDocument(doc);
    debugPrint("💾 تم حفظ المستند بنجاح للموظف: $finalEmpName (ID: $finalEmpId)");

    // إظهار تنبيه النجاح
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00C853)),
            const SizedBox(width: 10),
            Text('تمت الأرشفة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'تم اعتماد المستند ونقله إلى الأرشيف المركزي بنجاح.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق الديالوج
              Navigator.pop(context, true); // العودة للشاشة السابقة مع نتيجة نجاح
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('رجوع لصندوق الوارد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديد نوع الواجهة بناءً على عرض الشاشة
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900; 

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // خلفية فاتحة مثل نظام البلدية
      appBar: AppBar(
        backgroundColor: const Color(0xFF0096D6), // أزرق البلدية الرسمي
        elevation: 2,
        title: Text(
          isDesktop ? 'واجهة التدقيق والأرشفة الذكية' : 'نظام الأرشفة الذكي',
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: isDesktop ? _buildSplitLayout() : _buildMobileLayout(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AIAnalyticsPage()),
          );
        },
        backgroundColor: const Color(0xFF0096D6),
        label: Text('المحلل الذكي', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.analytics, color: Colors.white),
      ),
    );
  }

  /// واجهة الموبايل 
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ImageCaptureSection(
            selectedImages: selectedImages,
            isProcessing: isProcessing,
            onImagePicked: _pickImage,
            onDocumentPicked: _pickDocument,
            onImageRemoved: _removeImage,
            onStartScan: _analyzeImageAndPopulateFields,
          ),
          const SizedBox(height: 20),
          _buildTargetEmployeeField(),
          const SizedBox(height: 24),
          if (selectedMainCategory != null) ...[
            CategorySelectionSection(
              selectedMainCategory: selectedMainCategory,
              selectedSubCategory: selectedSubCategory,
              selectedFileClassification: selectedFileClassification,
              mainCategories: mainCategories,
              subCategories: subCategories,
              fileClassifications: fileClassifications,
              onMainCategoryChanged: _onMainCategoryChanged,
              onSubCategoryChanged: _onSubCategoryChanged,
              onFileClassificationChanged: _onFileClassificationChanged,
            ),
            const SizedBox(height: 20),
          ],
          if (dynamicFields.isNotEmpty || selectedFileClassification != null) ...[
            DynamicFormSection(
              fields: dynamicFields,
              controllers: fieldControllers,
              buttonLabel: widget.document == null 
                  ? 'إرسال لصندوق الوارد (بانتظار التدقيق)' 
                  : 'اعتماد وأرشفة نهائية',
              onSave: _onSave,
            ),
          ],
        ],
      ),
    );
  }

  /// واجهة العرض المنقسم بالألوان الفاتحة
  Widget _buildSplitLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الجانب الأيسر: معاينة المستند
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.black12, width: 1)),
              color: Colors.white, // أبيض للمعاينة
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: Color(0xFF0096D6)),
                      const SizedBox(width: 8),
                      Text(
                        'معاينة المستند الرئيسي',
                        style: GoogleFonts.cairo(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ImageCaptureSection(
                    selectedImages: selectedImages,
                    isProcessing: isProcessing,
                    onImagePicked: _pickImage,
                    onDocumentPicked: _pickDocument,
                    onImageRemoved: _removeImage,
                    onStartScan: _analyzeImageAndPopulateFields,
                    miniMode: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // الجانب الأيمن: البيانات
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTargetEmployeeField(),
                const SizedBox(height: 24),
                
                if (selectedMainCategory != null) ...[
                  CategorySelectionSection(
                    selectedMainCategory: selectedMainCategory,
                    selectedSubCategory: selectedSubCategory,
                    selectedFileClassification: selectedFileClassification,
                    mainCategories: mainCategories,
                    subCategories: subCategories,
                    fileClassifications: fileClassifications,
                    onMainCategoryChanged: _onMainCategoryChanged,
                    onSubCategoryChanged: _onSubCategoryChanged,
                    onFileClassificationChanged: _onFileClassificationChanged,
                  ),
                  const SizedBox(height: 24),
                ],

                if (dynamicFields.isNotEmpty || selectedFileClassification != null) ...[
                  DynamicFormSection(
                    fields: dynamicFields,
                    controllers: fieldControllers,
                    buttonLabel: widget.document == null 
                        ? 'إرسال لصندوق الوارد (بانتظار التدقيق)' 
                        : 'اعتماد وأرشفة نهائية',
                    onSave: _onSave,
                  ),
                ] else if (!isProcessing && selectedImages.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD), // أزرق فاتح جداً
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF0096D6), size: 54),
                        const SizedBox(height: 16),
                        Text(
                          'اضغط على "بدء المسح الذكي" لاستخراج البيانات آلياً',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF0D47A1),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// حقل إدخال الموظف مع ميزة الإكمال التلقائي
Widget _buildTargetEmployeeField() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Autocomplete<Employee>(
        textEditingController: targetEmployeeController,
        focusNode: targetEmployeeFocusNode,
        displayStringForOption: (Employee option) => option.name,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Employee>.empty();//اذا الحقل فارغ لا تظهر الاقتراحات
          }
          return EmployeeService.searchEmployees(textEditingValue.text);
        },
        onSelected: (Employee selection) {
          setState(() {
            //حفظ الموظف المختار
            selectedEmployee = selection;
            // تحديث النص يدوياً لضمان الظهور الفوري في البوكس
            targetEmployeeController.text = selection.name;
          });
          debugPrint('✅ تم اختيار الموظف: ${selection.name}');
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.cairo(color: Colors.black87),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_search, color: Color(0xFF0096D6)),
              suffixIcon: selectedEmployee != null 
                ? IconButton(
                    icon: const Icon(Icons.folder_shared, color: Colors.blueAccent),
                    tooltip: 'عرض الملف الكامل لهذا الموظف',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EmployeeFilePage(
                            employeeName: selectedEmployee!.name,
                            employeeId: selectedEmployee!.id,
                          ),
                        ),
                      );
                    },
                  )
                : null,
              hintText: 'البحث برقم الهوية أو الاسم (إكمال تلقائي)...',
              hintStyle: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topRight, // محاذاة لليمين لتناسب اللغة العربية
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: constraints.maxWidth, // مطابقة عرض المربع النصي تماماً
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Employee option = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.badge, color: Color(0xFF0096D6)),
                      title: Text(option.name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${option.id} - ${option.department}', style: GoogleFonts.cairo(fontSize: 11)),
                      onTap: () {
                        onSelected(option); // تنفيذ الاختيار البرمجي
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
}
