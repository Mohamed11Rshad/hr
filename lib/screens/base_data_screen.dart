import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/widgets/custom_snackbar.dart';
import 'package:hr/widgets/common/loading_indicator.dart';
import 'package:hr/widgets/common/error_widget.dart';
import 'package:hr/widgets/common/empty_state.dart';

abstract class BaseDataScreen extends StatefulWidget {
  const BaseDataScreen({Key? key}) : super(key: key);
}

abstract class BaseDataScreenState<T extends BaseDataScreen> extends State<T> {
  bool get isLoading;
  String get errorMessage;
  bool get hasData;

  // Abstract methods
  Widget buildHeader();
  Widget buildContent();
  Widget buildEmptyState();
  Future<void> loadData();
  Future<void> exportToExcel();
  void showColumnVisibilityDialog();

  // Optional methods
  void onAddEmployee() {
    // Default implementation does nothing
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingIndicator(message: 'جاري تحميل البيانات...');
    }

    if (errorMessage.isNotEmpty) {
      return ErrorDisplay(error: errorMessage, onRetry: loadData);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: hasData ? buildContent() : buildEmptyState()),
          ],
        ),
      ),
    );
  }

  Widget buildStandardHeader({
    required List<HeaderAction> actions,
    bool showAddButton = true,
  }) {
    final List<HeaderAction> allActions =
        showAddButton
            ? [
              HeaderAction(
                label: 'إضافة موظف',
                icon: Icons.add,
                onPressed: () => onAddEmployee(),
                color: Colors.green,
              ),
              ...actions,
            ]
            : actions;

    return SizedBox(
      height: 40,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children:
              allActions
                  .map(
                    (action) => [
                      ElevatedButton.icon(
                        onPressed: action.onPressed,
                        icon: Icon(action.icon, color: Colors.white),
                        label: Text(
                          action.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              action.color ?? AppColors.primaryColor,
                        ),
                      ),
                      if (action != allActions.last) const SizedBox(width: 8),
                    ],
                  )
                  .expand((element) => element)
                  .toList(),
        ),
      ),
    );
  }

  void showSuccessMessage(String message) {
    CustomSnackbar.showSuccess(context, message);
  }

  void showErrorMessage(String message) {
    CustomSnackbar.showError(context, message);
  }

  void showInfoMessage(String message) {
    CustomSnackbar.showInfo(context, message);
  }
}

class HeaderAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const HeaderAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
  });
}
