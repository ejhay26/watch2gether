import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/theme.dart';
import 'liquid_glass.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    
    // Proportional dimensions: sleek and compact on desktop, comfortable on mobile
    final double navWidth = isDesktop ? 248.0 : (screenWidth - 48).clamp(260.0, 305.0);
    final double navHeight = isDesktop ? 52.0 : 62.0;
    final double borderRadius = navHeight / 2.0;
    final double iconSize = isDesktop ? 19.0 : 22.0;
    final double fontSize = isDesktop ? 10.5 : 11.0;
    final double itemSpacing = isDesktop ? 2.0 : 3.0;
    final double pillRadius = isDesktop ? 18.0 : 22.0;
    final EdgeInsets itemMargin = isDesktop 
        ? const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5)
        : const EdgeInsets.symmetric(horizontal: 3.5, vertical: 3.0);

    return Center(
      child: SizedBox(
        width: navWidth,
        height: navHeight,
        child: LiquidGlassCard(
          borderRadius: borderRadius,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Row(
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                iconSize: iconSize,
                fontSize: fontSize,
                itemSpacing: itemSpacing,
                pillRadius: pillRadius,
                itemMargin: itemMargin,
              ),
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.history_rounded,
                label: 'History',
                iconSize: iconSize,
                fontSize: fontSize,
                itemSpacing: itemSpacing,
                pillRadius: pillRadius,
                itemMargin: itemMargin,
              ),
              _buildNavItem(
                context: context,
                index: 2,
                icon: Icons.tune_rounded,
                label: 'Settings',
                iconSize: iconSize,
                fontSize: fontSize,
                itemSpacing: itemSpacing,
                pillRadius: pillRadius,
                itemMargin: itemMargin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required double iconSize,
    required double fontSize,
    required double itemSpacing,
    required double pillRadius,
    required EdgeInsets itemMargin,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(pillRadius),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(index);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: itemMargin,
            decoration: BoxDecoration(
              // Symmetrical selected pill bubble matching current theme
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(pillRadius),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  SizedBox(height: itemSpacing),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      letterSpacing: 0.2,
                    ),
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
