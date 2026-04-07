import 'dart:async';

class Employee {
  final String id;
  final String name;
  final String department;

  Employee({required this.id, required this.name, required this.department});

  @override
  @override
  String toString() => '$id-$name';
}

class EmployeeService {
  // بيانات تجريبية - في الواقع سيتم جلبها من Laravel API
  static final List<Employee> _mockEmployees = [
    Employee(id: '205', name: 'منال داوود سليمان الشوا', department: 'الشؤون الإدارية'),
        Employee(id: '1631', name: 'عبد الباسط أحمد الخيسى', department: 'مدير دائرة الحدائق'),
    Employee(id: '123456789', name: 'أحمد محمد علي', department: 'قسم الهندسة'),
    Employee(id: '987654321', name: 'سارة محمود حسن', department: 'شؤون الموظفين'),
    Employee(id: '456123789', name: 'محمد عبد الله خليل', department: 'الصحة والبيئة'),
    Employee(id: '111222333', name: 'ليلى إبراهيم يوسف', department: 'العلاقات العامة'),
    Employee(id: '999888777', name: 'خالد وليد جابر', department: 'المالية'),
    Employee(id: '151', name: '  صلاح محمد يوسف أبو دية', department: 'المالية'),
  ];
//دالة  للبحث عن الموظفين حسب الاسم او الرقم
  static Future<List<Employee>> searchEmployees(String query) async {
    // محاكاة تأخير الشبكة
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return _mockEmployees.where((emp) {
      return emp.name.contains(query) || 
             emp.id.contains(query) || 
             emp.name.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}
