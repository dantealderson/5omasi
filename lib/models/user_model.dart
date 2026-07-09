import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  player,
  referee,
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? profileImageUrl;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Token/Balance system
  final int matchTokens; // Number of match tokens available
  final int totalTokensPurchased; // Lifetime tokens purchased
  final int totalTokensUsed; // Lifetime tokens used
  
  // Player-specific fields
  final PlayerStats? playerStats;
  final PlayerProfile? playerProfile;
  
  // Referee-specific fields
  final RefereeStats? refereeStats;
  final RefereeProfile? refereeProfile;
  
  // Common settings
  final UserSettings settings;
  final List<String> favoriteVenues;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.profileImageUrl,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.matchTokens = 0,
    this.totalTokensPurchased = 0,
    this.totalTokensUsed = 0,
    this.playerStats,
    this.playerProfile,
    this.refereeStats,
    this.refereeProfile,
    required this.settings,
    this.favoriteVenues = const [],
    this.blockedUsers = const [],
  });

  // Check if user has enough tokens
  bool hasTokens(int count) => matchTokens >= count;

  // Factory constructor from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.player,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      matchTokens: data['matchTokens'] ?? 0,
      totalTokensPurchased: data['totalTokensPurchased'] ?? 0,
      totalTokensUsed: data['totalTokensUsed'] ?? 0,
      playerStats: data['playerStats'] != null 
          ? PlayerStats.fromMap(data['playerStats']) 
          : null,
      playerProfile: data['playerProfile'] != null
          ? PlayerProfile.fromMap(data['playerProfile'])
          : null,
      refereeStats: data['refereeStats'] != null
          ? RefereeStats.fromMap(data['refereeStats'])
          : null,
      refereeProfile: data['refereeProfile'] != null
          ? RefereeProfile.fromMap(data['refereeProfile'])
          : null,
      settings: UserSettings.fromMap(data['settings'] ?? {}),
      favoriteVenues: List<String>.from(data['favoriteVenues'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'matchTokens': matchTokens,
      'totalTokensPurchased': totalTokensPurchased,
      'totalTokensUsed': totalTokensUsed,
      'playerStats': playerStats?.toMap(),
      'playerProfile': playerProfile?.toMap(),
      'refereeStats': refereeStats?.toMap(),
      'refereeProfile': refereeProfile?.toMap(),
      'settings': settings.toMap(),
      'favoriteVenues': favoriteVenues,
      'blockedUsers': blockedUsers,
    };
  }

  // CopyWith method for immutable updates
  UserModel copyWith({
    String? email,
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
    UserRole? role,
    DateTime? updatedAt,
    int? matchTokens,
    int? totalTokensPurchased,
    int? totalTokensUsed,
    PlayerStats? playerStats,
    PlayerProfile? playerProfile,
    RefereeStats? refereeStats,
    RefereeProfile? refereeProfile,
    UserSettings? settings,
    List<String>? favoriteVenues,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      matchTokens: matchTokens ?? this.matchTokens,
      totalTokensPurchased: totalTokensPurchased ?? this.totalTokensPurchased,
      totalTokensUsed: totalTokensUsed ?? this.totalTokensUsed,
      playerStats: playerStats ?? this.playerStats,
      playerProfile: playerProfile ?? this.playerProfile,
      refereeStats: refereeStats ?? this.refereeStats,
      refereeProfile: refereeProfile ?? this.refereeProfile,
      settings: settings ?? this.settings,
      favoriteVenues: favoriteVenues ?? this.favoriteVenues,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}

// ============================================
// TOKEN TRANSACTION MODEL
// ============================================

enum TokenTransactionType {
  purchase,      // Bought tokens
  matchBooking,  // Used for booking a match
  matchRefund,   // Refunded due to cancellation
  adminGrant,    // Admin gave tokens (promo, compensation)
  adminDeduct,   // Admin removed tokens
}

class TokenTransaction {
  final String id;
  final String oderId;
  final TokenTransactionType type;
  final int amount; // Positive for credit, negative for debit
  final int balanceAfter;
  final String? matchId; // If related to a match
  final String? description;
  final DateTime createdAt;

  TokenTransaction({
    required this.id,
    required this.oderId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.matchId,
    this.description,
    required this.createdAt,
  });

  factory TokenTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TokenTransaction(
      id: doc.id,
      oderId: data['oderId'] ?? '',
      type: TokenTransactionType.values.firstWhere(
        (e) => e.toString() == 'TokenTransactionType.${data['type']}',
        orElse: () => TokenTransactionType.purchase,
      ),
      amount: data['amount'] ?? 0,
      balanceAfter: data['balanceAfter'] ?? 0,
      matchId: data['matchId'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'oderId': oderId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'matchId': matchId,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// Player Statistics
class PlayerStats {
  final int totalMatches;
  final int totalGoals;
  final int totalAssists;
  final int yellowCards;
  final int redCards;
  final int wins;
  final int losses;
  final int draws;
  final int playerOfMatchAwards;
  final int hatTricks;
  final double averageRating;
  final int totalRatings;

  // Alias for playerOfMatchAwards
  int get mvpAwards => playerOfMatchAwards;

  // winRate is calculated, not stored
  double get winRate {
    if (totalMatches == 0) return 0.0;
    return (wins / totalMatches) * 100;
  }

  PlayerStats({
    this.totalMatches = 0,
    this.totalGoals = 0,
    this.totalAssists = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.playerOfMatchAwards = 0,
    this.hatTricks = 0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
  });

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      totalMatches: map['totalMatches'] ?? 0,
      totalGoals: map['totalGoals'] ?? 0,
      totalAssists: map['totalAssists'] ?? 0,
      yellowCards: map['yellowCards'] ?? 0,
      redCards: map['redCards'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      draws: map['draws'] ?? 0,
      playerOfMatchAwards: map['playerOfMatchAwards'] ?? 0,
      hatTricks: map['hatTricks'] ?? 0,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalMatches': totalMatches,
      'totalGoals': totalGoals,
      'totalAssists': totalAssists,
      'yellowCards': yellowCards,
      'redCards': redCards,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'playerOfMatchAwards': playerOfMatchAwards,
      'hatTricks': hatTricks,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
    };
  }

  PlayerStats copyWith({
    int? totalMatches,
    int? totalGoals,
    int? totalAssists,
    int? yellowCards,
    int? redCards,
    int? wins,
    int? losses,
    int? draws,
    int? playerOfMatchAwards,
    int? hatTricks,
    double? averageRating,
    int? totalRatings,
  }) {
    return PlayerStats(
      totalMatches: totalMatches ?? this.totalMatches,
      totalGoals: totalGoals ?? this.totalGoals,
      totalAssists: totalAssists ?? this.totalAssists,
      yellowCards: yellowCards ?? this.yellowCards,
      redCards: redCards ?? this.redCards,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      playerOfMatchAwards: playerOfMatchAwards ?? this.playerOfMatchAwards,
      hatTricks: hatTricks ?? this.hatTricks,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
    );
  }
}

// Player Profile
class PlayerProfile {
  final int? age;
  final String? bio;
  final DateTime memberSince;

  PlayerProfile({
    this.age,
    this.bio,
    required this.memberSince,
  });

  factory PlayerProfile.fromMap(Map<String, dynamic> map) {
    return PlayerProfile(
      age: map['age'],
      bio: map['bio'],
      memberSince: (map['memberSince'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'bio': bio,
      'memberSince': Timestamp.fromDate(memberSince),
    };
  }
}

// Referee Statistics
class RefereeStats {
  final int totalMatchesRefereed;
  final int totalGoalsRecorded;
  final int totalCardsGiven;
  final int yellowCardsGiven;
  final int redCardsGiven;
  final double averageRating;
  final int totalRatings;
  final int todayMatches;
  final int thisWeekMatches;
  final int thisMonthMatches;
  final double totalEarnings;

  RefereeStats({
    this.totalMatchesRefereed = 0,
    this.totalGoalsRecorded = 0,
    this.totalCardsGiven = 0,
    this.yellowCardsGiven = 0,
    this.redCardsGiven = 0,
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.todayMatches = 0,
    this.thisWeekMatches = 0,
    this.thisMonthMatches = 0,
    this.totalEarnings = 0.0,
  });

  factory RefereeStats.fromMap(Map<String, dynamic> map) {
    return RefereeStats(
      totalMatchesRefereed: map['totalMatchesRefereed'] ?? 0,
      totalGoalsRecorded: map['totalGoalsRecorded'] ?? 0,
      totalCardsGiven: map['totalCardsGiven'] ?? 0,
      yellowCardsGiven: map['yellowCardsGiven'] ?? 0,
      redCardsGiven: map['redCardsGiven'] ?? 0,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalRatings: map['totalRatings'] ?? 0,
      todayMatches: map['todayMatches'] ?? 0,
      thisWeekMatches: map['thisWeekMatches'] ?? 0,
      thisMonthMatches: map['thisMonthMatches'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalMatchesRefereed': totalMatchesRefereed,
      'totalGoalsRecorded': totalGoalsRecorded,
      'totalCardsGiven': totalCardsGiven,
      'yellowCardsGiven': yellowCardsGiven,
      'redCardsGiven': redCardsGiven,
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'todayMatches': todayMatches,
      'thisWeekMatches': thisWeekMatches,
      'thisMonthMatches': thisMonthMatches,
      'totalEarnings': totalEarnings,
    };
  }
}

// Referee Profile
class RefereeProfile {
  final bool availableForMatches;
  final bool instantBooking;
  final int experienceYears;
  final double pricePerMatch;
  final int maxDistanceKm;
  final List<String> preferredMatchTypes;
  final Map<String, RefereeAvailability> weeklyAvailability;
  final List<String> certifications;

  RefereeProfile({
    this.availableForMatches = true,
    this.instantBooking = false,
    this.experienceYears = 0,
    this.pricePerMatch = 25000.0,
    this.maxDistanceKm = 10,
    this.preferredMatchTypes = const ['7v7'],
    this.weeklyAvailability = const {},
    this.certifications = const [],
  });

  factory RefereeProfile.fromMap(Map<String, dynamic> map) {
    return RefereeProfile(
      availableForMatches: map['availableForMatches'] ?? true,
      instantBooking: map['instantBooking'] ?? false,
      experienceYears: map['experienceYears'] ?? 0,
      pricePerMatch: (map['pricePerMatch'] ?? 25000.0).toDouble(),
      maxDistanceKm: map['maxDistanceKm'] ?? 10,
      preferredMatchTypes: List<String>.from(map['preferredMatchTypes'] ?? ['7v7']),
      weeklyAvailability: (map['weeklyAvailability'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(
                    key,
                    RefereeAvailability.fromMap(value),
                  )) ??
          {},
      certifications: List<String>.from(map['certifications'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'availableForMatches': availableForMatches,
      'instantBooking': instantBooking,
      'experienceYears': experienceYears,
      'pricePerMatch': pricePerMatch,
      'maxDistanceKm': maxDistanceKm,
      'preferredMatchTypes': preferredMatchTypes,
      'weeklyAvailability': weeklyAvailability.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'certifications': certifications,
    };
  }
}

// Referee Availability for a day
class RefereeAvailability {
  final bool isAvailable;
  final String? startTime;
  final String? endTime;

  RefereeAvailability({
    this.isAvailable = false,
    this.startTime,
    this.endTime,
  });

  factory RefereeAvailability.fromMap(Map<String, dynamic> map) {
    return RefereeAvailability(
      isAvailable: map['isAvailable'] ?? false,
      startTime: map['startTime'],
      endTime: map['endTime'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAvailable': isAvailable,
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

// User Settings
class UserSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool locationEnabled;
  final String language;
  final bool darkModeEnabled;
  final bool autoJoinEnabled;
  final bool showProfilePublicly;

  UserSettings({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.locationEnabled = false,
    this.language = 'ar',
    this.darkModeEnabled = false,
    this.autoJoinEnabled = false,
    this.showProfilePublicly = true,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      soundEnabled: map['soundEnabled'] ?? true,
      locationEnabled: map['locationEnabled'] ?? false,
      language: map['language'] ?? 'ar',
      darkModeEnabled: map['darkModeEnabled'] ?? false,
      autoJoinEnabled: map['autoJoinEnabled'] ?? false,
      showProfilePublicly: map['showProfilePublicly'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'soundEnabled': soundEnabled,
      'locationEnabled': locationEnabled,
      'language': language,
      'darkModeEnabled': darkModeEnabled,
      'autoJoinEnabled': autoJoinEnabled,
      'showProfilePublicly': showProfilePublicly,
    };
  }

  UserSettings copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? locationEnabled,
    String? language,
    bool? darkModeEnabled,
    bool? autoJoinEnabled,
    bool? showProfilePublicly,
  }) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      language: language ?? this.language,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      autoJoinEnabled: autoJoinEnabled ?? this.autoJoinEnabled,
      showProfilePublicly: showProfilePublicly ?? this.showProfilePublicly,
    );
  }
}