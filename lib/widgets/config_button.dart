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
            backgroundColor: AppColors.primaryColor.withAlpha(200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: isLoading ? null : onPressed,
          child: SizedBox(
            height: 50.h.clamp(20, 60),
            width: 150.w.clamp(120, 180),
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
        if (exists)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 20.w.clamp(18, 22),
              height: 20.w.clamp(18, 22),
              decoration: const BoxDecoration(
                color: Colors.white54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.primaryColor.withAlpha(250),
                size: 16.w.clamp(14, 18),
              ),
            ),
          ),
      ],
    );
  }
}
