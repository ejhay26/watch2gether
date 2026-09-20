import 'package:flutter/material.dart';
import '../../constants/theme.dart';

class MobileGesturesOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTapLeft;
  final VoidCallback onDoubleTapRight;
  final VoidCallback onTap;

  const MobileGesturesOverlay({
    super.key,
    required this.child,
    required this.onDoubleTapLeft,
    required this.onDoubleTapRight,
    required this.onTap,
  });

  @override
  State<MobileGesturesOverlay> createState() => _MobileGesturesOverlayState();
}

class _MobileGesturesOverlayState extends State<MobileGesturesOverlay> {
  String? _indicatorText;
  bool _showIndicator = false;

  void _triggerIndicator(String text) {
    setState(() {
      _indicatorText = text;
      _showIndicator = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return GestureDetector(
          onTap: widget.onTap,
          onDoubleTapDown: (details) {
            final dx = details.localPosition.dx;
            if (dx < screenWidth * 0.35) {
              widget.onDoubleTapLeft();
              _triggerIndicator('-10s');
            } else if (dx > screenWidth * 0.65) {
              widget.onDoubleTapRight();
              _triggerIndicator('+10s');
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_showIndicator && _indicatorText != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Text(
                      _indicatorText!,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
