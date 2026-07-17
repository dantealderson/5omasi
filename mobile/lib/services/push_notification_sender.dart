import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationSender {
  static const String _workerUrl = 'https://khomasi-notifications.khomasi.workers.dev';
  static const String _apiKey = 'khomasi-notif-2026-x9k4m7p2';

  /// Send notification to specific users by their oderIds
  static Future<void> sendToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (userIds.isEmpty) return;

    // Fetch FCM tokens from Firestore
    final tokens = <String>[];
    for (final userId in userIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final token = doc.data()?['fcmToken'] as String?;
        if (token != null && token.isNotEmpty) {
          tokens.add(token);
        }
      } catch (_) {}
    }

    if (tokens.isEmpty) return;

    await _send(tokens: tokens, title: title, body: body, data: data);
  }

  /// Send notification to all players in a match (except the sender)
  static Future<void> notifyMatchPlayers({
    required String matchId,
    required String excludeUserId,
    required String title,
    required String body,
  }) async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) return;
      final matchData = matchDoc.data()!;

      // Collect all player IDs from both teams
      final playerIds = <String>{};
      for (final player in (matchData['teamAPlayers'] as List? ?? [])) {
        if (player is Map && player['oderId'] != null) {
          playerIds.add(player['oderId']);
        }
      }
      for (final player in (matchData['teamBPlayers'] as List? ?? [])) {
        if (player is Map && player['oderId'] != null) {
          playerIds.add(player['oderId']);
        }
      }

      // Remove the sender
      playerIds.remove(excludeUserId);

      if (playerIds.isEmpty) return;

      await sendToUsers(
        userIds: playerIds.toList(),
        title: title,
        body: body,
        data: {'matchId': matchId, 'type': 'match_update'},
      );
    } catch (e) {
      print('Error sending match notification: $e');
    }
  }

  /// Send notification to match creator
  static Future<void> notifyMatchCreator({
    required String matchId,
    required String title,
    required String body,
  }) async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) return;
      final creatorId = matchDoc.data()?['createdBy'] as String?;
      if (creatorId == null) return;

      await sendToUsers(
        userIds: [creatorId],
        title: title,
        body: body,
        data: {'matchId': matchId, 'type': 'match_update'},
      );
    } catch (e) {
      print('Error notifying match creator: $e');
    }
  }

  /// Internal: call the Cloudflare Worker
  static Future<void> _send({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await http.post(
        Uri.parse(_workerUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'tokens': tokens,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );
    } catch (e) {
      print('Error calling notification worker: $e');
    }
  }
}
