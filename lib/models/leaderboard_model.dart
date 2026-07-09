import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaderboardPeriod { week, month, year, all }
enum LeaderboardType { goals, assists }

/// Individual match record for a player (for time-based leaderboard)
/// Stored in 'playerMatchRecords' collection
class PlayerMatchRecord {
  final String oderId;
  final String matchId;
  final String playerName;
  final String? photoUrl;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final String result; // 'win', 'loss', 'draw'
  final DateTime matchDate;

  PlayerMatchRecord({
    required this.oderId,
    required this.matchId,
    required this.playerName,
    this.photoUrl,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    required this.result,
    required this.matchDate,
  });

  factory PlayerMatchRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerMatchRecord(
      oderId: data['oderId'] ?? '',
      matchId: data['matchId'] ?? '',
      playerName: data['playerName'] ?? '',
      photoUrl: data['photoUrl'],
      goals: data['goals'] ?? 0,
      assists: data['assists'] ?? 0,
      yellowCards: data['yellowCards'] ?? 0,
      redCards: data['redCards'] ?? 0,
      result: data['result'] ?? 'draw',
      matchDate: (data['matchDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'oderId': oderId,
      'matchId': matchId,
      'playerName': playerName,
      'photoUrl': photoUrl,
      'goals': goals,
      'assists': assists,
      'yellowCards': yellowCards,
      'redCards': redCards,
      'result': result,
      'matchDate': Timestamp.fromDate(matchDate),
    };
  }
}

class LeaderboardEntry {
  final String oderId;
  final String playerName;
  final String? photoUrl;
  final int goals;
  final int assists;
  final int totalMatches;
  final int wins;
  final int rank;

  LeaderboardEntry({
    required this.oderId,
    required this.playerName,
    this.photoUrl,
    required this.goals,
    required this.assists,
    required this.totalMatches,
    required this.wins,
    this.rank = 0,
  });

  // Win rate as percentage
  double get winRate => totalMatches > 0 ? (wins / totalMatches) * 100 : 0;

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc, {int rank = 0}) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      oderId: doc.id,
      playerName: data['name'] ?? data['playerName'] ?? '',
      photoUrl: data['profileImageUrl'] ?? data['photoUrl'],
      goals: data['playerStats']?['totalGoals'] ?? data['goals'] ?? 0,
      assists: data['playerStats']?['totalAssists'] ?? data['assists'] ?? 0,
      totalMatches: data['playerStats']?['totalMatches'] ?? data['totalMatches'] ?? 0,
      wins: data['playerStats']?['totalWins'] ?? data['wins'] ?? 0,
      rank: rank,
    );
  }

  factory LeaderboardEntry.fromUserDoc(DocumentSnapshot doc, {int rank = 0}) {
    final data = doc.data() as Map<String, dynamic>;
    final stats = data['playerStats'] as Map<String, dynamic>? ?? {};
    
    return LeaderboardEntry(
      oderId: doc.id,
      playerName: data['name'] ?? '',
      photoUrl: data['profileImageUrl'] ?? data['photoUrl'],
      goals: stats['totalGoals'] ?? 0,
      assists: stats['totalAssists'] ?? 0,
      totalMatches: stats['totalMatches'] ?? 0,
      wins: stats['totalWins'] ?? 0,
      rank: rank,
    );
  }

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map, {int rank = 0}) {
    return LeaderboardEntry(
      oderId: map['oderId'] ?? '',
      playerName: map['playerName'] ?? '',
      photoUrl: map['photoUrl'],
      goals: map['goals'] ?? 0,
      assists: map['assists'] ?? 0,
      totalMatches: map['totalMatches'] ?? 0,
      wins: map['wins'] ?? 0,
      rank: rank,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oderId': oderId,
      'playerName': playerName,
      'photoUrl': photoUrl,
      'goals': goals,
      'assists': assists,
      'totalMatches': totalMatches,
      'wins': wins,
    };
  }

  LeaderboardEntry copyWith({
    String? oderId,
    String? playerName,
    String? photoUrl,
    int? goals,
    int? assists,
    int? totalMatches,
    int? wins,
    int? rank,
  }) {
    return LeaderboardEntry(
      oderId: oderId ?? this.oderId,
      playerName: playerName ?? this.playerName,
      photoUrl: photoUrl ?? this.photoUrl,
      goals: goals ?? this.goals,
      assists: assists ?? this.assists,
      totalMatches: totalMatches ?? this.totalMatches,
      wins: wins ?? this.wins,
      rank: rank ?? this.rank,
    );
  }
}

/// Aggregated leaderboard document (stored in 'leaderboard' collection)
/// Updated periodically by Cloud Functions or batch jobs
class LeaderboardDocument {
  final String id; // 'weekly', 'monthly', 'allTime'
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> topGoalScorers;
  final List<LeaderboardEntry> topAssistMakers;
  final DateTime lastUpdated;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  LeaderboardDocument({
    required this.id,
    required this.period,
    required this.topGoalScorers,
    required this.topAssistMakers,
    required this.lastUpdated,
    this.periodStart,
    this.periodEnd,
  });

  factory LeaderboardDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return LeaderboardDocument(
      id: doc.id,
      period: LeaderboardPeriod.values.firstWhere(
        (e) => e.name == data['period'],
        orElse: () => LeaderboardPeriod.all,
      ),
      topGoalScorers: (data['topGoalScorers'] as List<dynamic>?)
          ?.asMap()
          .entries
          .map((e) => LeaderboardEntry.fromMap(e.value as Map<String, dynamic>, rank: e.key + 1))
          .toList() ?? [],
      topAssistMakers: (data['topAssistMakers'] as List<dynamic>?)
          ?.asMap()
          .entries
          .map((e) => LeaderboardEntry.fromMap(e.value as Map<String, dynamic>, rank: e.key + 1))
          .toList() ?? [],
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodStart: (data['periodStart'] as Timestamp?)?.toDate(),
      periodEnd: (data['periodEnd'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'period': period.name,
      'topGoalScorers': topGoalScorers.map((e) => e.toMap()).toList(),
      'topAssistMakers': topAssistMakers.map((e) => e.toMap()).toList(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'periodStart': periodStart != null ? Timestamp.fromDate(periodStart!) : null,
      'periodEnd': periodEnd != null ? Timestamp.fromDate(periodEnd!) : null,
    };
  }
}