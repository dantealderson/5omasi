import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';

/// A full-width settings/menu row: leading icon, label, trailing chevron,
/// and a hairline beneath. Theme-aware.
class MyWideButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? textColor;

  const MyWideButton({
    super.key,
    required this.text,
    required this.icon,
    this.onTap,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = textColor ?? p.textHi;
    return Column(
      children: [
        Material(
          color: color ?? Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: fg),
                  const SizedBox(width: 14),
                  Text(
                    text,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 15, color: p.textLow),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: p.line, indent: 20, endIndent: 20),
      ],
    );
  }
}
