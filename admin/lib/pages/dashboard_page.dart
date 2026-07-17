import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// The fixtures board: live counts set like a stadium scoreboard, then
/// today's fixtures.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final openMatches = FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'open')
        .snapshots();
    final activeStadiums = FirebaseFirestore.instance
        .collection('stadiums')
        .where('isActive', isEqualTo: true)
        .snapshots();

    final phone = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(phone ? 14 : 28, 28, phone ? 14 : 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'لوحة التحكم',
                hint: 'نظرة سريعة على ما يجري في خماسي الآن',
              ),
              const SizedBox(height: 24),

              // The fixtures board.
              StreamBuilder<QuerySnapshot>(
                stream: openMatches,
                builder: (context, matchSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: activeStadiums,
                    builder: (context, stadiumSnap) {
                      return _ScoreboardRow(
                        openMatches: matchSnap.data?.docs.length,
                        activeStadiums: stadiumSnap.data?.docs.length,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 36),
              const SectionHeader(title: 'مباريات اليوم', icon: Icons.today),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot>(
                stream: openMatches,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل المباريات',
                      hint: '${snapshot.error}',
                    );
                  }

                  final now = DateTime.now();
                  final todayDocs = (snapshot.data?.docs ?? []).where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final dt = (data['dateTime'] as Timestamp?)?.toDate();
                    if (dt == null) return false;
                    return dt.year == now.year &&
                        dt.month == now.month &&
                        dt.day == now.day;
                  }).toList()
                    ..sort((a, b) {
                      final at = ((a.data() as Map)['dateTime'] as Timestamp)
                          .toDate();
                      final bt = ((b.data() as Map)['dateTime'] as Timestamp)
                          .toDate();
                      return at.compareTo(bt);
                    });

                  if (todayDocs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.nights_stay_outlined,
                      title: 'لا توجد مباريات اليوم',
                      hint: 'أنشئ مباراة جديدة من تبويب المباريات',
                    );
                  }

                  return SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < todayDocs.length; i++) ...[
                          if (i > 0)
                            Divider(
                                color: context.palette.line, height: 1),
                          _TodayFixtureRow(
                            data:
                                todayDocs[i].data() as Map<String, dynamic>,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreboardRow extends StatelessWidget {
  const _ScoreboardRow({this.openMatches, this.activeStadiums});

  final int? openMatches;
  final int? activeStadiums;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        label: 'مباريات مفتوحة',
        icon: Icons.sports_soccer,
        value: openMatches,
      ),
      (
        label: 'ملاعب نشطة',
        icon: Icons.stadium_outlined,
        value: activeStadiums,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;
        final children = [
          for (final t in tiles)
            _ScoreboardTile(label: t.label, icon: t.icon, value: t.value),
        ];

        if (narrow) {
          return Column(
            children: [
              for (final c in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: c,
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// One scoreboard tile: mono numerals with a short gold trim rule — the
/// "metal on the bezel" from the mobile app's ticket language.
class _ScoreboardTile extends StatelessWidget {
  const _ScoreboardTile({
    required this.label,
    required this.icon,
    this.value,
  });

  final String label;
  final IconData icon;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: p.emerald),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: p.textMid,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value?.toString() ?? '—',
            textDirection: TextDirection.ltr,
            style: AppText.mono(size: 42, color: p.textHi),
          ),
          const SizedBox(height: 12),
          Container(
            width: 28,
            height: 2,
            color: p.gold,
          ),
        ],
      ),
    );
  }
}

class _TodayFixtureRow extends StatelessWidget {
  const _TodayFixtureRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dt = (data['dateTime'] as Timestamp).toDate();
    final maxPlayers = (data['maxPlayers'] ?? 10) as int;
    final currentPlayers = (data['currentPlayers'] ?? 0) as int;
    final side = maxPlayers ~/ 2;

    final time = Text(
      formatTime(dt),
      textDirection: TextDirection.ltr,
      style: AppText.mono(size: 18, color: p.emerald),
    );
    final name = Text(
      data['stadiumName'] ?? 'ملعب',
      style: Theme.of(context).textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
    );
    final sizeChip =
        MiniChip(label: '${side}v$side', icon: Icons.people_outline);
    final players = Text(
      '$currentPlayers/$maxPlayers',
      textDirection: TextDirection.ltr,
      style: AppText.mono(size: 14, color: p.textMid),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(builder: (context, constraints) {
        // Phones: two lines so the fixed-width parts never overflow.
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  time,
                  const SizedBox(width: 14),
                  Expanded(child: name),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  sizeChip,
                  const SizedBox(width: 12),
                  players,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            time,
            const SizedBox(width: 18),
            Expanded(child: name),
            const SizedBox(width: 12),
            sizeChip,
            const SizedBox(width: 12),
            players,
          ],
        );
      }),
    );
  }
}
