import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Client-side upload boundary for unsigned Cloudinary uploads.
///
/// Pass values at build time:
/// --dart-define=CLOUDINARY_CLOUD_NAME=...
/// --dart-define=CLOUDINARY_UPLOAD_PRESET=...
class CloudinaryService {
  CloudinaryService._();

  static const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  static bool get isConfigured =>
      cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  static Future<String?> uploadPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isConfigured) return null;
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed: ${response.statusCode} ${_errorMessage(body)}',
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String?;
  }

  static String _errorMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
          body;
    } catch (_) {
      return body;
    }
  }
}
