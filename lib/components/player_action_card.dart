import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlayerActionCard extends StatelessWidget {
  final String playerName;
  final int playerNumber;
  final int goals;
  final int assists;
  final int yellowCards;
  final bool hasRedCard;
  final DateTime? redCardTime;
  final VoidCallback onGoal;
  final VoidCallback onAssist;
  final VoidCallback onYellowCard;
  final VoidCallback onRedCard;

  const PlayerActionCard({
    super.key,
    required this.playerName,
    required this.playerNumber,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.hasRedCard,
    this.redCardTime,
    required this.onGoal,
    required this.onAssist,
    required this.onYellowCard,
    required this.onRedCard,
  });

  String get _timeRemaining {
    if (!hasRedCard || redCardTime == null) return '';
    
    final elapsed = DateTime.now().difference(redCardTime!);
    final remaining = const Duration(minutes: 5) - elapsed;
    
    if (remaining.isNegative) return 'منتهي';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasRedCard 
            ? (isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: hasRedCard
            ? Border.all(
                color: isDark ? Colors.red.shade700 : Colors.red.shade300,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: hasRedCard 
                ? Colors.red.withOpacity(isDark ? 0.2 : 0.1)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Player info row
            Row(
              children: [
                // Player number circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasRedCard 
                        ? Colors.red 
                        : Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      playerNumber.toString(),
                      style: TextStyle(
                        color: Theme.of(context).cardColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Player name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: hasRedCard 
                              ? Colors.red.shade700 
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                     if (hasRedCard) ...[
                        const SizedBox(height: 2),
                        StreamBuilder<int>(
                        stream: Stream.periodic(const Duration(seconds: 1), (x) => x),
                        builder: (context, snapshot) {
                        return Text(
                         'موقوف - متبقي $_timeRemaining',
                            style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
        ),
      );
    },
  ),
],
                    ],
                  ),
                ),
                
                // Stats badges
                Row(
                  children: [
                    if (goals > 0)
                      _buildStatBadge('⚽', goals.toString(), Colors.green, isDark),
                    if (assists > 0)
                      _buildStatBadge('🎯', assists.toString(), Colors.blue, isDark),
                    if (yellowCards > 0)
                      _buildStatBadge('🟨', yellowCards.toString(), Colors.orange, isDark),
                    if (hasRedCard)
                      _buildStatBadge('🟥', '', Colors.red, isDark),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                // Goal button
                _buildActionButton(
                  icon: Icons.sports_soccer,
                  label: 'هدف',
                  color: Colors.green,
                  onTap: hasRedCard ? null : onGoal,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                
                // Assist button
                _buildActionButton(
                  icon: Icons.sports,
                  label: 'صناعة',
                  color: Colors.blue,
                  onTap: hasRedCard ? null : onAssist,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                
                // Yellow card button
                _buildActionButton(
                  icon: Icons.square,
                  label: 'أصفر',
                  color: Colors.orange,
                  onTap: hasRedCard ? null : onYellowCard,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                
                // Red card button
                _buildActionButton(
                  icon: Icons.square,
                  label: 'أحمر',
                  color: Colors.red,
                  onTap: hasRedCard ? null : onRedCard,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String emoji, String value, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final isDisabled = onTap == null;
    
    return Expanded(
      child: Material(
        color: isDisabled 
            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isDisabled 
              ? null 
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDisabled ? Colors.grey : color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDisabled 
                        ? Colors.grey 
                        : Color.lerp(color, isDark ? Colors.white : Colors.black, 0.3)!,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}