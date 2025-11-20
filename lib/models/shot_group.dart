
import 'package:flutter/material.dart';
class ShotGroup {
  final int groupNumber;
  final Duration groupTime;
  final List<Shot> shots;

  ShotGroup({
    required this.groupNumber,
    required this.groupTime,
    required this.shots,
  });
}

class Shot {
  Offset position;
  Duration shotTime;
  bool isConfirmed;
  Set<String> feedback;
  double score;
  int ringNumber;

  Shot({
    required this.position,
    required this.shotTime,
    this.isConfirmed = false,
    Set<String>? feedback,
    this.score = 0.0,
    this.ringNumber = 0,
  }) : feedback = feedback ?? {};
}
