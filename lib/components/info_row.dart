import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String label;

  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 20,
          ), 
          child: Row(
            children: [
              Icon(icon, size: 24, color: Colors.deepPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.7,
          indent: 20,
          endIndent: 20,
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
      ],
    );
  }
}