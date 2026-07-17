import 'package:flutter/material.dart';

class RefereeStats extends StatelessWidget {
  // We make these optional so you can use this widget anywhere
  final int? totalMatches;
  final int? totalGoals;
  final int? totalCards;
  final int? todayMatches;
  final int? monthMatches; // NEW
  final double? rating;    // NEW

  const RefereeStats({
    super.key,
    this.totalMatches,
    this.totalGoals,
    this.totalCards,
    this.todayMatches,
    this.monthMatches,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على الأداء',
            style: TextStyle(
              fontSize: 18, // Increased to match your profile look
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Row 1
          Row(
            children: [
              if (monthMatches != null)
                _buildStatItem(
                  context: context,
                  icon: Icons.calendar_month,
                  label: 'مباريات الشهر',
                  value: monthMatches.toString(),
                  color: Colors.blue,
                )
              else if (todayMatches != null)
                _buildStatItem(
                  context: context,
                  icon: Icons.sports,
                  label: 'مباريات اليوم',
                  value: todayMatches.toString(),
                  color: Colors.green,
                ),
                
              const SizedBox(width: 12),
              
              _buildStatItem(
                context: context,
                icon: Icons.sports_soccer,
                label: 'الأهداف المسجلة',
                value: (totalGoals ?? 0).toString(),
                color: Colors.green, // Changed to match profile green
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Row 2
          Row(
            children: [
              _buildStatItem(
                context: context,
                icon: Icons.style,
                label: 'البطاقات الصادرة',
                value: (totalCards ?? 0).toString(),
                color: Colors.orange,
              ),
              
              const SizedBox(width: 12),
              
              if (rating != null)
                _buildStatItem(
                  context: context,
                  icon: Icons.star_border,
                  label: 'معدل التقييم',
                  value: '⭐ $rating',
                  color: Colors.amber,
                )
              else
                _buildStatItem(
                  context: context,
                  icon: Icons.event,
                  label: 'إجمالي المباريات',
                  value: (totalMatches ?? 0).toString(),
                  color: Colors.blue,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // Smart color logic: White in dark mode, Dark Grey in light mode
                      color: isDark ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}