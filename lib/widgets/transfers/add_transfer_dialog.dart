import 'package:flutter/material.dart';

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
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _badgeController,
              decoration: const InputDecoration(
                labelText: 'رقم الموظف',
                border: OutlineInputBorder(),
                hintText: 'أدخل رقم الموظف',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'كود الوظيفة',
                border: OutlineInputBorder(),
                hintText: 'أدخل كود الوظيفة',
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
    final badgeNo = _badgeController.text.trim();
    final positionCode = _positionController.text.trim();

    if (badgeNo.isEmpty || positionCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال جميع البيانات المطلوبة')),
      );
      return;
    }

    Navigator.of(
      context,
    ).pop({'badgeNo': badgeNo, 'positionCode': positionCode});
  }
}
