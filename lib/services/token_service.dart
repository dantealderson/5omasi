import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khomasi/models/user_model.dart';

class TokenService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // GET USER BALANCE
  // ============================================
  
  static Future<int> getBalance(String oderId) async {
    final doc = await _firestore.collection('users').doc(oderId).get();
    if (!doc.exists) return 0;
    return (doc.data()?['matchTokens'] ?? 0) as int;
  }

  // ============================================
  // DEDUCT TOKENS (for booking)
  // ============================================
  
  static Future<bool> deductTokens({
    required String oderId,
    required int amount,
    required String matchId,
    String? description,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(oderId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }
        
        final currentTokens = (userDoc.data()?['matchTokens'] ?? 0) as int;
        final totalUsed = (userDoc.data()?['totalTokensUsed'] ?? 0) as int;
        
        if (currentTokens < amount) {
          throw Exception('Insufficient tokens');
        }
        
        final newBalance = currentTokens - amount;
        
        // Update user balance
        transaction.update(userRef, {
          'matchTokens': newBalance,
          'totalTokensUsed': totalUsed + amount,
          'updatedAt': Timestamp.now(),
        });
        
        // Create transaction record
        final transactionRef = _firestore.collection('tokenTransactions').doc();
        transaction.set(transactionRef, {
          'oderId': oderId,
          'type': 'matchBooking',
          'amount': -amount,
          'balanceAfter': newBalance,
          'matchId': matchId,
          'description': description ?? 'حجز مباراة',
          'createdAt': Timestamp.now(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error deducting tokens: $e');
      return false;
    }
  }

  // ============================================
  // REFUND TOKENS (for cancellation)
  // ============================================
  
  static Future<bool> refundTokens({
    required String oderId,
    required int amount,
    required String matchId,
    String? description,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(oderId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }
        
        final currentTokens = (userDoc.data()?['matchTokens'] ?? 0) as int;
        final newBalance = currentTokens + amount;
        
        // Update user balance
        transaction.update(userRef, {
          'matchTokens': newBalance,
          'updatedAt': Timestamp.now(),
        });
        
        // Create transaction record
        final transactionRef = _firestore.collection('tokenTransactions').doc();
        transaction.set(transactionRef, {
          'oderId': oderId,
          'type': 'matchRefund',
          'amount': amount,
          'balanceAfter': newBalance,
          'matchId': matchId,
          'description': description ?? 'استرداد - إلغاء مباراة',
          'createdAt': Timestamp.now(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error refunding tokens: $e');
      return false;
    }
  }

  // ============================================
  // ADD TOKENS (for purchase or admin grant)
  // ============================================
  
  static Future<bool> addTokens({
    required String oderId,
    required int amount,
    required TokenTransactionType type,
    String? description,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(oderId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }
        
        final currentTokens = (userDoc.data()?['matchTokens'] ?? 0) as int;
        final totalPurchased = (userDoc.data()?['totalTokensPurchased'] ?? 0) as int;
        final newBalance = currentTokens + amount;
        
        // Update user balance
        final updateData = <String, dynamic>{
          'matchTokens': newBalance,
          'updatedAt': Timestamp.now(),
        };
        
        if (type == TokenTransactionType.purchase) {
          updateData['totalTokensPurchased'] = totalPurchased + amount;
        }
        
        transaction.update(userRef, updateData);
        
        // Create transaction record
        final transactionRef = _firestore.collection('tokenTransactions').doc();
        transaction.set(transactionRef, {
          'oderId': oderId,
          'type': type.toString().split('.').last,
          'amount': amount,
          'balanceAfter': newBalance,
          'matchId': null,
          'description': description ?? _getDefaultDescription(type),
          'createdAt': Timestamp.now(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error adding tokens: $e');
      return false;
    }
  }

  static String _getDefaultDescription(TokenTransactionType type) {
    switch (type) {
      case TokenTransactionType.purchase:
        return 'شراء رصيد';
      case TokenTransactionType.adminGrant:
        return 'هدية من الإدارة';
      case TokenTransactionType.adminDeduct:
        return 'خصم من الإدارة';
      default:
        return 'معاملة';
    }
  }

  // ============================================
  // BATCH REFUND (for auto-cancelled matches)
  // ============================================
  
  static Future<bool> batchRefundPlayers({
    required String matchId,
    required List<Map<String, dynamic>> players,
    required String reason,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (final player in players) {
        final oderId = player['oderId'] as String?;
        if (oderId == null || oderId.isEmpty) continue;
        
        // Each player gets 1 token back per spot
        final userRef = _firestore.collection('users').doc(oderId);
        
        // We need to get current balance first, so we can't use batch for this
        // Using individual transactions instead
        await refundTokens(
          oderId: oderId,
          amount: 1,
          matchId: matchId,
          description: reason,
        );
      }
      
      return true;
    } catch (e) {
      print('Error in batch refund: $e');
      return false;
    }
  }

  // ============================================
  // GET TRANSACTION HISTORY
  // ============================================
  
  static Stream<List<TokenTransaction>> getTransactionHistory(String oderId) {
    return _firestore
        .collection('tokenTransactions')
        .where('oderId', isEqualTo: oderId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TokenTransaction.fromFirestore(doc))
            .toList());
  }

  // ============================================
  // CHECK IF USER HAS ENOUGH TOKENS
  // ============================================
  
  static Future<bool> hasEnoughTokens(String oderId, int required) async {
    final balance = await getBalance(oderId);
    return balance >= required;
  }
}