import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageUploadService {
  // Using freeimage.host - no region restrictions
  static const String _apiKey = '6d207e02198a847aa98d0a2a901485a5';
  static const String _uploadUrl = 'https://freeimage.host/api/1/upload';

  /// Upload image and return the URL
  /// Returns null if upload fails
  static Future<String?> uploadImage(File imageFile) async {
    try {
      // Read file and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Make API request
      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'key': _apiKey,
          'source': base64Image,
          'format': 'json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status_code'] == 200) {
          // Return the image URL
          return jsonResponse['image']['url'];
        }
      }

      print('Freeimage upload failed: ${response.body}');
      return null;
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  /// Upload image from path
  static Future<String?> uploadImageFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      print('File not found: $path');
      return null;
    }
    return uploadImage(file);
  }
}