import 'package:flutter/material.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/utils/category_mapper.dart';

class CategoryStatusWidget extends StatelessWidget {
  final Map<String, Map<String, bool>> categoryStatus;

  const CategoryStatusWidget({Key? key, required this.categoryStatus})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'حالة جداول الفئات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...CategoryMapper.getAllCategories().map((category) {
              final status =
                  categoryStatus[category] ??
                  {'salaryScale': false, 'annualIncrease': false};
              return _buildCategoryRow(category, status);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String category, Map<String, bool> status) {
    final salaryScaleExists = status['salaryScale'] ?? false;
    final annualIncreaseExists = status['annualIncrease'] ?? false;
    final allExist = salaryScaleExists && annualIncreaseExists;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allExist ? Icons.check_circle : Icons.warning,
                color: allExist ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        allExist
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTableStatus(
                  'سلم الرواتب',
                  CategoryMapper.getSalaryScaleTable(category),
                  salaryScaleExists,
                ),
                const SizedBox(height: 2),
                _buildTableStatus(
                  'الزيادة السنوية',
                  CategoryMapper.getAnnualIncreaseTable(category),
                  annualIncreaseExists,
                ),
              ],
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildTableStatus(String label, String tableName, bool exists) {
    return Row(
      children: [
        Icon(
          exists ? Icons.check : Icons.close,
          color: exists ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            tableName,
            style: TextStyle(
              fontSize: 12,
              color: exists ? Colors.green.shade600 : Colors.red.shade600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
