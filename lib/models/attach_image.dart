import 'dart:typed_data';
class AttachedImage {
  final String imageId;
  final Uint8List imageData;
  final String title;
  final String notes;

  AttachedImage({
    required this.imageId,
    required this.imageData,
    required this.title,
    required this.notes,
  });
}
