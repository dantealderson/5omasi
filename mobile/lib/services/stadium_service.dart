import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stadium_model.dart';

class StadiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'stadiums';

  // Get all active stadiums
  Future<List<StadiumModel>> getAllStadiums() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc)).toList();
  }

  // Get stadium by ID
  Future<StadiumModel?> getStadiumById(String stadiumId) async {
    final doc = await _firestore.collection(_collection).doc(stadiumId).get();
    if (!doc.exists) return null;
    return StadiumModel.fromFirestore(doc);
  }

  // Search stadiums by name
  Future<List<StadiumModel>> searchStadiums(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .get();
    
    final lowerQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => StadiumModel.fromFirestore(doc))
        .where((stadium) => 
            stadium.name.toLowerCase().contains(lowerQuery) ||
            stadium.address.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // Get stadiums by surface type
  Future<List<StadiumModel>> getStadiumsBySurface(SurfaceType surfaceType) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('surfaceType', isEqualTo: surfaceType.name)
        .get();
    return snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc)).toList();
  }

  // Get stadiums by match type (5v5, 7v7, etc.)
  Future<List<StadiumModel>> getStadiumsByMatchType(String matchType) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .where('matchType', isEqualTo: matchType)
        .get();
    return snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc)).toList();
  }

  // Stream stadium data (for real-time updates)
  Stream<StadiumModel?> streamStadium(String stadiumId) {
    return _firestore
        .collection(_collection)
        .doc(stadiumId)
        .snapshots()
        .map((doc) => doc.exists ? StadiumModel.fromFirestore(doc) : null);
  }

  // Stream all stadiums
  Stream<List<StadiumModel>> streamAllStadiums() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc)).toList());
  }

  // Add rating to stadium
  Future<void> addRating({
    required String stadiumId,
    required String oderId,
    required double rating,
    String? review,
  }) async {
    final batch = _firestore.batch();
    
    // Add review to subcollection
    final reviewRef = _firestore
        .collection(_collection)
        .doc(stadiumId)
        .collection('reviews')
        .doc(oderId);
    
    batch.set(reviewRef, {
      'oderId': oderId,
      'rating': rating,
      'review': review,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update stadium rating
    final stadiumRef = _firestore.collection(_collection).doc(stadiumId);
    final stadium = await getStadiumById(stadiumId);
    
    if (stadium != null) {
      final newTotalRatings = stadium.totalRatings + 1;
      final newRating = ((stadium.rating * stadium.totalRatings) + rating) / newTotalRatings;
      
      batch.update(stadiumRef, {
        'rating': newRating,
        'totalRatings': newTotalRatings,
      });
    }
    
    await batch.commit();
  }

  // Get stadium ratings/reviews
  Future<List<Map<String, dynamic>>> getStadiumReviews(String stadiumId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .doc(stadiumId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get favorite stadiums for a user
  Future<List<StadiumModel>> getFavoriteStadiums(String oderId) async {
    final userDoc = await _firestore.collection('users').doc(oderId).get();
    if (!userDoc.exists) return [];
    
    final favoriteIds = List<String>.from(userDoc.data()?['favoriteStadiums'] ?? []);
    if (favoriteIds.isEmpty) return [];
    
    final stadiums = <StadiumModel>[];
    for (final id in favoriteIds) {
      final stadium = await getStadiumById(id);
      if (stadium != null) stadiums.add(stadium);
    }
    return stadiums;
  }

  // Add stadium to favorites
  Future<void> addToFavorites({
    required String oderId,
    required String stadiumId,
  }) async {
    await _firestore.collection('users').doc(oderId).update({
      'favoriteStadiums': FieldValue.arrayUnion([stadiumId]),
    });
  }

  // Remove stadium from favorites
  Future<void> removeFromFavorites({
    required String oderId,
    required String stadiumId,
  }) async {
    await _firestore.collection('users').doc(oderId).update({
      'favoriteStadiums': FieldValue.arrayRemove([stadiumId]),
    });
  }

  // Filter stadiums by amenities
  Future<List<StadiumModel>> filterByAmenities({
    bool? hasWater,
    bool? hasParking,
    bool? hasBathroom,
    bool? hasLighting,
    bool? hasShowers,
  }) async {
    Query query = _firestore.collection(_collection).where('isActive', isEqualTo: true);
    
    if (hasWater == true) query = query.where('hasWater', isEqualTo: true);
    if (hasParking == true) query = query.where('hasParking', isEqualTo: true);
    if (hasBathroom == true) query = query.where('hasBathroom', isEqualTo: true);
    if (hasLighting == true) query = query.where('hasLighting', isEqualTo: true);
    if (hasShowers == true) query = query.where('hasShowers', isEqualTo: true);
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc as DocumentSnapshot)).toList();
  }

  // Get top rated stadiums
  Future<List<StadiumModel>> getTopRatedStadiums({int limit = 10}) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => StadiumModel.fromFirestore(doc)).toList();
  }

  // Get nearby stadiums (simple distance filter - for proper geo queries use GeoFlutterFire)
  Future<List<StadiumModel>> getNearbyStadiums({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    // Simple approach: get all and filter client-side
    // For production, use GeoFlutterFire or similar for proper geo queries
    final allStadiums = await getAllStadiums();
    
    return allStadiums.where((stadium) {
      final distance = _calculateDistance(
        latitude, longitude,
        stadium.location.latitude, stadium.location.longitude,
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Haversine formula for distance calculation
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = 
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);
    
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _babylonianSqrt(x) : 0;
  double _atan2(double y, double x) => _taylorAtan2(y, x);

  double _taylorSin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _babylonianSqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _taylorAtan2(double y, double x) {
    if (x > 0) return _taylorAtan(y / x);
    if (x < 0 && y >= 0) return _taylorAtan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _taylorAtan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _taylorAtan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _taylorAtan(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}