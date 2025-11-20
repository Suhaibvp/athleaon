// Create models/attached_file.dart
class AttachedFile {
  final String filePath;
  final String fileName;
  final String fileType; // 'pdf', 'txt', 'image', etc.
  final int fileSize;

  AttachedFile({
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'fileName': fileName,
    'fileType': fileType,
    'fileSize': fileSize,
  };

  factory AttachedFile.fromJson(Map<String, dynamic> json) => AttachedFile(
    filePath: json['filePath'] ?? '',
    fileName: json['fileName'] ?? '',
    fileType: json['fileType'] ?? '',
    fileSize: json['fileSize'] ?? 0,
  );
}
