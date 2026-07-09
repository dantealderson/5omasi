import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  static Position? _cachedPosition;
  static DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Get current user position with caching
  /// Returns null if location services are disabled or permission denied
  static Future<Position?> getCurrentPosition() async {
    // Check if cached position is still valid
    if (_cachedPosition != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration) {
        return _cachedPosition;
      }
    }

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }

      // Get current position
      _cachedPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      _lastFetchTime = DateTime.now();

      return _cachedPosition;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between user and a GeoPoint
  /// Returns distance in kilometers, or null if user location unavailable
  static Future<double?> getDistanceToPoint(GeoPoint point) async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    return calculateDistance(
      position.latitude,
      position.longitude,
      point.latitude,
      point.longitude,
    );
  }

  /// Calculate distance between two coordinates
  /// Returns distance in kilometers
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceInMeters / 1000; // Convert to KM
  }

  /// Calculate distance from cached position (sync, for sorting)
  /// Returns null if no cached position
  static double? getDistanceFromCached(GeoPoint point) {
    if (_cachedPosition == null) return null;

    return calculateDistance(
      _cachedPosition!.latitude,
      _cachedPosition!.longitude,
      point.latitude,
      point.longitude,
    );
  }

  /// Format distance for display
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return '';
    
    if (distanceKm < 1) {
      // Show in meters if less than 1 km
      return '${(distanceKm * 1000).round()} م';
    } else if (distanceKm < 10) {
      // Show one decimal for distances under 10 km
      return '${distanceKm.toStringAsFixed(1)} كم';
    } else {
      // Round to whole number for larger distances
      return '${distanceKm.round()} كم';
    }
  }

  /// Check if location permission is granted
  static Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Open app settings for location permission
  static Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Clear cached position
  static void clearCache() {
    _cachedPosition = null;
    _lastFetchTime = null;
  }
}