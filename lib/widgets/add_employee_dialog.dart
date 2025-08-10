import 'package:flutter/material.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class AddEmployeeDialog extends StatefulWidget {
  final Function(List<String>) onAddEmployees;

  const AddEmployeeDialog({Key? key, required this.onAddEmployees})
    : super(key: key);

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final TextEditingController _badgesController = TextEditingController();

  @override
  void dispose() {
    _badgesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة موظف للترقيات'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _badgesController,
              decoration: const InputDecoration(
                labelText: 'Badge Numbers',
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(),
                hintText:
                    'أدخل رقم البادج للموظف أو عدة أرقام مفصولة بفاصلة أو سطر جديد',
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _onAddPressed, child: const Text('إضافة')),
      ],
    );
  }

  void _onAddPressed() {
    final badgeNumbers = <String>[];
    final invalidEntries = <String>[];

    final text = _badgesController.text.trim();
    if (text.isNotEmpty) {
      final entries = text
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);

      for (final entry in entries) {
        // Validate that entry contains only numbers
        if (RegExp(r'^\d+$').hasMatch(entry)) {
          badgeNumbers.add(entry);
        } else {
          invalidEntries.add(entry);
        }
      }
    }

    // Show validation errors if any
    if (invalidEntries.isNotEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('خطأ في التحقق'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'القيم التالية غير صحيحة (يجب أن تكون أرقام فقط):',
                  ),
                  const SizedBox(height: 8),
                  ...invalidEntries.map((entry) => Text('• $entry')),
                  const SizedBox(height: 16),
                  const Text('الصيغة الصحيحة:'),
                  const Text('• رقم واحد: 12345'),
                  const Text('• عدة أرقام: 12345,67890 أو كل رقم في سطر منفصل'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('موافق'),
                ),
              ],
            ),
      );
      return;
    }

    if (badgeNumbers.isNotEmpty) {
      Navigator.of(context).pop();
      widget.onAddEmployees(badgeNumbers);
    } else {
      // Show message if no valid entries
      CustomSnackbar.showError(
        context,
        'يرجى إدخال أرقام البادج بالصيغة الصحيحة',
      );
    }
  }
}
