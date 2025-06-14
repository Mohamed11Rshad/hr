import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hr/core/app_colors.dart';

class ConfigButton extends StatelessWidget {
  const ConfigButton({
    super.key,
    required this.isLoading,
    required this.title,
    required this.exists,
    required this.onPressed,
  });

  final bool isLoading;
  final String title;
  final bool exists;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(0, 0),
            padding: EdgeInsets.symmetric(horizontal: 16.w.clamp(0, 20)),
            backgroundColor: AppColors.primaryColor.withAlpha(200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: isLoading ? null : onPressed,
          child: SizedBox(
            height: 30.h.clamp(0, 40),
            width: 140.w.clamp(0, 160),
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp.clamp(11, 15),
                ),
              ),
            ),
          ),
        ),
        if (exists)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 15.w.clamp(12, 18),
              height: 15.w.clamp(12, 18),
              decoration: const BoxDecoration(
                color: Colors.white54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.primaryColor.withAlpha(250),
                size: 16.w.clamp(7, 9),
              ),
            ),
          ),
      ],
    );
  }
}
