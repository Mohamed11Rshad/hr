import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DateCalculatorDialog extends StatefulWidget {
  final String currentDate;
  final String title;

  const DateCalculatorDialog({
    Key? key,
    required this.currentDate,
    this.title = 'حساب التاريخ',
  }) : super(key: key);

  @override
  State<DateCalculatorDialog> createState() => _DateCalculatorDialogState();

  static Future<String?> show({
    required BuildContext context,
    required String currentDate,
    String title = 'حساب التاريخ',
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (context) =>
              DateCalculatorDialog(currentDate: currentDate, title: title),
    );
  }
}

class _DateCalculatorDialogState extends State<DateCalculatorDialog> {
  late TextEditingController yearsController;
  late TextEditingController monthsController;
  late TextEditingController daysController;
  String? errorMessage;
  DateTime? baseDate;
  DateTime? calculatedDate;

  @override
  void initState() {
    super.initState();
    yearsController = TextEditingController();
    monthsController = TextEditingController();
    daysController = TextEditingController();
    _parseCurrentDate();
    _calculateDate(); // Initial calculation
  }

  void _parseCurrentDate() {
    try {
      if (widget.currentDate.isNotEmpty) {
        if (widget.currentDate.contains('.')) {
          final parts = widget.currentDate.split('.');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            baseDate = DateTime(year, month, day);
          }
        } else if (widget.currentDate.contains('/')) {
          final parts = widget.currentDate.split('/');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            baseDate = DateTime(year, month, day);
          }
        } else {
          baseDate = DateTime.tryParse(widget.currentDate);
        }
      }
    } catch (e) {
      print('Error parsing current date: $e');
    }

    // If parsing failed or no date provided, use current date
    baseDate ??= DateTime.now();
  }

  @override
  void dispose() {
    yearsController.dispose();
    monthsController.dispose();
    daysController.dispose();
    super.dispose();
  }

  void _calculateDate() {
    try {
      setState(() {
        errorMessage = null;
      });

      final years = int.tryParse(yearsController.text.trim()) ?? 0;
      final months = int.tryParse(monthsController.text.trim()) ?? 0;
      final days = int.tryParse(daysController.text.trim()) ?? 0;

      if (baseDate != null) {
        // Add years and months first
        var tempDate = DateTime(
          baseDate!.year + years,
          baseDate!.month + months,
          baseDate!.day,
        );

        // Then add days
        calculatedDate = tempDate.add(Duration(days: days));
      }
    } catch (e) {
      setState(() {
        errorMessage = 'خطأ في حساب التاريخ: ${e.toString()}';
        calculatedDate = null;
      });
    }
  }

  void _validateAndSave() {
    if (calculatedDate != null) {
      final formattedDate =
          '${calculatedDate!.day.toString().padLeft(2, '0')}'
          '.${calculatedDate!.month.toString().padLeft(2, '0')}'
          '.${calculatedDate!.year}';
      Navigator.of(context).pop(formattedDate);
    } else {
      setState(() {
        errorMessage = 'يرجى إدخال قيم صحيحة للحساب';
      });
    }
  }

  void _resetToCurrentDate() {
    setState(() {
      yearsController.clear();
      monthsController.clear();
      daysController.clear();
      calculatedDate = baseDate;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18.w.clamp(16, 24),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Current date display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'التاريخ الحالي :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    baseDate != null
                        ? '${baseDate!.day.toString().padLeft(2, '0')}'
                            '.${baseDate!.month.toString().padLeft(2, '0')}'
                            '.${baseDate!.year}'
                        : 'غير محدد',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Input fields for years, months, days
            const Text(
              'أضف إلى التاريخ الحالي :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.center,

                    controller: daysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      labelText: 'أيام',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (_) => _calculateDate(),
                  ),
                ),

                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.center,
                    controller: monthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      labelText: 'شهور',
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (_) => _calculateDate(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    textAlign: TextAlign.center,
                    controller: yearsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      floatingLabelAlignment: FloatingLabelAlignment.center,
                      labelText: 'سنوات',

                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (_) => _calculateDate(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Calculated date display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'التاريخ المحسوب :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calculatedDate != null
                        ? '${calculatedDate!.day.toString().padLeft(2, '0')}'
                            '.${calculatedDate!.month.toString().padLeft(2, '0')}'
                            '.${calculatedDate!.year}'
                        : 'أدخل القيم للحساب',
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          calculatedDate != null
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _resetToCurrentDate,
          child: const Text('إعادة تعيين'),
        ),
        ElevatedButton(
          onPressed: calculatedDate != null ? _validateAndSave : null,
          child: const Text('تطبيق التاريخ المحسوب'),
        ),
      ],
    );
  }
}
