import 'package:cloud_firestore/cloud_firestore.dart';

enum SurfaceType { natural, artificial, indoor }

class StadiumModel {
  final String id;
  final String name;
  final String address;
  final String? description;
  final GeoPoint location;
  final String? googleMapsUrl; // Direct Google Maps link
  final String? locationText; // Text description of location (e.g. "بغداد - الكرادة - قرب مول بغداد")
  final String? imageUrl;
  final List<String> images;
  final SurfaceType surfaceType;
  final int capacity;
  final String matchType;
  final double pricePerHour;
  final bool hasWater;
  final bool hasParking;
  final bool hasBathroom;
  final bool hasLighting;
  final bool hasShowers;
  final double rating;
  final int totalRatings;
  final String ownerId;
  final bool isActive;
  final Map<String, List<String>>? availableSlots;

  StadiumModel({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.location,
    this.googleMapsUrl,
    this.locationText,
    this.imageUrl,
    this.images = const [],
    required this.surfaceType,
    this.capacity = 10,
    this.matchType = "5v5",
    required this.pricePerHour,
    this.hasWater = false,
    this.hasParking = false,
    this.hasBathroom = false,
    this.hasLighting = false,
    this.hasShowers = false,
    this.rating = 0.0,
    this.totalRatings = 0,
    required this.ownerId,
    this.isActive = true,
    this.availableSlots,
  });

  factory StadiumModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StadiumModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      description: data['description'],
      location: data['location'] ?? const GeoPoint(0, 0),
      googleMapsUrl: data['googleMapsUrl'],
      locationText: data['locationText'],
      imageUrl: data['imageUrl'],
      images: List<String>.from(data['images'] ?? []),
      surfaceType: SurfaceType.values.firstWhere(
        (e) => e.name == data['surfaceType'],
        orElse: () => SurfaceType.artificial,
      ),
      capacity: data['capacity'] ?? 10,
      matchType: data['matchType'] ?? '5v5',
      pricePerHour: (data['pricePerHour'] ?? 0).toDouble(),
      hasWater: data['hasWater'] ?? false,
      hasParking: data['hasParking'] ?? false,
      hasBathroom: data['hasBathroom'] ?? false,
      hasLighting: data['hasLighting'] ?? false,
      hasShowers: data['hasShowers'] ?? false,
      rating: (data['rating'] ?? 0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      ownerId: data['ownerId'] ?? '',
      isActive: data['isActive'] ?? true,
      availableSlots: data['availableSlots'] != null
          ? (data['availableSlots'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, List<String>.from(value)))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'description': description,
      'location': location,
      'googleMapsUrl': googleMapsUrl,
      'locationText': locationText,
      'imageUrl': imageUrl,
      'images': images,
      'surfaceType': surfaceType.name,
      'capacity': capacity,
      'matchType': matchType,
      'pricePerHour': pricePerHour,
      'hasWater': hasWater,
      'hasParking': hasParking,
      'hasBathroom': hasBathroom,
      'hasLighting': hasLighting,
      'hasShowers': hasShowers,
      'rating': rating,
      'totalRatings': totalRatings,
      'ownerId': ownerId,
      'isActive': isActive,
      'availableSlots': availableSlots,
    };
  }

  StadiumModel copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    GeoPoint? location,
    String? googleMapsUrl,
    String? locationText,
    String? imageUrl,
    List<String>? images,
    SurfaceType? surfaceType,
    int? capacity,
    String? matchType,
    double? pricePerHour,
    bool? hasWater,
    bool? hasParking,
    bool? hasBathroom,
    bool? hasLighting,
    bool? hasShowers,
    double? rating,
    int? totalRatings,
    String? ownerId,
    bool? isActive,
    Map<String, List<String>>? availableSlots,
  }) {
    return StadiumModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      location: location ?? this.location,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      locationText: locationText ?? this.locationText,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      surfaceType: surfaceType ?? this.surfaceType,
      capacity: capacity ?? this.capacity,
      matchType: matchType ?? this.matchType,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      hasWater: hasWater ?? this.hasWater,
      hasParking: hasParking ?? this.hasParking,
      hasBathroom: hasBathroom ?? this.hasBathroom,
      hasLighting: hasLighting ?? this.hasLighting,
      hasShowers: hasShowers ?? this.hasShowers,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      ownerId: ownerId ?? this.ownerId,
      isActive: isActive ?? this.isActive,
      availableSlots: availableSlots ?? this.availableSlots,
    );
  }
}