import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/services/player_rating_service.dart';
import 'package:khomasi/l10n/app_localizations.dart';

// Trait definitions with icons
const List<Map<String, dynamic>> _positiveTraits = [
  {'key': 'fast', 'icon': Icons.speed},
  {'key': 'goodPasser', 'icon': Icons.swap_horiz},
  {'key': 'strongShot', 'icon': Icons.sports_soccer},
  {'key': 'teamPlayer', 'icon': Icons.groups},
  {'key': 'goodDefense', 'icon': Icons.shield},
  {'key': 'skilled', 'icon': Icons.auto_awesome},
];

const List<Map<String, dynamic>> _negativeTraits = [
  {'key': 'selfish', 'icon': Icons.person},
  {'key': 'slow', 'icon': Icons.hourglass_bottom},
  {'key': 'aggressive', 'icon': Icons.warning_amber},
  {'key': 'badPositioning', 'icon': Icons.wrong_location},
  {'key': 'weakStamina', 'icon': Icons.battery_1_bar},
];

class RatePlayersPage extends StatefulWidget {
  final String matchId;
  final String currentUserId;
  final Map<String, dynamic> matchData;

  const RatePlayersPage({
    super.key,
    required this.matchId,
    required this.currentUserId,
    required this.matchData,
  });

  @override
  State<RatePlayersPage> createState() => _RatePlayersPageState();
}

class _RatePlayersPageState extends State<RatePlayersPage> {
  final Map<String, double> _ratings = {};
  final Map<String, List<String>> _selectedTraits = {}; // oderId -> list of trait keys
  Map<String, double> _existingRatings = {};
  Map<String, List<String>> _existingTraits = {};
  List<Map<String, dynamic>> _players = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _players = PlayerRatingService.getMatchPlayers(
      widget.matchData,
      widget.currentUserId,
    );

    final existing = await PlayerRatingService.getMyRatingsForMatch(
      widget.currentUserId,
      widget.matchId,
    );

    _existingRatings = existing.map((k, v) => MapEntry(k, v['rating'] as double));
    _existingTraits = existing.map((k, v) {
      final traits = v['traits'];
      if (traits is List) {
        return MapEntry(k, traits.cast<String>());
      }
      return MapEntry(k, <String>[]);
    });

    // Pre-fill existing
    for (final entry in _existingRatings.entries) {
      _ratings[entry.key] = entry.value;
    }
    for (final entry in _existingTraits.entries) {
      _selectedTraits[entry.key] = List.from(entry.value);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _submitRatings() async {
    if (_ratings.isEmpty) return;

    setState(() => _isSubmitting = true);

    int successCount = 0;
    for (final entry in _ratings.entries) {
      final ok = await PlayerRatingService.ratePlayer(
        raterUserId: widget.currentUserId,
        ratedPlayerId: entry.key,
        matchId: widget.matchId,
        rating: entry.value,
        traits: _selectedTraits[entry.key] ?? [],
      );
      if (ok) successCount++;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    HapticFeedback.mediumImpact();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              tr(context, 'ratingsSubmitted'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$successCount / ${_ratings.length}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr(context, 'ok')),
            ),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _toggleTrait(String oderId, String traitKey) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTraits.putIfAbsent(oderId, () => []);
      if (_selectedTraits[oderId]!.contains(traitKey)) {
        _selectedTraits[oderId]!.remove(traitKey);
      } else {
        _selectedTraits[oderId]!.add(traitKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stadiumName = widget.matchData['stadiumName'] ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr(context, 'ratePlayers')),
        backgroundColor: AppColors.brand,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _players.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80,
                          color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        tr(context, 'noPlayersToRate'),
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.brand, AppColors.brandPressed],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            stadiumName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(context, 'ratePlayersSubtitle'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Players list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _players.length,
                        itemBuilder: (context, index) {
                          return _buildPlayerRatingCard(_players[index], isDark);
                        },
                      ),
                    ),

                    // Submit button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _ratings.isEmpty || _isSubmitting
                              ? null
                              : _submitRatings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '${tr(context, 'submitRatings')} (${_ratings.length}/${_players.length})',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPlayerRatingCard(Map<String, dynamic> player, bool isDark) {
    final oderId = player['oderId'] as String;
    final playerName = player['playerName'] as String? ?? 'لاعب';
    final team = player['team'] as String?;
    final currentRating = _ratings[oderId];
    final hadExistingRating = _existingRatings.containsKey(oderId);
    final playerTraits = _selectedTraits[oderId] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: currentRating != null
            ? Border.all(color: AppColors.brand.withOpacity(0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Player avatar
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(oderId).get(),
                builder: (context, snapshot) {
                  String? imageUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    imageUrl = (snapshot.data!.data() as Map<String, dynamic>?)?['profileImageUrl'] as String?;
                  }
                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: team == 'A'
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                    child: imageUrl == null
                        ? Text(
                            playerName.isNotEmpty ? playerName[0] : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: team == 'A' ? Colors.blue : Colors.red,
                            ),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      team == 'A' ? tr(context, 'teamA') : tr(context, 'teamB'),
                      style: TextStyle(
                        fontSize: 12,
                        color: team == 'A' ? Colors.blue : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentRating != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRatingColor(currentRating).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: _getRatingColor(currentRating), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        currentRating.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getRatingColor(currentRating),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hadExistingRating && currentRating != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Star rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = (index + 1).toDouble();
              final isSelected = currentRating != null && currentRating >= starValue;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _ratings[oderId] = starValue;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isSelected ? Colors.amber : (isDark ? Colors.grey[600] : Colors.grey[400]),
                      size: 40,
                    ),
                  ),
                ),
              );
            }),
          ),
          // Traits section - only show after rating is given
          if (currentRating != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Positive traits
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(context, 'positiveTraits'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _positiveTraits.map((trait) {
                final key = trait['key'] as String;
                final icon = trait['icon'] as IconData;
                final isSelected = playerTraits.contains(key);
                return _buildTraitChip(
                  key: key,
                  icon: icon,
                  isSelected: isSelected,
                  isPositive: true,
                  isDark: isDark,
                  onTap: () => _toggleTrait(oderId, key),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Negative traits
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(context, 'negativeTraits'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _negativeTraits.map((trait) {
                final key = trait['key'] as String;
                final icon = trait['icon'] as IconData;
                final isSelected = playerTraits.contains(key);
                return _buildTraitChip(
                  key: key,
                  icon: icon,
                  isSelected: isSelected,
                  isPositive: false,
                  isDark: isDark,
                  onTap: () => _toggleTrait(oderId, key),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraitChip({
    required String key,
    required IconData icon,
    required bool isSelected,
    required bool isPositive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final color = isPositive ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            Text(
              tr(context, key),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }
}
