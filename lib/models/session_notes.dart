class SessionNote {
  final String note;
  final DateTime timestamp;

  SessionNote({
    required this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SessionNote.fromJson(Map<String, dynamic> json) {
    return SessionNote(
      note: json['note'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}
