import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match_model.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'matches';

  // ==========================================
  // PLAYER-SIDE METHODS (Browsing & Joining)
  // ==========================================

  /// Get all matches available for viewing (open, full, scheduled)
  /// Full/scheduled matches are shown only to users booked in them (filtered in UI)
  Future<List<MatchModel>> getAvailableMatches() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', whereIn: ['open', 'full', 'scheduled'])
          .get();
      
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => MatchModel.fromFirestore(doc))
          .where((match) => match.dateTime.isAfter(now))
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      print('❌ Error fetching matches: $e');
      return [];
    }
  }

  /// Get matches filtered by date
  Future<List<MatchModel>> getMatchesByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final snapshot = await _firestore
        .collection(_collection)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThan: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: [MatchStatus.open.name, MatchStatus.full.name])
        .orderBy('dateTime')
        .get();
    return snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
  }

  /// Get matches for today
  Future<List<MatchModel>> getTodayMatches() async {
    return getMatchesByDate(DateTime.now());
  }

  /// Get matches for tomorrow
  Future<List<MatchModel>> getTomorrowMatches() async {
    return getMatchesByDate(DateTime.now().add(const Duration(days: 1)));
  }

  /// Get matches for this week
  Future<List<MatchModel>> getThisWeekMatches() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfDay.add(const Duration(days: 7));
    
    final snapshot = await _firestore
        .collection(_collection)
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThan: Timestamp.fromDate(endOfWeek))
        .where('status', whereIn: [MatchStatus.open.name, MatchStatus.full.name])
        .orderBy('dateTime')
        .get();
    return snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
  }

  /// Search matches by stadium name
  Future<List<MatchModel>> searchMatches(String query) async {
    final matches = await getAvailableMatches();
    final lowerQuery = query.toLowerCase();
    return matches.where((m) => 
        m.stadiumName.toLowerCase().contains(lowerQuery) ||
        (m.stadiumAddress?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  /// Get match by ID
  Future<MatchModel?> getMatchById(String matchId) async {
    final doc = await _firestore.collection(_collection).doc(matchId).get();
    if (!doc.exists) return null;
    return MatchModel.fromFirestore(doc);
  }

  /// Stream a single match (for live updates)
  Stream<MatchModel?> streamMatch(String matchId) {
    return _firestore
        .collection(_collection)
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.exists ? MatchModel.fromFirestore(doc) : null);
  }

  /// Stream available matches
  Stream<List<MatchModel>> streamAvailableMatches() {
    return _firestore
        .collection(_collection)
        .where('status', whereIn: ['open', 'full', 'scheduled'])
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .where((match) => match.dateTime.isAfter(now))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        });
  }

  /// Join a match as a player (single spot)
  Future<bool> joinMatch({
    required String matchId,
    required String oderId,
    required String playerName,
    required String team,
  }) async {
    return joinMatchMultiple(
      matchId: matchId,
      oderId: oderId,
      playerName: playerName,
      team: team,
      count: 1,
    );
  }

  /// Join a match with multiple spots (for booking multiple places)
  /// First player is the actual user, rest are guests (isGuest: true)
  Future<bool> joinMatchMultiple({
    required String matchId,
    required String oderId,
    required String playerName,
    required String team,
    required int count,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Check if match is still open
        if (match.status != MatchStatus.open) return false;
        
        // Check if already joined
        final alreadyJoined = match.allPlayers.any((p) => p.oderId == oderId);
        if (alreadyJoined) return false;
        
        // Check team capacity
        final teamPlayers = team == 'A' ? match.teamAPlayers : match.teamBPlayers;
        final maxPerTeam = match.maxPlayers ~/ 2;
        final availableInTeam = maxPerTeam - teamPlayers.length;
        
        if (count > availableInTeam) return false;
        
        // Check total available spots
        if (count > match.spotsLeft) return false;
        
        // Create new players
        final newPlayers = <MatchPlayer>[];
        for (int i = 0; i < count; i++) {
          final isGuest = i > 0; // First player is real user, rest are guests
          newPlayers.add(MatchPlayer(
            oderId: isGuest ? '${oderId}_guest_$i' : oderId,
            playerName: isGuest ? '$playerName (ضيف $i)' : playerName,
            playerNumber: teamPlayers.length + i + 1 + (team == 'B' ? maxPerTeam : 0),
            team: team,
            isGuest: isGuest,
            bookedByUserId: isGuest ? oderId : null, // Track who booked the guest
            joinedAt: DateTime.now(),
          ));
        }
        
        // Update match
        final newCurrentPlayers = match.currentPlayers + count;
        final newStatus = newCurrentPlayers >= match.maxPlayers 
            ? MatchStatus.full 
            : MatchStatus.open;
        
        final updateData = {
          'currentPlayers': newCurrentPlayers,
          'status': newStatus.name,
        };
        
        if (team == 'A') {
          updateData['teamAPlayers'] = [
            ...match.teamAPlayers.map((p) => p.toMap()), 
            ...newPlayers.map((p) => p.toMap())
          ];
        } else {
          updateData['teamBPlayers'] = [
            ...match.teamBPlayers.map((p) => p.toMap()), 
            ...newPlayers.map((p) => p.toMap())
          ];
        }
        
        transaction.update(matchRef, updateData);
        return true;
      });
    } catch (e) {
      print('Error joining match: $e');
      return false;
    }
  }

  /// Add guests to a match for an already booked user
  Future<bool> addGuestsToMatch({
    required String matchId,
    required String bookedByUserId,
    required String playerName,
    required String team,
    required int count,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Check if match is still open
        if (match.status != MatchStatus.open) return false;
        
        // Check team capacity
        final teamPlayers = team == 'A' ? match.teamAPlayers : match.teamBPlayers;
        final maxPerTeam = match.maxPlayers ~/ 2;
        final availableInTeam = maxPerTeam - teamPlayers.length;
        
        if (count > availableInTeam) return false;
        
        // Check total available spots
        if (count > match.spotsLeft) return false;
        
        // Count existing guests from this user
        final existingGuestCount = match.allPlayers.where(
          (p) => p.bookedByUserId == bookedByUserId
        ).length;
        
        // Create new guest players
        final newPlayers = <MatchPlayer>[];
        for (int i = 0; i < count; i++) {
          final guestIndex = existingGuestCount + i + 1;
          newPlayers.add(MatchPlayer(
            oderId: '${bookedByUserId}_guest_$guestIndex',
            playerName: '$playerName (ضيف $guestIndex)',
            playerNumber: teamPlayers.length + i + 1 + (team == 'B' ? maxPerTeam : 0),
            team: team,
            isGuest: true,
            bookedByUserId: bookedByUserId,
            joinedAt: DateTime.now(),
          ));
        }
        
        // Update match
        final newCurrentPlayers = match.currentPlayers + count;
        final newStatus = newCurrentPlayers >= match.maxPlayers 
            ? MatchStatus.full 
            : MatchStatus.open;
        
        final updateData = {
          'currentPlayers': newCurrentPlayers,
          'status': newStatus.name,
        };
        
        if (team == 'A') {
          updateData['teamAPlayers'] = [
            ...match.teamAPlayers.map((p) => p.toMap()), 
            ...newPlayers.map((p) => p.toMap())
          ];
        } else {
          updateData['teamBPlayers'] = [
            ...match.teamBPlayers.map((p) => p.toMap()), 
            ...newPlayers.map((p) => p.toMap())
          ];
        }
        
        transaction.update(matchRef, updateData);
        return true;
      });
    } catch (e) {
      print('Error adding guests: $e');
      return false;
    }
  }

  /// Leave a match (before it starts) - also removes guests booked by user
  Future<bool> leaveMatch({
    required String matchId,
    required String oderId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Can't leave if match started
        if (match.status == MatchStatus.inProgress || 
            match.status == MatchStatus.completed) return false;
        
        // Find player and their guests in both teams
        final inTeamA = match.teamAPlayers.any((p) => p.oderId == oderId);
        final inTeamB = match.teamBPlayers.any((p) => p.oderId == oderId);
        
        if (!inTeamA && !inTeamB) return false;
        
        // Count how many spots to remove (user + their guests)
        final spotsToRemoveA = match.teamAPlayers.where((p) => 
          p.oderId == oderId || p.bookedByUserId == oderId
        ).length;
        final spotsToRemoveB = match.teamBPlayers.where((p) => 
          p.oderId == oderId || p.bookedByUserId == oderId
        ).length;
        final totalSpotsToRemove = spotsToRemoveA + spotsToRemoveB;
        
        final newCurrentPlayers = match.currentPlayers - totalSpotsToRemove;
        final newStatus = match.status == MatchStatus.full 
            ? MatchStatus.open 
            : match.status;
        
        // Remove user and their guests from both teams
        final newTeamAPlayers = match.teamAPlayers
            .where((p) => p.oderId != oderId && p.bookedByUserId != oderId)
            .map((p) => p.toMap())
            .toList();
        
        final newTeamBPlayers = match.teamBPlayers
            .where((p) => p.oderId != oderId && p.bookedByUserId != oderId)
            .map((p) => p.toMap())
            .toList();
        
        final updateData = <String, dynamic>{
          'currentPlayers': newCurrentPlayers,
          'status': newStatus.name,
          'teamAPlayers': newTeamAPlayers,
          'teamBPlayers': newTeamBPlayers,
        };
        
        transaction.update(matchRef, updateData);
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Get matches the user has joined
  Future<List<MatchModel>> getUserMatches(String oderId) async {
    // Get all non-completed matches and filter client-side
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', whereIn: [
          MatchStatus.open.name,
          MatchStatus.full.name,
          MatchStatus.scheduled.name,
          MatchStatus.inProgress.name,
        ])
        .get();
    
    return snapshot.docs
        .map((doc) => MatchModel.fromFirestore(doc))
        .where((match) => match.allPlayers.any((p) => p.oderId == oderId))
        .toList();
  }

  /// Get user's upcoming matches
  Future<List<MatchModel>> getUserUpcomingMatches(String oderId) async {
    final matches = await getUserMatches(oderId);
    return matches.where((m) => m.dateTime.isAfter(DateTime.now())).toList();
  }

  // ==========================================
  // REFEREE-SIDE METHODS
  // ==========================================

  /// Get matches waiting for a referee
  Stream<List<MatchModel>> streamMatchesNeedingReferee() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: MatchStatus.full.name)
        .where('refereeId', isNull: true)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList());
  }

  /// Get matches needing referee (non-stream)
  Future<List<MatchModel>> getMatchesNeedingReferee() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: MatchStatus.full.name)
        .where('refereeId', isNull: true)
        .where('dateTime', isGreaterThan: Timestamp.now())
        .orderBy('dateTime')
        .get();
    return snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
  }

  /// Referee assigns themselves to a match
  Future<bool> assignReferee({
    required String matchId,
    required String refereeId,
    required String refereeName,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Check if already has a referee
        if (match.refereeId != null) return false;
        
        transaction.update(matchRef, {
          'refereeId': refereeId,
          'refereeName': refereeName,
          'status': MatchStatus.scheduled.name,
        });
        
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Referee unassigns from a match (before it starts)
  Future<bool> unassignReferee({
    required String matchId,
    required String refereeId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Verify this referee is assigned
        if (match.refereeId != refereeId) return false;
        
        // Can't unassign if match started
        if (match.status == MatchStatus.inProgress) return false;
        
        transaction.update(matchRef, {
          'refereeId': null,
          'refereeName': null,
          'status': MatchStatus.full.name,
        });
        
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Get referee's assigned matches
  Future<List<MatchModel>> getRefereeMatches(String refereeId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('refereeId', isEqualTo: refereeId)
        .where('status', whereIn: [
          MatchStatus.scheduled.name,
          MatchStatus.inProgress.name,
        ])
        .orderBy('dateTime')
        .get();
    return snapshot.docs.map((doc) => MatchModel.fromFirestore(doc)).toList();
  }

  /// Stream referee's active match
  Stream<MatchModel?> streamRefereeActiveMatch(String refereeId) {
    return _firestore
        .collection(_collection)
        .where('refereeId', isEqualTo: refereeId)
        .where('status', isEqualTo: MatchStatus.inProgress.name)
        .limit(1)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.isEmpty ? null : MatchModel.fromFirestore(snapshot.docs.first));
  }

  // ==========================================
  // LIVE MATCH METHODS (Referee Controls)
  // ==========================================

  /// Start a match
  Future<bool> startMatch(String matchId) async {
    try {
      await _firestore.collection(_collection).doc(matchId).update({
        'status': MatchStatus.inProgress.name,
        'startedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// End a match
  Future<bool> endMatch({
    required String matchId,
    required int matchDurationSeconds,
  }) async {
    try {
      final matchRef = _firestore.collection(_collection).doc(matchId);
      final matchDoc = await matchRef.get();
      
      if (!matchDoc.exists) return false;
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      // Update match status
      await matchRef.update({
        'status': MatchStatus.completed.name,
        'endedAt': FieldValue.serverTimestamp(),
        'matchDurationSeconds': matchDurationSeconds,
      });
      
      // Create match history records for each player
      final batch = _firestore.batch();
      
      for (final player in match.allPlayers) {
        final historyRef = _firestore.collection('matchHistory').doc();
        batch.set(historyRef, {
          'oderId': player.oderId,
          'matchId': matchId,
          'stadiumName': match.stadiumName,
          'date': match.dateTime,
          'teamAScore': match.teamAScore,
          'teamBScore': match.teamBScore,
          'team': player.team,
          'myGoals': player.goals,
          'myAssists': player.assists,
          'yellowCards': player.yellowCards,
          'gotRedCard': player.hasRedCard,
          'result': _getMatchResult(player.team, match.teamAScore, match.teamBScore),
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Update player stats in users collection
        final userRef = _firestore.collection('users').doc(player.oderId);
        batch.update(userRef, {
          'playerStats.totalMatches': FieldValue.increment(1),
          'playerStats.totalGoals': FieldValue.increment(player.goals),
          'playerStats.totalAssists': FieldValue.increment(player.assists),
          if (_getMatchResult(player.team, match.teamAScore, match.teamBScore) == 'won')
            'playerStats.totalWins': FieldValue.increment(1),
        });
      }
      
      // Update referee stats
      if (match.refereeId != null) {
        final refereeRef = _firestore.collection('users').doc(match.refereeId);
        batch.update(refereeRef, {
          'refereeStats.totalMatches': FieldValue.increment(1),
          'refereeStats.totalGoalsRecorded': FieldValue.increment(match.teamAScore + match.teamBScore),
          'refereeStats.totalCardsGiven': FieldValue.increment(match.totalYellowCards + match.totalRedCards),
        });
      }
      
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _getMatchResult(String team, int teamAScore, int teamBScore) {
    if (teamAScore == teamBScore) return 'draw';
    if (team == 'A') {
      return teamAScore > teamBScore ? 'won' : 'lost';
    } else {
      return teamBScore > teamAScore ? 'won' : 'lost';
    }
  }

  /// Record a goal
  Future<bool> recordGoal({
    required String matchId,
    required String oderId,
    required String team,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Find player and update goals
        final teamPlayers = team == 'A' ? match.teamAPlayers : match.teamBPlayers;
        final playerIndex = teamPlayers.indexWhere((p) => p.oderId == oderId);
        
        if (playerIndex == -1) return false;
        
        teamPlayers[playerIndex].goals++;
        
        final updateData = <String, dynamic>{
          team == 'A' ? 'teamAScore' : 'teamBScore': FieldValue.increment(1),
          team == 'A' ? 'teamAPlayers' : 'teamBPlayers': 
              teamPlayers.map((p) => p.toMap()).toList(),
        };
        
        transaction.update(matchRef, updateData);
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Record an assist
  Future<bool> recordAssist({
    required String matchId,
    required String oderId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Find player in either team
        var playerIndex = match.teamAPlayers.indexWhere((p) => p.oderId == oderId);
        final isTeamA = playerIndex != -1;
        
        if (!isTeamA) {
          playerIndex = match.teamBPlayers.indexWhere((p) => p.oderId == oderId);
        }
        
        if (playerIndex == -1) return false;
        
        final teamPlayers = isTeamA ? match.teamAPlayers : match.teamBPlayers;
        teamPlayers[playerIndex].assists++;
        
        transaction.update(matchRef, {
          isTeamA ? 'teamAPlayers' : 'teamBPlayers': 
              teamPlayers.map((p) => p.toMap()).toList(),
        });
        
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Give yellow card
  Future<bool> giveYellowCard({
    required String matchId,
    required String oderId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Find player
        var playerIndex = match.teamAPlayers.indexWhere((p) => p.oderId == oderId);
        final isTeamA = playerIndex != -1;
        
        if (!isTeamA) {
          playerIndex = match.teamBPlayers.indexWhere((p) => p.oderId == oderId);
        }
        
        if (playerIndex == -1) return false;
        
        final teamPlayers = isTeamA ? match.teamAPlayers : match.teamBPlayers;
        teamPlayers[playerIndex].yellowCards++;
        
        // Check for automatic red card (2 yellows)
        final shouldGiveRed = teamPlayers[playerIndex].yellowCards >= 2;
        if (shouldGiveRed) {
          teamPlayers[playerIndex].hasRedCard = true;
          teamPlayers[playerIndex].redCardTime = DateTime.now();
        }
        
        final updateData = <String, dynamic>{
          isTeamA ? 'teamAPlayers' : 'teamBPlayers': 
              teamPlayers.map((p) => p.toMap()).toList(),
          'totalYellowCards': FieldValue.increment(1),
        };
        
        if (shouldGiveRed) {
          updateData['totalRedCards'] = FieldValue.increment(1);
        }
        
        transaction.update(matchRef, updateData);
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Give red card
  Future<bool> giveRedCard({
    required String matchId,
    required String oderId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Find player
        var playerIndex = match.teamAPlayers.indexWhere((p) => p.oderId == oderId);
        final isTeamA = playerIndex != -1;
        
        if (!isTeamA) {
          playerIndex = match.teamBPlayers.indexWhere((p) => p.oderId == oderId);
        }
        
        if (playerIndex == -1) return false;
        
        final teamPlayers = isTeamA ? match.teamAPlayers : match.teamBPlayers;
        teamPlayers[playerIndex].hasRedCard = true;
        teamPlayers[playerIndex].redCardTime = DateTime.now();
        
        transaction.update(matchRef, {
          isTeamA ? 'teamAPlayers' : 'teamBPlayers': 
              teamPlayers.map((p) => p.toMap()).toList(),
          'totalRedCards': FieldValue.increment(1),
        });
        
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Remove red card (after timeout)
  Future<bool> removeRedCard({
    required String matchId,
    required String oderId,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final matchRef = _firestore.collection(_collection).doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        
        if (!matchDoc.exists) return false;
        
        final match = MatchModel.fromFirestore(matchDoc);
        
        // Find player
        var playerIndex = match.teamAPlayers.indexWhere((p) => p.oderId == oderId);
        final isTeamA = playerIndex != -1;
        
        if (!isTeamA) {
          playerIndex = match.teamBPlayers.indexWhere((p) => p.oderId == oderId);
        }
        
        if (playerIndex == -1) return false;
        
        final teamPlayers = isTeamA ? match.teamAPlayers : match.teamBPlayers;
        teamPlayers[playerIndex].hasRedCard = false;
        teamPlayers[playerIndex].redCardTime = null;
        
        transaction.update(matchRef, {
          isTeamA ? 'teamAPlayers' : 'teamBPlayers': 
              teamPlayers.map((p) => p.toMap()).toList(),
        });
        
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  /// Update match score directly
  Future<bool> updateScore({
    required String matchId,
    required int teamAScore,
    required int teamBScore,
  }) async {
    try {
      await _firestore.collection(_collection).doc(matchId).update({
        'teamAScore': teamAScore,
        'teamBScore': teamBScore,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // MATCH CREATION & MANAGEMENT
  // ==========================================

  /// Create a new match
  Future<String?> createMatch(MatchModel match) async {
    try {
      final docRef = await _firestore.collection(_collection).add(match.toFirestore());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  /// Cancel a match
  Future<bool> cancelMatch(String matchId) async {
    try {
      await _firestore.collection(_collection).doc(matchId).update({
        'status': MatchStatus.cancelled.name,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update match details (before it starts)
  Future<bool> updateMatch(MatchModel match) async {
    try {
      await _firestore.collection(_collection).doc(match.id).update(match.toFirestore());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a match (admin only)
  Future<bool> deleteMatch(String matchId) async {
    try {
      await _firestore.collection(_collection).doc(matchId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  /// Check if user can join a specific team
  Future<bool> canJoinTeam({
    required String matchId,
    required String team,
  }) async {
    final match = await getMatchById(matchId);
    if (match == null) return false;
    
    final teamPlayers = team == 'A' ? match.teamAPlayers : match.teamBPlayers;
    return teamPlayers.length < match.maxPlayers ~/ 2;
  }

  /// Get available spots in each team
  Future<Map<String, int>> getAvailableSpots(String matchId) async {
    final match = await getMatchById(matchId);
    if (match == null) return {'A': 0, 'B': 0};
    
    final maxPerTeam = match.maxPlayers ~/ 2;
    return {
      'A': maxPerTeam - match.teamAPlayers.length,
      'B': maxPerTeam - match.teamBPlayers.length,
    };
  }

  /// Check if user is in a match
  Future<bool> isUserInMatch({
    required String matchId,
    required String oderId,
  }) async {
    final match = await getMatchById(matchId);
    if (match == null) return false;
    return match.allPlayers.any((p) => p.oderId == oderId);
  }
}