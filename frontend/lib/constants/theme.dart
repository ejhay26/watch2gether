import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Abyssal Obsidian & Sapphire Palette
  static const Color background = Color(0xFF090B10);
  static const Color surface = Color(0xFF0F131C);
  static const Color surfaceElevated = Color(0xFF161B26);
  static const Color surfaceBorder = Color(0xFF232B3C);

  static const Color accent = Color(0xFF6366F1); // Electric Indigo / Sapphire
  static const Color accentBright = Color(0xFF818CF8);
  static const Color accentDim = Color(0xFF4F46E5);
  static const Color accentGlow = Color(0x336366F1);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color ratingAmber = Color(0xFFF59E0B);
  static const Color liveIndicator = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}

class AppMotion {
  // Emil Kowalski & Apple Design Fluid Curve Specifications
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0); // Strong ease-out for responsive UI
  static const Curve easeInOut = Cubic(0.77, 0.0, 0.175, 1.0); // Strong ease-in-out for morphing
  static const Curve easeDrawer = Cubic(0.32, 0.72, 0.0, 1.0); // iOS sheet & drawer curve

  // Durations (strictly keeping UI interactions snappy & responsive)
  static const Duration press = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 210);
  static const Duration modal = Duration(milliseconds: 260);
}

class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final HitTestBehavior behavior;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

class AppTheme {
  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
