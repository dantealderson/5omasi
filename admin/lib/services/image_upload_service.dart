import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Same freeimage.host uploader the mobile app uses, but byte-based so it
/// works on desktop and web alike.
class ImageUploadService {
  static const String _apiKey = '6d207e02198a847aa98d0a2a901485a5';
  static const String _uploadUrl = 'https://freeimage.host/api/1/upload';

  /// Upload image bytes and return the hosted URL, or null on failure.
  static Future<String?> uploadBytes(Uint8List bytes) async {
    try {
      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'key': _apiKey,
          'source': base64Encode(bytes),
          'format': 'json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status_code'] == 200) {
          return jsonResponse['image']['url'];
        }
      }

      debugPrint('Freeimage upload failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }
}
