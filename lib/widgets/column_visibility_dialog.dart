import 'package:flutter/material.dart';

class ColumnVisibilityDialog extends StatefulWidget {
  final List<String> columns;
  final Map<String, String> columnNames;
  final Set<String> hiddenColumns;
  final VoidCallback onVisibilityChanged;

  const ColumnVisibilityDialog({
    Key? key,
    required this.columns,
    required this.columnNames,
    required this.hiddenColumns,
    required this.onVisibilityChanged,
  }) : super(key: key);

  @override
  State<ColumnVisibilityDialog> createState() => _ColumnVisibilityDialogState();
}

class _ColumnVisibilityDialogState extends State<ColumnVisibilityDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إظهار/إخفاء الأعمدة'),
      content: SizedBox(
        width: double.maxFinite.clamp(0, 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('تحديد الكل'),
              value: widget.hiddenColumns.isEmpty,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    widget.hiddenColumns.clear();
                  } else {
                    widget.hiddenColumns.addAll(widget.columns);
                  }
                });
                widget.onVisibilityChanged();
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.columns.length,
                itemBuilder: (context, index) {
                  final column = widget.columns[index];
                  final displayName = widget.columnNames[column] ?? column;

                  return CheckboxListTile(
                    title: Text(displayName),
                    value: !widget.hiddenColumns.contains(column),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == false) {
                          widget.hiddenColumns.add(column);
                        } else {
                          widget.hiddenColumns.remove(column);
                        }
                      });
                      widget.onVisibilityChanged();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
