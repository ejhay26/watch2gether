import "package:flutter/material.dart";
import "../../constants/theme.dart";

enum ToastType { info, success, error, warning }

class AppToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    Color iconColor;
    IconData iconData;
    Color borderColor;

    switch (type) {
      case ToastType.success:
        iconColor = const Color(0xFF2ED573);
        iconData = Icons.check_circle_rounded;
        borderColor = const Color(0xFF2ED573).withValues(alpha: 0.4);
        break;
      case ToastType.error:
        iconColor = const Color(0xFFFF4757);
        iconData = Icons.error_rounded;
        borderColor = const Color(0xFFFF4757).withValues(alpha: 0.4);
        break;
      case ToastType.warning:
        iconColor = const Color(0xFFFFA502);
        iconData = Icons.warning_rounded;
        borderColor = const Color(0xFFFFA502).withValues(alpha: 0.4);
        break;
      case ToastType.info:
      default:
        iconColor = AppColors.accent;
        iconData = Icons.info_rounded;
        borderColor = AppColors.accent.withValues(alpha: 0.4);
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        backgroundColor: const Color(0xFF141622),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        duration: duration,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
