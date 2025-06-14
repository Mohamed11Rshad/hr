import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';
import 'package:hr/widgets/config_button.dart';

class MainUploadCard extends StatelessWidget {
  final String status;
  final bool isLoading;
  final bool salaryScaleAExists;
  final bool salaryScaleBExists;
  final bool annualIncreaseAExists;
  final bool annualIncreaseBExists;
  final bool statusExists;
  final bool staffAssignmentsExists; // Add new property
  final VoidCallback onMainUpload;
  final Function(String) onConfigUpload;

  const MainUploadCard({
    Key? key,
    required this.status,
    required this.isLoading,
    required this.salaryScaleAExists,
    required this.salaryScaleBExists,
    required this.annualIncreaseAExists,
    required this.annualIncreaseBExists,
    required this.statusExists,
    this.staffAssignmentsExists = false, // Add with default value
    required this.onMainUpload,
    required this.onConfigUpload,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            SizedBox(
              height: 50.h.clamp(20, 60),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isLoading ? null : onMainUpload,
                child:
                    isLoading
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'جاري المعالجة...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                        : const Text(
                          'رفع الملف الأساسي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'شيتات الترقية',
                      style: TextStyle(
                        fontSize: 20.sp.clamp(0, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Status',
                      exists: statusExists,
                      onPressed: () => onConfigUpload('Status'),
                    ),
                    const SizedBox(height: 15),

                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Salary Scale A',
                      exists: salaryScaleAExists,
                      onPressed: () => onConfigUpload('Salary Scale A'),
                    ),
                    const SizedBox(height: 15),
                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Salary Scale B',
                      exists: salaryScaleBExists,
                      onPressed: () => onConfigUpload('Salary Scale B'),
                    ),
                    const SizedBox(height: 15),

                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Annual Increase A',
                      exists: annualIncreaseAExists,
                      onPressed: () => onConfigUpload('Annual Increase A'),
                    ),
                    const SizedBox(height: 15),
                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Annual Increase B',
                      exists: annualIncreaseBExists,
                      onPressed: () => onConfigUpload('Annual Increase B'),
                    ),
                  ],
                ),

                SizedBox(width: 30.w.clamp(0, 30)),

                Column(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'شيتات التنقلات',
                      style: TextStyle(
                        fontSize: 20.sp.clamp(0, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ConfigButton(
                      isLoading: isLoading,
                      title: 'Staff Assignments',
                      exists: staffAssignmentsExists,
                      onPressed: () => onConfigUpload('Staff Assignments'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (isLoading)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      color: AppColors.primaryColor,
                      backgroundColor: AppColors.primaryColor.withAlpha(40),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى عدم إغلاق التطبيق أثناء المعالجة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            else
              SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color:
                      status.contains('خطأ')
                          ? Colors.red
                          : status.contains('جاري')
                          ? Colors.blue
                          : status.contains('جاهز')
                          ? Colors.blue
                          : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
