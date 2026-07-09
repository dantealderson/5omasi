import 'package:flutter/material.dart';

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
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: color ?? Colors.transparent,
            child: Row(
              children: [
                Icon(icon, size: 24, color: textColor ?? Colors.black87),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: textColor ?? Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.grey, indent: 20, endIndent: 20),
      ],
    );
  }
}
