import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/match_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/models/match_model.dart';
import 'package:khomasi/components/match_card.dart';
import 'package:khomasi/pages/booking_page.dart';
import 'package:khomasi/services/location_service.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  bool _isSearching = false;
  Map<String, double> _matchDistances = {};
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final matchProvider = Provider.of<MatchProvider>(context, listen: false);

      if (userProvider.userId.isNotEmpty) {
        matchProvider.initForPlayer(userProvider.userId);
      }
      _loadUserLocation();
    });
  }

  Future<void> _loadUserLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null && mounted) {
      setState(() => _locationLoaded = true);
    }
  }

  void _calculateDistances(List<MatchModel> matches) {
    if (!_locationLoaded) return;

    for (final match in matches) {
      if (match.location != null && !_matchDistances.containsKey(match.id)) {
        final distance = LocationService.getDistanceFromCached(match.location!);
        if (distance != null) {
          _matchDistances[match.id] = distance;
        }
      }
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final matchProvider = Provider.of<MatchProvider>(context, listen: false);
    switch (_tabController.index) {
      case 0: matchProvider.setFilter('all'); break;
      case 1: matchProvider.setFilter('today'); break;
      case 2: matchProvider.setFilter('tomorrow'); break;
      case 3: matchProvider.setFilter('week'); break;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final matchProvider = Provider.of<MatchProvider>(context, listen: false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && value == _searchController.text) {
        matchProvider.setSearchQuery(value);
      }
    });
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (matchDate == today) return tr(context, 'today');
    if (matchDate == tomorrow) return tr(context, 'tomorrow');
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime, int durationMinutes) {
    final endTime = dateTime.add(Duration(minutes: durationMinutes));
    final startStr = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$startStr - $endStr';
  }

  String _getSurfaceTypeText(SurfaceType type) {
    switch (type) {
      case SurfaceType.natural: return tr(context, 'naturalGrass');
      case SurfaceType.artificial: return tr(context, 'artificialGrass');
      case SurfaceType.indoor: return tr(context, 'indoorStadium');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matchProvider = Provider.of<MatchProvider>(context);
    final matches = matchProvider.filteredMatches;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Fixed header: search + tabs
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onTap: () => setState(() => _isSearching = true),
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: tr(context, 'searchStadiumOrArea'),
                      prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                });
                                Provider.of<MatchProvider>(context, listen: false).setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                  indicatorColor: Colors.deepPurple,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: [
                    Tab(text: tr(context, 'all')),
                    Tab(text: tr(context, 'today')),
                    Tab(text: tr(context, 'tomorrow')),
                    Tab(text: tr(context, 'thisWeek')),
                  ],
                  onTap: (index) => HapticFeedback.selectionClick(),
                ),
              ],
            ),
          ),

          // Show full matches toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text(tr(context, 'showFullMatches')),
                  selected: matchProvider.showFullMatches,
                  selectedColor: Colors.deepPurple.withOpacity(0.2),
                  checkmarkColor: Colors.deepPurple,
                  onSelected: (_) => matchProvider.toggleShowFullMatches(),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: matchProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
                : RefreshIndicator(
                    onRefresh: () => matchProvider.refreshMatches(),
                    color: Colors.deepPurple,
                    child: matches.isEmpty
                        ? _buildEmptyState()
                        : _buildMatchList(matches),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_soccer, size: 100, color: Theme.of(context).dividerColor),
              const SizedBox(height: 16),
              Text(
                tr(context, 'noMatchesAvailable'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty ? tr(context, 'tryDifferentSearch') : tr(context, 'pullToRefresh'),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchList(List<MatchModel> matches) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    _calculateDistances(matches);

    // Deduplicate by match ID
    final seen = <String>{};
    final uniqueMatches = matches.where((m) => seen.add(m.id)).toList();

    // Separate booked and other matches
    final bookedMatches = uniqueMatches.where((m) => m.isUserBooked(userId)).toList();
    final otherMatches = uniqueMatches.where((m) => !m.isUserBooked(userId)).toList();

    bookedMatches.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    otherMatches.sort((a, b) {
      final distA = _matchDistances[a.id];
      final distB = _matchDistances[b.id];

      if (distA != null && distB != null) {
        final distCompare = distA.compareTo(distB);
        if (distCompare != 0) return distCompare;
      }
      if (distA != null && distB == null) return -1;
      if (distA == null && distB != null) return 1;

      return a.dateTime.compareTo(b.dateTime);
    });

    final sortedMatches = [...bookedMatches, ...otherMatches];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80, top: 16),
      child: Column(
        children: [
          for (int index = 0; index < sortedMatches.length; index++)
            MatchCard(
              index: index,
              venue: sortedMatches[index].stadiumName,
              date: _formatDate(sortedMatches[index].dateTime),
              time: _formatTime(sortedMatches[index].dateTime, sortedMatches[index].durationMinutes),
              price: sortedMatches[index].pricePerPlayer,
              currentPlayers: sortedMatches[index].currentPlayers,
              maxPlayers: sortedMatches[index].maxPlayers,
              surfaceType: _getSurfaceTypeText(sortedMatches[index].surfaceType),
              imageUrl: sortedMatches[index].pitchImageUrl,
              isBooked: sortedMatches[index].isUserBooked(userId),
              matchDateTime: sortedMatches[index].dateTime,
              distance: _matchDistances[sortedMatches[index].id] != null
                  ? double.parse(_matchDistances[sortedMatches[index].id]!.toStringAsFixed(1))
                  : null,
              isFavorite: false,
              onFavorite: () {},
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookingPage(match: sortedMatches[index])));
              },
            ),
        ],
      ),
    );
  }
}
