import 'package:flutter/material.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class AddTerminationDialog extends StatefulWidget {
  const AddTerminationDialog({Key? key}) : super(key: key);

  @override
  State<AddTerminationDialog> createState() => _AddTerminationDialogState();
}

class _AddTerminationDialogState extends State<AddTerminationDialog> {
  final TextEditingController _badgesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _selectedAppraisal = '';
  DateTime? _selectedDate;

  @override
  void dispose() {
    _badgesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة تسريح موظفين'),
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
                    'أدخل رقم البادج أو عدة أرقام مفصولة بفاصلة أو سطر جديد',
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAppraisal.isNotEmpty ? _selectedAppraisal : null,
              decoration: const InputDecoration(
                labelText: 'نص التقييم (Appraisal Text)',
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(),
                hintText: 'اختر نص التقييم للموظفين',
              ),
              items: const [
                DropdownMenuItem<String>(value: '', child: Text('بدون تقييم')),
                DropdownMenuItem<String>(value: 'O', child: Text('O')),
                DropdownMenuItem<String>(value: 'E', child: Text('E')),
                DropdownMenuItem<String>(value: 'Ep', child: Text('Ep')),
                DropdownMenuItem<String>(value: 'M', child: Text('M')),
                DropdownMenuItem<String>(value: 'P', child: Text('P')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAppraisal = value ?? '';
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'تاريخ التسريح',
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                hintText: 'اختر تاريخ التسريح',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectDate,
                ),
              ),
              readOnly: true,
              onTap: _selectDate,
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      });
    }
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
        if (RegExp(r'^\d+$').hasMatch(entry)) {
          badgeNumbers.add(entry);
        } else {
          invalidEntries.add(entry);
        }
      }
    }

    // Validate termination date
    if (_selectedDate == null) {
      CustomSnackbar.showError(context, 'يرجى اختيار تاريخ التسريح');
      return;
    }

    // Validate appraisal text
    if (_selectedAppraisal.isEmpty) {
      CustomSnackbar.showError(context, 'يرجى اختيار نص التقييم');
      return;
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
      Navigator.of(context).pop(
        badgeNumbers
            .map(
              (badge) => {
                'badgeNo': badge,
                'terminationDate': _dateController.text,
                'appraisalText': _selectedAppraisal,
              },
            )
            .toList(),
      );
    } else {
      CustomSnackbar.showError(
        context,
        'يرجى إدخال أرقام البادج بالصيغة الصحيحة',
      );
    }
  }
}
