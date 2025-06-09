import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomDatePickerDialog extends StatefulWidget {
  final String currentDate;
  final String title;

  const CustomDatePickerDialog({
    Key? key,
    required this.currentDate,
    this.title = 'تعديل التاريخ',
  }) : super(key: key);

  @override
  State<CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();

  static Future<String?> show({
    required BuildContext context,
    required String currentDate,
    String title = 'تعديل التاريخ',
  }) {
    return showDialog<String>(
      context: context,
      builder:
          (context) =>
              CustomDatePickerDialog(currentDate: currentDate, title: title),
    );
  }
}

class _CustomDatePickerDialogState extends State<CustomDatePickerDialog> {
  late TextEditingController dayController;
  late TextEditingController monthController;
  late TextEditingController yearController;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _parseCurrentDate();
  }

  void _parseCurrentDate() {
    String day = '';
    String month = '';
    String year = '';

    try {
      if (widget.currentDate.isNotEmpty) {
        if (widget.currentDate.contains('.')) {
          final parts = widget.currentDate.split('.');
          day = parts[0];
          month = parts[1];
          year = parts[2];
        } else if (widget.currentDate.contains('/')) {
          final parts = widget.currentDate.split('/');
          day = parts[0];
          month = parts[1];
          year = parts[2];
        }
      }
    } catch (e) {
      print('Error parsing date: $e');
    }

    dayController = TextEditingController(text: day);
    monthController = TextEditingController(text: month);
    yearController = TextEditingController(text: year);
  }

  @override
  void dispose() {
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    final dayValue = dayController.text.trim().padLeft(2, '0');
    final monthValue = monthController.text.trim().padLeft(2, '0');
    final yearValue = yearController.text.trim();

    // Validate input
    final dayInt = int.tryParse(dayValue);
    final monthInt = int.tryParse(monthValue);
    final yearInt = int.tryParse(yearValue);

    if (dayInt != null &&
        monthInt != null &&
        yearInt != null &&
        dayInt >= 1 &&
        dayInt <= 31 &&
        monthInt >= 1 &&
        monthInt <= 12 &&
        yearInt >= 2000 &&
        yearInt <= 2050) {
      final formattedDate = '$dayValue.$monthValue.$yearValue';
      Navigator.of(context).pop(formattedDate);
    } else {
      setState(() {
        errorMessage =
            'يرجى إدخال تاريخ صحيح:\n• اليوم: 1-31\n• الشهر: 1-12\n• السنة: 2000-2050';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: AlertDialog(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18.w.clamp(16, 24),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dayController,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'اليوم',
                      hintText: '01-31',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: monthController,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'الشهر',
                      hintText: '01-12',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'السنة',
                      hintText: '2024',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'الصيغة: يوم.شهر.سنة (مثال: 01.12.2024)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(onPressed: _validateAndSave, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
