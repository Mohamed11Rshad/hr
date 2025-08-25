import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/category_mapper.dart';

class SalaryScalesUploadSection extends StatelessWidget {
  final Map<String, Map<String, bool>> categoryStatus;
  final bool statusExists;
  final bool staffAssignmentsExists;
  final bool adjustmentsExists;
  final Function(String) onConfigUpload;

  const SalaryScalesUploadSection({
    Key? key,
    required this.categoryStatus,
    required this.statusExists,
    required this.staffAssignmentsExists,
    required this.adjustmentsExists,
    required this.onConfigUpload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                children: [
                  SizedBox(width: 24),
                  Icon(
                    Icons.table_chart,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Salary Scales Sheets',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...CategoryMapper.getAllCategories().map((category) {
              final status = categoryStatus[category] ??
                  {'salaryScale': false, 'annualIncrease': false};
              return _buildCategorySection(context, category, status);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String category,
    Map<String, bool> status,
  ) {
    final salaryScaleExists = status['salaryScale'] ?? false;
    final annualIncreaseExists = status['annualIncrease'] ?? false;
    final salaryScaleTable = CategoryMapper.getSalaryScaleTable(category);
    final annualIncreaseTable = CategoryMapper.getAnnualIncreaseTable(category);

    // Get the sheet names with spaces for upload
    final salaryScaleSheetName = salaryScaleTable.replaceAll('_', ' ');
    final annualIncreaseSheetName = annualIncreaseTable.replaceAll('_', ' ');

    return Container(
      margin: EdgeInsets.only(bottom: 16, right: 100, left: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 16.sp.clamp(14, 18),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 24),

                // Salary Scale Upload Button
                Expanded(
                  child: _buildUploadButton(
                    context,
                    'Upload Salary Scale',
                    salaryScaleTable,
                    salaryScaleExists,
                    Icons.table_rows,
                    () => onConfigUpload(salaryScaleSheetName),
                  ),
                ),
                const SizedBox(width: 100),
                // Annual Increase Upload Button
                Expanded(
                  child: _buildUploadButton(
                    context,
                    'Upload Annual Increase',
                    annualIncreaseTable,
                    annualIncreaseExists,
                    Icons.trending_up,
                    () => onConfigUpload(annualIncreaseSheetName),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(
    BuildContext context,
    String label,
    String tableName,
    bool exists,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        exists ? Icons.check_circle : icon,
        size: 18.w.clamp(16, 24),
        color: exists ? Colors.white : AppColors.primaryColor,
      ),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: exists ? Colors.white : AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            tableName,
            style: TextStyle(
              fontSize: 10,
              color: exists
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.primaryColor.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: exists ? Colors.green : Colors.white,
        foregroundColor: exists ? Colors.white : AppColors.primaryColor,
        side: BorderSide(
          color: exists ? Colors.green : AppColors.primaryColor,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
