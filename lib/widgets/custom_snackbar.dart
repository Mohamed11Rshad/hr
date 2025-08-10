import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/enums/data_operation_type.dart';

class CustomSnackbar {
  static void showSuccess(BuildContext context, String message) {
    _showSnackbar(
      context,
      message,
      type: SnackbarType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _showSnackbar(
      context,
      message,
      type: SnackbarType.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackbar(
      context,
      message,
      type: SnackbarType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showSnackbar(
      context,
      message,
      type: SnackbarType.warning,
    );
  }

  static void _showSnackbar(
    BuildContext context,
    String message, {
    required SnackbarType type,
    Duration? duration,
  }) {
    final config = _getSnackbarConfig(type);
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => CustomSnackbarWidget(
        message: message,
        backgroundColor: config.backgroundColor,
        icon: config.icon,
        iconColor: config.iconColor,
        onDismiss: () => overlayEntry.remove(),
        duration: duration ?? AppConstants.snackbarDuration,
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration ?? AppConstants.snackbarDuration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static _SnackbarConfig _getSnackbarConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          backgroundColor: Colors.green.shade600,
          icon: Icons.check_circle,
          iconColor: Colors.white,
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          backgroundColor: Colors.red.shade600,
          icon: Icons.error,
          iconColor: Colors.white,
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          backgroundColor: Colors.blue.shade600,
          icon: Icons.info,
          iconColor: Colors.white,
        );
      case SnackbarType.warning:
        return _SnackbarConfig(
          backgroundColor: Colors.orange.shade600,
          icon: Icons.warning,
          iconColor: Colors.white,
        );
    }
  }
}

class _SnackbarConfig {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;

  _SnackbarConfig({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
  });
}

class CustomSnackbarWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const CustomSnackbarWidget({
    Key? key,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
    required this.duration,
  }) : super(key: key);

  @override
  State<CustomSnackbarWidget> createState() => _CustomSnackbarWidgetState();
}

class _CustomSnackbarWidgetState extends State<CustomSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(Icons.close, color: widget.iconColor, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
