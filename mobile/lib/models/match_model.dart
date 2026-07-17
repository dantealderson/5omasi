import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// ENUMS
// ==========================================

enum MatchStatus {
  open,        // Available for players to join
  full,        // All player spots taken, waiting for referee
  scheduled,   // Referee assigned, waiting for match time
  inProgress,  // Currently being played
  completed,   // Match finished
  cancelled,   // Match was cancelled
}

enum SurfaceType { natural, artificial, indoor }

// ==========================================
// MATCH PLAYER MODEL
// ==========================================

class MatchPlayer {
  final String oderId;
  final String playerName;
  final int playerNumber;
  final String team; // 'A' or 'B'
  final bool isGuest; // Guest players don't get stats saved
  final String? bookedByUserId; // If guest, who booked them
  int goals;
  int assists;
  int yellowCards;
  bool hasRedCard;
  DateTime? redCardTime;
  final DateTime joinedAt;

  MatchPlayer({
    required this.oderId,
    required this.playerName,
    required this.playerNumber,
    required this.team,
    this.isGuest = false,
    this.bookedByUserId,
    this.goals = 0,
    this.assists = 0,
    this.yellowCards = 0,
    this.hasRedCard = false,
    this.redCardTime,
    required this.joinedAt,
  });

  factory MatchPlayer.fromMap(Map<String, dynamic> map) {
    return MatchPlayer(
      oderId: map['oderId'] ?? '',
      playerName: map['playerName'] ?? '',
      playerNumber: map['playerNumber'] ?? 0,
      team: map['team'] ?? 'A',
      isGuest: map['isGuest'] ?? false,
      bookedByUserId: map['bookedByUserId'],
      goals: map['goals'] ?? 0,
      assists: map['assists'] ?? 0,
      yellowCards: map['yellowCards'] ?? 0,
      hasRedCard: map['hasRedCard'] ?? false,
      redCardTime: map['redCardTime'] != null
          ? (map['redCardTime'] as Timestamp).toDate()
          : null,
      joinedAt: map['joinedAt'] != null
          ? (map['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oderId': oderId,
      'playerName': playerName,
      'playerNumber': playerNumber,
      'team': team,
      'isGuest': isGuest,
      'bookedByUserId': bookedByUserId,
      'goals': goals,
      'assists': assists,
      'yellowCards': yellowCards,
      'hasRedCard': hasRedCard,
      'redCardTime': redCardTime != null ? Timestamp.fromDate(redCardTime!) : null,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  MatchPlayer copyWith({
    String? oderId,
    String? playerName,
    int? playerNumber,
    String? team,
    bool? isGuest,
    String? bookedByUserId,
    int? goals,
    int? assists,
    int? yellowCards,
    bool? hasRedCard,
    DateTime? redCardTime,
    DateTime? joinedAt,
  }) {
    return MatchPlayer(
      oderId: oderId ?? this.oderId,
      playerName: playerName ?? this.playerName,
      playerNumber: playerNumber ?? this.playerNumber,
      team: team ?? this.team,
      isGuest: isGuest ?? this.isGuest,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      yellowCards: yellowCards ?? this.yellowCards,
      hasRedCard: hasRedCard ?? this.hasRedCard,
      redCardTime: redCardTime ?? this.redCardTime,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

// ==========================================
// MATCH MODEL
// ==========================================

class MatchModel {
  final String id;
  final String stadiumId;
  final String stadiumName;
  final String? stadiumAddress;
  final String? googleMapsUrl; // Direct Google Maps link to stadium
  final String? locationText; // Text description of location
  final String? pitchImageUrl;
  final DateTime dateTime;
  final int durationMinutes;
  final double pricePerPlayer;
  final int maxPlayers;
  final int currentPlayers;
  final MatchStatus status;
  final SurfaceType surfaceType;
  final String? refereeId;
  final String? refereeName;
  final String? createdBy;
  final DateTime createdAt;
  final GeoPoint? location;
  
  // Team info
  final String teamAName;
  final String teamBName;
  final List<MatchPlayer> teamAPlayers;
  final List<MatchPlayer> teamBPlayers;
  
  // Live match data
  final int teamAScore;
  final int teamBScore;
  final int totalYellowCards;
  final int totalRedCards;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? matchDurationSeconds; // Actual played time

  MatchModel({
    required this.id,
    required this.stadiumId,
    required this.stadiumName,
    this.stadiumAddress,
    this.googleMapsUrl,
    this.locationText,
    this.pitchImageUrl,
    required this.dateTime,
    this.durationMinutes = 60,
    required this.pricePerPlayer,
    this.maxPlayers = 10,
    this.currentPlayers = 0,
    this.status = MatchStatus.open,
    required this.surfaceType,
    this.refereeId,
    this.refereeName,
    this.createdBy,
    required this.createdAt,
    this.location,
    this.teamAName = 'الفريق الأزرق',
    this.teamBName = 'الفريق الأحمر',
    this.teamAPlayers = const [],
    this.teamBPlayers = const [],
    this.teamAScore = 0,
    this.teamBScore = 0,
    this.totalYellowCards = 0,
    this.totalRedCards = 0,
    this.startedAt,
    this.endedAt,
    this.matchDurationSeconds,
  });

  // Computed properties
  bool get isFull => currentPlayers >= maxPlayers;
  bool get isFillingFast => currentPlayers >= (maxPlayers * 0.8);
  bool get needsReferee => status == MatchStatus.full && refereeId == null;
  bool get isLive => status == MatchStatus.inProgress;
  bool get canJoin => status == MatchStatus.open && !isFull;
  int get spotsLeft => maxPlayers - currentPlayers;
  
  List<MatchPlayer> get allPlayers => [...teamAPlayers, ...teamBPlayers];
  
  /// Check if a user is booked in this match
  bool isUserBooked(String oderId) {
    return allPlayers.any((p) => p.oderId == oderId && !p.isGuest);
  }

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      stadiumId: data['stadiumId'] ?? '',
      stadiumName: data['stadiumName'] ?? '',
      stadiumAddress: data['stadiumAddress'],
      googleMapsUrl: data['googleMapsUrl'],
      locationText: data['locationText'],
      pitchImageUrl: data['pitchImageUrl'] ?? data['stadiumImage'],
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      durationMinutes: data['durationMinutes'] ?? 60,
      pricePerPlayer: (data['pricePerPlayer'] ?? 0).toDouble(),
      maxPlayers: data['maxPlayers'] ?? 10,
      currentPlayers: data['currentPlayers'] ?? 0,
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MatchStatus.open,
      ),
      surfaceType: SurfaceType.values.firstWhere(
        (e) => e.name == data['surfaceType'],
        orElse: () => SurfaceType.artificial,
      ),
      refereeId: data['refereeId'],
      refereeName: data['refereeName'],
      createdBy: data['createdBy'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      location: data['location'] is GeoPoint ? data['location'] : null,
      teamAName: data['teamAName'] ?? 'الفريق الأزرق',
      teamBName: data['teamBName'] ?? 'الفريق الأحمر',
      teamAPlayers: (data['teamAPlayers'] as List<dynamic>?)
              ?.map((p) => MatchPlayer.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      teamBPlayers: (data['teamBPlayers'] as List<dynamic>?)
              ?.map((p) => MatchPlayer.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      teamAScore: data['teamAScore'] ?? 0,
      teamBScore: data['teamBScore'] ?? 0,
      totalYellowCards: data['totalYellowCards'] ?? 0,
      totalRedCards: data['totalRedCards'] ?? 0,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      matchDurationSeconds: data['matchDurationSeconds'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stadiumId': stadiumId,
      'stadiumName': stadiumName,
      'stadiumAddress': stadiumAddress,
      'googleMapsUrl': googleMapsUrl,
      'locationText': locationText,
      'pitchImageUrl': pitchImageUrl,
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': durationMinutes,
      'pricePerPlayer': pricePerPlayer,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'status': status.name,
      'surfaceType': surfaceType.name,
      'refereeId': refereeId,
      'refereeName': refereeName,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'location': location,
      'teamAName': teamAName,
      'teamBName': teamBName,
      'teamAPlayers': teamAPlayers.map((p) => p.toMap()).toList(),
      'teamBPlayers': teamBPlayers.map((p) => p.toMap()).toList(),
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'totalYellowCards': totalYellowCards,
      'totalRedCards': totalRedCards,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'matchDurationSeconds': matchDurationSeconds,
    };
  }

  MatchModel copyWith({
    String? id,
    String? stadiumId,
    String? stadiumName,
    String? stadiumAddress,
    String? googleMapsUrl,
    String? locationText,
    String? pitchImageUrl,
    DateTime? dateTime,
    int? durationMinutes,
    double? pricePerPlayer,
    int? maxPlayers,
    int? currentPlayers,
    MatchStatus? status,
    SurfaceType? surfaceType,
    String? refereeId,
    String? refereeName,
    String? createdBy,
    DateTime? createdAt,
    GeoPoint? location,
    String? teamAName,
    String? teamBName,
    List<MatchPlayer>? teamAPlayers,
    List<MatchPlayer>? teamBPlayers,
    int? teamAScore,
    int? teamBScore,
    int? totalYellowCards,
    int? totalRedCards,
    DateTime? startedAt,
    DateTime? endedAt,
    int? matchDurationSeconds,
  }) {
    return MatchModel(
      id: id ?? this.id,
      stadiumId: stadiumId ?? this.stadiumId,
      stadiumName: stadiumName ?? this.stadiumName,
      stadiumAddress: stadiumAddress ?? this.stadiumAddress,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      locationText: locationText ?? this.locationText,
      pitchImageUrl: pitchImageUrl ?? this.pitchImageUrl,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      pricePerPlayer: pricePerPlayer ?? this.pricePerPlayer,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      currentPlayers: currentPlayers ?? this.currentPlayers,
      status: status ?? this.status,
      surfaceType: surfaceType ?? this.surfaceType,
      refereeId: refereeId ?? this.refereeId,
      refereeName: refereeName ?? this.refereeName,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      teamAPlayers: teamAPlayers ?? this.teamAPlayers,
      teamBPlayers: teamBPlayers ?? this.teamBPlayers,
      teamAScore: teamAScore ?? this.teamAScore,
      teamBScore: teamBScore ?? this.teamBScore,
      totalYellowCards: totalYellowCards ?? this.totalYellowCards,
      totalRedCards: totalRedCards ?? this.totalRedCards,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      matchDurationSeconds: matchDurationSeconds ?? this.matchDurationSeconds,
    );
  }
}