// lib/utils/image_compression_helper.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressionHelper {
  /// Compress image with 85% quality (good balance for coach sessions)
  static Future<Uint8List> compressImage(File imageFile, {int quality = 85}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Compress
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      final originalSize = bytes.length / 1024;
      final compressedSize = compressed.length / 1024;
      print('📦 Compressed: ${originalSize.toStringAsFixed(1)}KB → ${compressedSize.toStringAsFixed(1)}KB (${((1 - compressedSize/originalSize) * 100).toStringAsFixed(0)}% reduction)');
      
      return Uint8List.fromList(compressed);
    } catch (e) {
      print('⚠️ Compression failed, using original: $e');
      return await imageFile.readAsBytes();
    }
  }
}
