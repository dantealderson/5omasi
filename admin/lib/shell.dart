import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:admin/main.dart';
import 'package:admin/pages/admins_page.dart';
import 'package:admin/pages/dashboard_page.dart';
import 'package:admin/pages/matches_page.dart';
import 'package:admin/pages/stadiums_page.dart';
import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// Desktop shell: navigation rail on the reading side (right, RTL) with the
/// wordmark and gold trim, content pane beside it.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'لوحة التحكم'),
    (icon: Icons.sports_soccer_outlined, activeIcon: Icons.sports_soccer, label: 'المباريات'),
    (icon: Icons.stadium_outlined, activeIcon: Icons.stadium, label: 'الملاعب'),
    (icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, label: 'المشرفون'),
  ];

  final _pages = const [
    DashboardPage(),
    MatchesPage(),
    StadiumsPage(),
    AdminsPage(),
  ];

  Future<void> _signOut() async {
    final ok = await confirmDanger(
      context,
      title: 'تسجيل الخروج',
      message: 'هل تريد تسجيل الخروج من مكتب العمليات؟',
      confirmLabel: 'خروج',
    );
    if (ok) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: p.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final expanded = constraints.maxWidth >= 980;
          final railWidth = expanded ? 236.0 : 76.0;

          return Row(
            children: [
              // In RTL the first child sits on the right edge.
              Container(
                width: railWidth,
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(left: BorderSide(color: p.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    // Wordmark + ADMIN trim.
                    if (expanded) ...[
                      Center(
                        child: Text(
                          'خماسي',
                          style: AppText.kufi(
                              size: 30, weight: 700, color: p.textHi),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.goldSoft,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: p.gold),
                          ),
                          child: Text(
                            'مكتب العمليات',
                            style: TextStyle(
                              color: p.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Center(
                        child: Text(
                          'خ',
                          style: AppText.kufi(
                              size: 30, weight: 700, color: p.emerald),
                        ),
                      ),
                    const SizedBox(height: 28),

                    for (var i = 0; i < _destinations.length; i++)
                      _RailItem(
                        icon: _destinations[i].icon,
                        activeIcon: _destinations[i].activeIcon,
                        label: _destinations[i].label,
                        selected: _index == i,
                        expanded: expanded,
                        onTap: () => setState(() => _index = i),
                      ),

                    const Spacer(),

                    Divider(color: p.line, height: 1),
                    const SizedBox(height: 10),
                    _RailAction(
                      icon: p.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      label: p.isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                      expanded: expanded,
                      onTap: () => appThemeMode.value =
                          p.isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                    _RailAction(
                      icon: Icons.logout,
                      label: 'تسجيل الخروج',
                      expanded: expanded,
                      danger: true,
                      onTap: _signOut,
                    ),
                    if (expanded && email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textLow, fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content pane.
              Expanded(
                child: IndexedStack(index: _index, children: _pages),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.emerald : p.textMid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? p.emeraldSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 14 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 22),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? p.emerald : p.textMid,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = danger ? p.danger : p.textMid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 0,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              if (expanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(color: color, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
