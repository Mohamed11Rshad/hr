import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/widgets/custom_snackbar.dart';

class AddTransferDialog extends StatefulWidget {
  const AddTransferDialog({Key? key}) : super(key: key);

  @override
  State<AddTransferDialog> createState() => _AddTransferDialogState();
}

class _AddTransferDialogState extends State<AddTransferDialog> {
  final TextEditingController _badgeController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();

  @override
  void dispose() {
    _badgeController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة تنقل جديد'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _badgeController,
              maxLines: 5,
              scrollPhysics: const BouncingScrollPhysics(),
              decoration: const InputDecoration(
                labelText: 'أرقام الموظفين',
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
              ),

              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _positionController,
              maxLines: 5,
              scrollPhysics: const BouncingScrollPhysics(),
              decoration: const InputDecoration(
                labelText: 'أكواد الوظائف',

                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
              ),
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 8),
            const Text(
              'ملاحظة: يجب أن يكون عدد أرقام الموظفين مساوياً لعدد أكواد الوظائف',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,

                fontStyle: FontStyle.italic,
              ),
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
    final badgeText = _badgeController.text.trim();
    final positionText = _positionController.text.trim();

    if (badgeText.isEmpty || positionText.isEmpty) {
      CustomSnackbar.showError(context, 'يرجى إدخال جميع البيانات المطلوبة');
      return;
    }

    // Parse badge numbers
    final badgeNumbers =
        badgeText
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    // Parse position codes
    final positionCodes =
        positionText
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    // Validate that we have the same number of badges and positions
    if (badgeNumbers.length != positionCodes.length) {
      CustomSnackbar.showError(
        context,
        'عدد أرقام الموظفين (${badgeNumbers.length}) لا يساوي عدد أكواد الوظائف (${positionCodes.length})',
      );
      return;
    }

    if (badgeNumbers.isEmpty) {
      CustomSnackbar.showError(context, 'يرجى إدخال رقم موظف واحد على الأقل');
      return;
    }

    // Validate badge numbers are numeric
    final invalidBadges = <String>[];
    for (final badge in badgeNumbers) {
      if (!RegExp(r'^\d+$').hasMatch(badge)) {
        invalidBadges.add(badge);
      }
    }

    if (invalidBadges.isNotEmpty) {
      CustomSnackbar.showError(
        context,
        'أرقام الموظفين التالية غير صحيحة (يجب أن تكون أرقام فقط):\n${invalidBadges.join(', ')}',
      );
      return;
    }

    // Create pairs of badge numbers and position codes
    final transfers = <Map<String, String>>[];
    for (int i = 0; i < badgeNumbers.length; i++) {
      transfers.add({
        'badgeNo': badgeNumbers[i],
        'positionCode': positionCodes[i],
      });
    }

    Navigator.of(context).pop(transfers);
  }
}
