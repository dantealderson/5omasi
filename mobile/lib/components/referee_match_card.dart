import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class RefereeMatchCard extends StatelessWidget {
  final String pitchName;
  final String pitchSize;
  final String location;
  final double? distanceKm; // Distance in kilometers
  final String time;
  final String date;
  final int currentPlayers;
  final int maxPlayers;
  final String? pitchImageUrl;
  final bool isBooked;
  final bool canStart; // true if 5 min before match time
  final VoidCallback onTap;

  const RefereeMatchCard({
    super.key,
    required this.pitchName,
    required this.pitchSize,
    required this.location,
    this.distanceKm,
    required this.time,
    required this.date,
    required this.currentPlayers,
    required this.maxPlayers,
    this.pitchImageUrl,
    this.isBooked = false,
    this.canStart = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top section with image and details
            Row(
              children: [
                // Pitch Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Container(
                    width: 110,
                    height: 130,
                    color: AppColors.brandTint,
                    child: pitchImageUrl != null
                        ? Image.network(
                            pitchImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildMockImage(context),
                          )
                        : _buildMockImage(context),
                  ),
                ),

                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pitch name & size
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pitchName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pitchSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPressed,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Location & Distance
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (distanceKm != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.near_me,
                                      size: 12,
                                      color: AppColors.brand,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      distanceKm! < 1
                                          ? '${(distanceKm! * 1000).round()} م'
                                          : '${distanceKm!.toStringAsFixed(1)} كم',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),

                        // TIME - BIG & BOLD
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.access_time_filled,
                                size: 20,
                                color: AppColors.brandPressed,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandPressed,
                                  ),
                                ),
                                Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom section - Players count & Button
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Player count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[800]
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: currentPlayers == maxPlayers
                              ? Colors.green
                              : AppColors.brand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$currentPlayers/$maxPlayers',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Action Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        onTap();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(_getButtonIcon(), size: 18),
                      label: Text(
                        _getButtonText(context),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockImage(BuildContext context) {
    // Show placeholder when no image is available
    return Container(
      color: AppColors.brandTint,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.stadium,
              size: 40,
              color: AppColors.brand,
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'stadium'),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.brand,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor() {
    if (isBooked && canStart) {
      return Colors.green; // Ready to start
    } else if (isBooked) {
      return Colors.orange; // Booked but not time yet
    }
    return AppColors.brand; // Not booked
  }

  IconData _getButtonIcon() {
    if (isBooked && canStart) {
      return Icons.play_arrow; // Start match
    } else if (isBooked) {
      return Icons.check_circle; // Already booked
    }
    return Icons.sports; // Book to ref
  }

  String _getButtonText(BuildContext context) {
    if (isBooked && canStart) {
      return tr(context, 'startMatch');
    } else if (isBooked) {
      return tr(context, 'alreadyBooked');
    }
    return tr(context, 'bookToReferee');
  }
}