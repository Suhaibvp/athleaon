import 'dart:typed_data';

// In models/photo_data.dart
class PhotoData {
  final String localPath; // Path to local file
  final String note;
  final int shotGroup; // Which group (1, 2, 3, etc.)
  
  PhotoData({
    required this.localPath,
    required this.note,
    required this.shotGroup,
  });

  Map<String, dynamic> toJson() => {
    'localPath': localPath,
    'note': note,
    'shotGroup': shotGroup,
  };

  factory PhotoData.fromJson(Map<String, dynamic> json) => PhotoData(
    localPath: json['localPath'] ?? '',
    note: json['note'] ?? '',
    shotGroup: json['shotGroup'] ?? 1,
  );
}
