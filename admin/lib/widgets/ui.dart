import 'package:flutter/material.dart';

import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';

/// Page header: Reem Kufi title with an optional one-line hint under it.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.kufi(size: 28, weight: 700, color: p.textHi)),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: TextStyle(color: p.textMid, fontSize: 14)),
        ],
      ],
    );
  }
}

/// Section header inside a card/form: emerald icon + bold title.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, color: p.emerald, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// Standard surface card of the Midnight Club system.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

/// Small emerald chip (surface type, pitch sizes...).
class MiniChip extends StatelessWidget {
  const MiniChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.emeraldSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: p.emerald),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state block: quiet icon, one line of direction.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: p.textLow),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: p.textMid, fontWeight: FontWeight.w600),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(color: p.textLow, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool danger = false}) {
  final p = context.palette;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: danger ? p.danger : p.textHi),
      ),
      behavior: SnackBarBehavior.floating,
      width: 420,
    ),
  );
}

/// Confirmation dialog for destructive actions. Resolves to true on confirm.
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
}) async {
  final p = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: p.danger),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// dd/mm/yyyy — matches how the mobile app prints dates.
String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// 12-hour clock with the Arabic am/pm marker: "10:00 م".
String formatTime(DateTime d) => formatTimeOfDay(TimeOfDay.fromDateTime(d));

/// Same, from a [TimeOfDay].
String formatTimeOfDay(TimeOfDay t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.hour >= 12 ? 'م' : 'ص';
  return '$hour:$minute $period';
}

String surfaceLabel(String? type) {
  switch (type) {
    case 'natural':
      return 'عشب طبيعي';
    case 'artificial':
      return 'عشب صناعي';
    case 'indoor':
      return 'داخلي';
    default:
      return 'غير محدد';
  }
}
