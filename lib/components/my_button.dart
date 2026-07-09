import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.height = 60,
    this.enableHaptics = true,
    // defaults to keep the original look
    this.margin, 
    this.borderRadius = 30,
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
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() {
        _isPressed = true;
      });
      _animationController.forward();
      if (widget.enableHaptics) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() {
        _isPressed = false;
      });
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isLoading && widget.onTap != null) {
      setState(() {
        _isPressed = false;
      });
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onTap == null || widget.isLoading;

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
              duration: const Duration(milliseconds: 200),
              width: widget.width,
              height: widget.height,
              //Uses custom margin or 25.0
              margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 25.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDisabled
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [
                          widget.backgroundColor ?? Colors.deepPurple,
                          widget.backgroundColor?.withOpacity(0.8) ??
                              Colors.deepPurple.shade700,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                // custom border radius
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  if (!isDisabled)
                    BoxShadow(
                      color: (widget.backgroundColor ?? Colors.deepPurple)
                          .withOpacity(0.3),
                      blurRadius: _isPressed ? 5 : 15,
                      offset: Offset(0, _isPressed ? 2 : 5),
                      spreadRadius: _isPressed ? 0 : 2,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  // matching border radius before splash effect
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  onTap: isDisabled ? null : widget.onTap,
                  child: Center(
                    child: widget.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.textColor ?? Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: widget.textColor ?? Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.text,
                                style: TextStyle(
                                  color: widget.textColor ?? Colors.white,
                                  fontWeight: FontWeight.bold,
                                  // UPDATED: Uses custom font size
                                  fontSize: widget.fontSize,
                                  letterSpacing: 0.5,
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