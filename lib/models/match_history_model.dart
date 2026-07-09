import 'package:cloud_firestore/cloud_firestore.dart';

/// Match history item for players
class PlayerMatchHistory {
  final String matchId;
  final DateTime matchDate;
  final String stadiumName;
  final String result; // 'win', 'loss', 'draw', 'upcoming'
  final int myTeamScore;
  final int opponentScore;
  final int myGoals;
  final int myAssists;
  final int yellowCards;
  final int redCards;
  final String? status; // For upcoming matches

  PlayerMatchHistory({
    required this.matchId,
    required this.matchDate,
    required this.stadiumName,
    required this.result,
    required this.myTeamScore,
    required this.opponentScore,
    required this.myGoals,
    required this.myAssists,
    this.yellowCards = 0,
    this.redCards = 0,
    this.status,
  });

  bool get isWin => result == 'win';
  bool get isLoss => result == 'loss';
  bool get isDraw => result == 'draw';
  bool get isUpcoming => result == 'upcoming';
  bool get hasHatTrick => myGoals >= 3;
}

/// Match history item for referees
class RefereeMatchHistory {
  final String matchId;
  final DateTime matchDate;
  final String stadiumName;
  final int teamAScore;
  final int teamBScore;
  final int totalGoals;
  final int yellowCards;
  final int redCards;
  final int totalPlayers;

  RefereeMatchHistory({
    required this.matchId,
    required this.matchDate,
    required this.stadiumName,
    required this.teamAScore,
    required this.teamBScore,
    required this.totalGoals,
    required this.yellowCards,
    required this.redCards,
    required this.totalPlayers,
  });

  factory RefereeMatchHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final teamAPlayers = (data['teamAPlayers'] as List<dynamic>?) ?? [];
    final teamBPlayers = (data['teamBPlayers'] as List<dynamic>?) ?? [];
    
    return RefereeMatchHistory(
      matchId: doc.id,
      matchDate: (data['endedAt'] as Timestamp?)?.toDate() ?? 
                (data['dateTime'] as Timestamp).toDate(),
      stadiumName: data['stadiumName'] ?? 'ملعب غير معروف',
      teamAScore: data['teamAScore'] ?? 0,
      teamBScore: data['teamBScore'] ?? 0,
      totalGoals: (data['teamAScore'] ?? 0) + (data['teamBScore'] ?? 0),
      yellowCards: data['totalYellowCards'] ?? 0,
      redCards: data['totalRedCards'] ?? 0,
      totalPlayers: teamAPlayers.length + teamBPlayers.length,
    );
  }
}