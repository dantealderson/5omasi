import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';

/// Live scoreline on an emerald slab — the biggest fixtures-board moment in the
/// app, so the scores are set in mono. Team chips keep their blue/red identity.
class ScoreBoard extends StatelessWidget {
  final String teamAName;
  final String teamBName;
  final int teamAScore;
  final int teamBScore;

  const ScoreBoard({
    super.key,
    required this.teamAName,
    required this.teamBName,
    required this.teamAScore,
    required this.teamBScore,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandPressed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _team(context, teamAName, teamAScore, const Color(0xFF4C8DFF)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'VS',
                  style: AppText.mono(
                      size: 14,
                      color: p.onEmerald.withOpacity(0.85),
                      weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text('–',
                  style: TextStyle(
                      color: p.onEmerald.withOpacity(0.4), fontSize: 30)),
            ],
          ),
          _team(context, teamBName, teamBScore, const Color(0xFFFF5D5D)),
        ],
      ),
    );
  }

  Widget _team(BuildContext context, String name, int score, Color chip) {
    final p = context.palette;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chip.withOpacity(0.28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              name,
              style: TextStyle(
                color: p.onEmerald,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            score.toString(),
            style: AppText.mono(size: 48, color: p.onEmerald, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
