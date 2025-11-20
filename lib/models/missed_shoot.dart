class MissedShot {
  final int shotNumber;
  final Set<String> feedback;
  final Duration shotTime; // ✅ NEW: Add time field

  MissedShot({
    required this.shotNumber,
    required this.feedback,
    required this.shotTime, // ✅ NEW: Required parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'shotNumber': shotNumber,
      'feedback': feedback.toList(),
      'time': shotTime.inMilliseconds, // ✅ NEW: Save time in milliseconds
    };
  }

  factory MissedShot.fromJson(Map<String, dynamic> json) {
    return MissedShot(
      shotNumber: json['shotNumber'] as int,
      feedback: Set<String>.from(json['feedback'] ?? []),
      shotTime: Duration(milliseconds: json['time'] ?? 0), // ✅ NEW: Load time, default to 0
    );
  }
}
