import 'package:flutter/material.dart';

// lib/models/precision_shot_group.dart (or in your screen file)
class PrecisionShot {
  Offset position;
  Duration shotTime;
  bool isConfirmed;
  Set<String> feedback;
  double score;
  int ringNumber;
  
  // Environmental conditions
  String? light;
  String? wind;
  String? climate;
  String? groupName;
  
  // NEW: Track if this shot is a malfunction placeholder
  bool isMalfunction;

  PrecisionShot({
    required this.position,
    required this.shotTime,
    this.isConfirmed = false,
    Set<String>? feedback,
    this.score = 0.0,
    this.ringNumber = 0,
    this.light,
    this.wind,
    this.climate,
    this.groupName,
    this.isMalfunction = false, // NEW
  }) : feedback = feedback ?? {};

  factory PrecisionShot.fromMap(Map<String, dynamic> map) {
    return PrecisionShot(
      position: Offset(
        (map['x'] as num?)?.toDouble() ?? 0.0,
        (map['y'] as num?)?.toDouble() ?? 0.0,
      ),
      shotTime: Duration(milliseconds: map['time'] as int? ?? 0),
      isConfirmed: map['isConfirmed'] as bool? ?? true,
      feedback: Set<String>.from(map['feedback'] ?? []),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      ringNumber: map['ring'] as int? ?? 0,
      light: map['light'] as String?,
      wind: map['wind'] as String?,
      climate: map['climate'] as String?,
      isMalfunction: map['isMalfunction'] as bool? ?? false, // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': position.dx,
      'y': position.dy,
      'score': score,
      'time': shotTime.inMilliseconds,
      'feedback': feedback.toList(),
      'ring': ringNumber,
      'light': light,
      'wind': wind,
      'climate': climate,
      'isMalfunction': isMalfunction, // NEW
    };
  }
}

class PrecisionShotGroup {
  final int groupNumber;
  final Duration groupTime;
  final List<PrecisionShot> shots; // ✅ Store PrecisionShot objects, not Maps!
  final String? groupName;
    final bool isMalfunction; // NEW: Track if group had malfunction
  final bool isRetry;
  PrecisionShotGroup({
    required this.groupNumber,
    required this.groupTime,
    required this.shots,
    this.groupName,
    this.isMalfunction = false,
    this.isRetry = false,
  });

  // Convert to Map for saving
  Map<String, dynamic> toMap() {
    return {
      'groupNumber': groupNumber,
      'groupTime': groupTime.inMilliseconds,
      'shotCount': shots.length,
      'groupName': groupName,
      'isMalfunction': isMalfunction,
      'isRetry': isRetry,
      'shots': shots.map((shot) => shot.toMap()).toList(),
    };
  }

  factory PrecisionShotGroup.fromMap(Map<String, dynamic> map) {
    final shotsList = map['shots'] as List<dynamic>?;
    return PrecisionShotGroup(
      groupNumber: map['groupNumber'] as int,
      groupTime: Duration(milliseconds: map['groupTime'] as int),
      groupName: map['groupName'] as String?,
      isMalfunction: map['isMalfunction'] as bool? ?? false,
      isRetry: map['isRetry'] as bool? ?? false,
      shots: shotsList != null
          ? shotsList
              .map((s) => PrecisionShot.fromMap(s as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
