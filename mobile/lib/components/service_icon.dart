import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';

class ServiceIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool available;

  const ServiceIcon({
    super.key,
    required this.icon,
    required this.label,
    this.available = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.brand : Colors.grey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: available ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }
}
