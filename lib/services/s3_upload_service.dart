import 'dart:io';

import 'package:aws_s3_upload_lite/aws_s3_upload_lite.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Service for uploading and deleting images on AWS S3.
///
/// Supported folders: `properties/`, `avatars/`, `categories/`.
/// URL format: `https://yalla-trip-media.s3.eu-south-1.amazonaws.com/{folder}/{filename}`
class S3UploadService {
  final String accessKey;
  final String secretKey;
  final String region;
  final String bucket;

  static const Set<String> _allowedFolders = {
    'properties',
    'avatars',
    'categories',
  };

  S3UploadService({
    required this.accessKey,
    required this.secretKey,
    required this.region,
    required this.bucket,
  });

  /// Upload [file] to the given [folder] and return the public URL.
  ///
  /// [folder] must be one of `properties`, `avatars`, `categories`.
  /// Returns the full public URL on success, or an empty string on failure.
  Future<String> uploadFile(File file, {String folder = 'properties'}) async {
    if (!_allowedFolders.contains(folder)) {
      debugPrint('[S3UploadService] Invalid folder "$folder". '
          'Allowed: ${_allowedFolders.join(', ')}');
      return '';
    }

    if (!file.existsSync()) {
      debugPrint('[S3UploadService] File does not exist: ${file.path}');
      return '';
    }

    try {
      final String result = await AwsS3.uploadFile(
        accessKey: accessKey,
        secretKey: secretKey,
        file: file,
        bucket: bucket,
        region: region,
        destDir: folder,
        filename: p.basename(file.path),
        metadata: {'uploaded-by': 'talaa-app'},
      );

      if (result.isEmpty) {
        debugPrint('[S3UploadService] Upload returned empty URL.');
        return '';
      }

      debugPrint('[S3UploadService] Upload success: $result');
      return result;
    } catch (e) {
      debugPrint('[S3UploadService] Upload failed: $e');
      return '';
    }
  }

  /// Build the expected public URL for a file already on S3.
  String buildUrl(String folder, String filename) {
    return 'https://$bucket.s3.$region.amazonaws.com/$folder/$filename';
  }
}
