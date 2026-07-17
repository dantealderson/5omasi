import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:khomasi/theme/app_colors.dart';

/// Primary action button. Solid emerald with dark "ink-on-kit" text by
/// default; pass [backgroundColor] for semantic actions (e.g. danger) and the
/// label flips to white automatically.
class MyButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String text;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final bool enableHaptics;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double fontSize;

  const MyButton({
    super.key,
    required this.onTap,
    this.text = 'تسجيل دخول',
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.enableHaptics = true,
    this.margin,
    this.borderRadius = 14,
    this.fontSize = 16,
  });

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() => _isPressed = true);
      _animationController.forward();
      if (widget.enableHaptics) HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bool isDisabled = widget.onTap == null || widget.isLoading;
    final bool isDefault = widget.backgroundColor == null;

    final Color bg =
        isDisabled ? p.surfaceRaised : (widget.backgroundColor ?? p.emerald);
    // Dark ink on the emerald default; white on custom semantic colors.
    final Color fg = isDisabled
        ? p.textLow
        : (widget.textColor ?? (isDefault ? p.onEmerald : Colors.white));

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isDisabled ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: widget.width,
              height: widget.height,
              margin:
                  widget.margin ?? const EdgeInsets.symmetric(horizontal: 25.0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  if (!isDisabled)
                    BoxShadow(
                      color: bg.withOpacity(0.28),
                      blurRadius: _isPressed ? 6 : 18,
                      offset: Offset(0, _isPressed ? 2 : 8),
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  splashColor: fg.withOpacity(0.12),
                  highlightColor: fg.withOpacity(0.06),
                  onTap: isDisabled ? null : widget.onTap,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(fg),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, color: fg, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.text,
                                style: TextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.fontSize,
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
        },
      ),
    );
  }
}
