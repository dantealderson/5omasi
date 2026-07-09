import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/components/referee_match_card.dart';
import 'package:khomasi/pages/referee_profile_page.dart';
import 'package:khomasi/pages/active_match_page.dart';
import 'package:khomasi/services/location_service.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class RefereePage extends StatefulWidget {
  const RefereePage({super.key});

  @override
  State<RefereePage> createState() => _RefereePageState();
}

class _RefereePageState extends State<RefereePage> {
  Map<String, double> _matchDistances = {}; // matchId -> distance in km
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _locationLoaded = true);
    }
  }

  double? _getMatchDistance(String matchId, GeoPoint? location) {
    if (!_locationLoaded || location == null) return null;
    
    if (!_matchDistances.containsKey(matchId)) {
      final distance = LocationService.getDistanceFromCached(location);
      if (distance != null) {
        _matchDistances[matchId] = distance;
      }
    }
    return _matchDistances[matchId];
  }
  
  // ==========================================
  // MAPS LOCATION HANDLER
  // ==========================================
  
  Future<void> _openMapsLocation(String? googleMapsUrl, dynamic location) async {
    String? url = googleMapsUrl;
    
    // If no Google Maps URL, try to create one from location coordinates
    if ((url == null || url.isEmpty) && location != null) {
      final geoPoint = location as GeoPoint;
      url = 'https://www.google.com/maps/search/?api=1&query=${geoPoint.latitude},${geoPoint.longitude}';
    }
    
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(context, 'cannotOpenMap')),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'noLocationLink')),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ==========================================
  // MATCH CARD TAP HANDLER
  // ==========================================
  
  void _onMatchCardTap(String matchId, Map<String, dynamic> data, bool isBooked, bool canStart) {
    HapticFeedback.mediumImpact();
    
    if (isBooked && canStart) {
      // Start the match - go to active match page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveMatchPage(
            matchId: matchId,
            venue: data['stadiumName'] ?? tr(context, 'stadium'),
            teamAName: data['teamAName'] ?? tr(context, 'blueTeam'),
            teamBName: data['teamBName'] ?? tr(context, 'redTeam'),
          ),
        ),
      );
    } else {
      // Show match details bottom sheet
      _showMatchDetailsSheet(matchId, data, isBooked);
    }
  }

  // ==========================================
  // MATCH DETAILS BOTTOM SHEET
  // ==========================================

  void _showMatchDetailsSheet(String matchId, Map<String, dynamic> data, bool isBooked) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateTime = (data['dateTime'] as Timestamp).toDate();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pitch Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        color: Colors.deepPurple.shade100,
                        child: data['pitchImageUrl'] != null
                            ? Image.network(
                                data['pitchImageUrl'], 
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildMockPitchImage(),
                              )
                            : _buildMockPitchImage(),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Pitch name & size
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['stadiumName'] ?? tr(context, 'stadium'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            data['pitchSize'] ?? '5×5',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Address
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data['stadiumAddress'] ?? tr(context, 'baghdadIraq'),
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                    
                    // Location text (detailed directions)
                    if (data['locationText'] != null && (data['locationText'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.near_me, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data['locationText'],
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Google Maps button
                    if (data['googleMapsUrl'] != null && (data['googleMapsUrl'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openMapsLocation(data['googleMapsUrl'], data['location']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.map, color: Colors.deepPurple, size: 16),
                              const SizedBox(width: 6),
                              Text(tr(context, 'openInMaps'), style: TextStyle(color: Colors.deepPurple, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Time & Date Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.access_time_filled, 
                              size: 32, 
                              color: Colors.deepPurple.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatMatchTime(dateTime),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                              Text(
                                _formatMatchDateFull(dateTime),
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Player count
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.deepPurple, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            tr(context, 'playersCount'),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${data['currentPlayers'] ?? 0}/${data['maxPlayers'] ?? 10}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isBooked) {
                            _cancelBooking(matchId, data);
                          } else {
                            _bookMatch(matchId, data);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBooked ? Colors.red : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(isBooked ? Icons.cancel : Icons.sports),
                        label: Text(
                          isBooked ? tr(context, 'cancelBooking') : tr(context, 'bookToReferee'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockPitchImage() {
    // Show placeholder when no image is available
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stadium, size: 60, color: Colors.deepPurple.shade300),
          const SizedBox(height: 8),
          Text(
            tr(context, 'stadiumImage'),
            style: TextStyle(color: Colors.deepPurple.shade400),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOOKING METHODS
  // ==========================================

  Future<void> _bookMatch(String matchId, Map<String, dynamic> data) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    
    // Get the match details
    final newMatchTime = (data['dateTime'] as Timestamp).toDate();
    final newMatchStadiumId = data['stadiumId'] as String?;
    final newMatchDuration = (data['durationMinutes'] ?? 60) as int;
    final newMatchEndTime = newMatchTime.add(Duration(minutes: newMatchDuration));
    
    try {
      // Check for conflicts with referee's other booked matches
      final existingBookings = await FirebaseFirestore.instance
          .collection('matches')
          .where('refereeId', isEqualTo: userId)
          .where('status', whereIn: ['open', 'full', 'scheduled', 'inProgress'])
          .get();
      
      for (final doc in existingBookings.docs) {
        if (doc.id == matchId) continue; // Skip the same match
        
        final existingData = doc.data();
        final existingTime = (existingData['dateTime'] as Timestamp).toDate();
        final existingDuration = (existingData['durationMinutes'] ?? 60) as int;
        final existingEndTime = existingTime.add(Duration(minutes: existingDuration));
        final existingStadiumId = existingData['stadiumId'] as String?;
        
        // Check if same stadium or different stadium
        final isSameStadium = newMatchStadiumId != null && 
                              existingStadiumId != null && 
                              newMatchStadiumId == existingStadiumId;
        
        // Check for overlap (new match overlaps with existing match time)
        final hasOverlap = newMatchTime.isBefore(existingEndTime) && 
                          newMatchEndTime.isAfter(existingTime);
        
        if (hasOverlap) {
          // Matches overlap - not allowed regardless of stadium
          if (!mounted) return;
          final existingStadiumName = existingData['stadiumName'] ?? tr(context, 'stadium');
          final existingTimeStr = '${existingTime.hour}:${existingTime.minute.toString().padLeft(2, '0')}';
          _showErrorDialog(tr(context, 'conflictingMatch').replaceAll('{stadium}', existingStadiumName).replaceAll('{time}', existingTimeStr));
          return;
        }
        
        // For different stadiums, check for 1 hour gap (travel time)
        if (!isSameStadium) {
          int gapMinutes;
          if (newMatchTime.isAfter(existingEndTime) || newMatchTime.isAtSameMomentAs(existingEndTime)) {
            // New match is AFTER existing match - gap from existing end to new start
            gapMinutes = newMatchTime.difference(existingEndTime).inMinutes;
          } else {
            // New match is BEFORE existing match - gap from new end to existing start
            gapMinutes = existingTime.difference(newMatchEndTime).inMinutes;
          }
          
          if (gapMinutes < 60) {
            if (!mounted) return;
            final existingStadiumName = existingData['stadiumName'] ?? tr(context, 'stadium');
            final existingTimeStr = '${existingTime.hour}:${existingTime.minute.toString().padLeft(2, '0')}';
            _showErrorDialog(
              tr(context, 'oneHourGapRequired').replaceAll('{stadium}', existingStadiumName).replaceAll('{time}', existingTimeStr)
            );
            return;
          }
        }
        // Same stadium - back-to-back is fine, no gap needed
      }
      
      // No conflicts - proceed with booking
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'refereeId': userId,
        'refereeName': userProvider.userName,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'refereeBookSuccess'), textAlign: TextAlign.center),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'refereeBookFailed'), textAlign: TextAlign.center),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule, color: Colors.red, size: 32),
        ),
        title: Text(
          tr(context, 'scheduleConflict'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tr(context, 'ok'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(String matchId, Map<String, dynamic> data) async {
    // Check if within 2 hours of match start - lockout cancellation
    final matchTime = (data['dateTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final minutesUntilMatch = matchTime.difference(now).inMinutes;
    
    if (minutesUntilMatch <= 120 && minutesUntilMatch > 0) {
      // Within 2 hours - can't cancel
      final hours = minutesUntilMatch ~/ 60;
      final minutes = minutesUntilMatch % 60;
      _showRefereeLockoutDialog(hours, minutes);
      return;
    }
    
    try {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'refereeId': null,
        'refereeName': null,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'cancelSuccess'), textAlign: TextAlign.center),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'cancelFailed'), textAlign: TextAlign.center),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showRefereeLockoutDialog(int hours, int minutes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_clock, color: Colors.orange, size: 32),
        ),
        title: Text(
          tr(context, 'cannotCancelBooking'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          tr(context, 'cannotCancelBeforeTwoHours').replaceAll('{time}', '${hours > 0 ? "$hours ${tr(context, 'hours')} " : ""}$minutes ${tr(context, 'minutes')}'),
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tr(context, 'ok'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // DATE/TIME FORMATTERS
  // ==========================================

  String _formatMatchDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (matchDate == today) {
      return tr(context, 'today');
    } else if (matchDate == tomorrow) {
      return tr(context, 'tomorrow');
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  String _formatMatchDateFull(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (matchDate == today) {
      return tr(context, 'today');
    } else if (matchDate == tomorrow) {
      return tr(context, 'tomorrow');
    } else {
      final weekdays = [tr(context, 'monday'), tr(context, 'tuesday'), tr(context, 'wednesday'), tr(context, 'thursday'), tr(context, 'friday'), tr(context, 'saturday'), tr(context, 'sunday')];
      return '${weekdays[dateTime.weekday - 1]}، ${dateTime.day}/${dateTime.month}';
    }
  }

  String _formatMatchTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? tr(context, 'pm') : tr(context, 'am');
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    
    // Get referee data from provider
    final refereeName = userProvider.userName.isNotEmpty ? userProvider.userName : tr(context, 'referee');
    final refereePhotoUrl = userProvider.userPhotoUrl;
    final refereeStats = userProvider.refereeStats;
    final totalMatchesRefereed = refereeStats?.totalMatchesRefereed ?? 0;
    final todayMatches = refereeStats?.todayMatches ?? 0;
    final thisWeekMatches = refereeStats?.thisWeekMatches ?? 0;
    final averageRating = refereeStats?.averageRating ?? 0.0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2D1F3D), const Color(0xFF1F1F1F)]
                      : [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    children: [
                      // Top bar with profile
                      Row(
                        children: [
                          // Profile avatar
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RefereeProfilePage()),
                              );
                            },
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white24,
                              backgroundImage: refereePhotoUrl != null
                                  ? NetworkImage(refereePhotoUrl)
                                  : null,
                              child: refereePhotoUrl == null
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(context, 'welcomeStadiums'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  refereeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          
                          // Rating badge
                          if (averageRating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(width: 8),
                          
                          // Settings button
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RefereeProfilePage()),
                              );
                            },
                            icon: const Icon(Icons.settings, color: Colors.white),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Quick stats
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildQuickStat(tr(context, 'today'), todayMatches.toString(), Icons.today),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            Expanded(
                              child: _buildQuickStat(tr(context, 'thisWeek'), thisWeekMatches.toString(), Icons.calendar_view_week),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            Expanded(
                              child: _buildQuickStat(tr(context, 'total'), totalMatchesRefereed.toString(), Icons.sports_score),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Available matches section
            _buildMatchesSection(),
            
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MATCHES SECTION
  // ==========================================

  Widget _buildMatchesSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
          );
        }
        
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                tr(context, 'matchLoadError'),
                style: TextStyle(color: Colors.red[400]),
              ),
            ),
          );
        }
        
        // Filter matches that need a referee
        final now = DateTime.now();
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final userId = userProvider.userId;
        
        final matches = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final refereeId = data['refereeId'];
          final dateTime = (data['dateTime'] as Timestamp).toDate();
          
          // Show matches that:
          // 1. Are not completed, cancelled, or in progress
          // 2. Either: have no referee OR this referee booked it
          // 3. Haven't started yet (or within 60 min window)
          final isNotFinished = status != 'completed' && 
                                status != 'cancelled' && 
                                status != 'inProgress';
          final availableOrMine = refereeId == null || refereeId == '' || refereeId == userId;
          final isRelevantTime = dateTime.isAfter(now.subtract(const Duration(minutes: 60)));
          
          return isNotFinished && availableOrMine && isRelevantTime;
        }).toList() ?? [];
        
        // Sort by distance first (closest first), then by date
        matches.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aLocation = aData['location'] as GeoPoint?;
          final bLocation = bData['location'] as GeoPoint?;
          
          final distA = _getMatchDistance(a.id, aLocation);
          final distB = _getMatchDistance(b.id, bLocation);
          
          // If both have distances, sort by distance
          if (distA != null && distB != null) {
            final distCompare = distA.compareTo(distB);
            if (distCompare != 0) return distCompare;
          }
          // If only one has distance, prioritize it
          if (distA != null && distB == null) return -1;
          if (distA == null && distB != null) return 1;
          
          // Fall back to date sorting
          final aTime = (aData['dateTime'] as Timestamp).toDate();
          final bTime = (bData['dateTime'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });
        
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(context, 'availableMatches'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${matches.length} ${tr(context, 'matches')}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Matches list
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'noMatchesForReferee'),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final doc = matches[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final dateTime = (data['dateTime'] as Timestamp).toDate();
                  final refereeId = data['refereeId'];
                  final isBooked = refereeId == userId;
                  
                  // Check if match can start (5 min before to 60 min after)
                  final minutesUntilMatch = dateTime.difference(DateTime.now()).inMinutes;
                  final canStart = isBooked && minutesUntilMatch <= 5 && minutesUntilMatch >= -60;
                  
                  // Get distance
                  final location = data['location'] as GeoPoint?;
                  final distance = _getMatchDistance(doc.id, location);
                  
                  return RefereeMatchCard(
                    pitchName: data['stadiumName'] ?? tr(context, 'stadium'),
                    pitchSize: data['pitchSize'] ?? '5×5',
                    location: data['stadiumAddress'] ?? tr(context, 'baghdadIraq'),
                    distanceKm: distance != null ? double.parse(distance.toStringAsFixed(1)) : null,
                    time: _formatMatchTime(dateTime),
                    date: _formatMatchDate(dateTime),
                    currentPlayers: (data['currentPlayers'] ?? 0) as int,
                    maxPlayers: (data['maxPlayers'] ?? 10) as int,
                    pitchImageUrl: data['pitchImageUrl'] as String?,
                    isBooked: isBooked,
                    canStart: canStart,
                    onTap: () => _onMatchCardTap(doc.id, data, isBooked, canStart),
                  );
                },
              ),
          ],
        );
      },
    );
  }
  
  // ==========================================
  // QUICK STAT WIDGET
  // ==========================================

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}