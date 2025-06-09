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
                child: const Text(
                  'رفع الملف الأساسي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'ملفات حساب الزيادة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConfigButton(
                  isLoading: isLoading,
                  title: 'Salary Scale A',
                  exists: salaryScaleAExists,
                  onPressed: () => onConfigUpload('Salary Scale A'),
                ),
                const SizedBox(width: 15),
                ConfigButton(
                  isLoading: isLoading,
                  title: 'Salary Scale B',
                  exists: salaryScaleBExists,
                  onPressed: () => onConfigUpload('Salary Scale B'),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConfigButton(
                  isLoading: isLoading,
                  title: 'Annual Increase A',
                  exists: annualIncreaseAExists,
                  onPressed: () => onConfigUpload('Annual Increase A'),
                ),
                const SizedBox(width: 15),
                ConfigButton(
                  isLoading: isLoading,
                  title: 'Annual Increase B',
                  exists: annualIncreaseBExists,
                  onPressed: () => onConfigUpload('Annual Increase B'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'ملفات أخرى',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConfigButton(
                  isLoading: isLoading,
                  title: 'Status',
                  exists: statusExists,
                  onPressed: () => onConfigUpload('Status'),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(height: isLoading ? 16 : 8),
            if (isLoading)
              LinearProgressIndicator(
                color: AppColors.primaryColor,
                backgroundColor: AppColors.primaryColor.withAlpha(40),
              ),
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
