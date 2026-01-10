import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../../session_report_screen.dart';
import '../../../../widgets/shooting_feedback_icons.dart';
import '../../../../services/session_service.dart';
import '../../../../models/missed_shoot.dart';
import '../../../../models/photo_data.dart';
import '../../../../models/session_notes.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rapid_session_report.dart';
import '../../../../models/precision_shot_group.dart';

// /// Shot model with environmental conditions
// class PrecisionShot {
//   Offset position;
//   Duration shotTime;
//   bool isConfirmed;
//   Set<String> feedback;
//   double score;
//   int ringNumber;

//   // Environmental conditions
//   String? light; // Bright, Medium, Low
//   String? wind; // N, NE, E, SE, S, SW, W, NW, NONE
//   String? climate; // Sunny, Cloudy, Rainy, Foggy

//   // NEW: store section / group name for each shot
//   String? groupName;

//   PrecisionShot({
//     required this.position,
//     required this.shotTime,
//     this.isConfirmed = false,
//     Set<String>? feedback,
//     this.score = 0.0,
//     this.ringNumber = 0,
//     this.light,
//     this.wind,
//     this.climate,
//     this.groupName,
//   }) : feedback = feedback ?? {};
// }

/// Shot Group model for Precision includes environmental data
// class PrecisionShotGroup {
//   final int groupNumber;
//   final Duration groupTime;
//   final List<Map<String, dynamic>> shots;
  

//   PrecisionShotGroup({
//     required this.groupNumber,
//     required this.groupTime,
//     required this.shots,
    
//   });
// }

class Day1ShootingScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;
  final List<Map<String, dynamic>>? existingShots;
  final List<MissedShot>? existingMissedShots;
  final List<PhotoData>? existingImages;
  final List<PrecisionShotGroup>? existingShotGroups;
  final String studentName;
  final List<SessionNote>? existingNotes;
  final List<PrecisionShot>? existingSightingShots;

  const Day1ShootingScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.shotsPerTarget,
    this.existingShots,
    required this.studentName,
    this.existingMissedShots,
    this.existingImages,
    this.existingShotGroups,
    this.existingNotes,
    this.existingSightingShots,
  });

  @override
  State<Day1ShootingScreen> createState() => Day1ShootingScreenState();
}

class Day1ShootingScreenState extends State<Day1ShootingScreen> {

  List<int> malfunctionedGroupIndices = []; // Indices of groups with malfunction
  bool hasUsedRetry = false; // Track if user has used their one retry
  int? retryGroupIndex; // Which group is being retried

  bool isSightingMode = true;
  List<PrecisionShot> sightingShots = [];
  List<PrecisionShot> shots = [];

  Duration sightingTime = Duration.zero;
  Timer? timer;
  Timer? sessionTimer;
  Duration currentShotTime = Duration.zero;
  Duration totalSessionTime = Duration.zero;
  bool isTimerRunning = false;
  bool isSessionActive = false;
  bool sessionStarted = false;
  bool shotPlaced = false;
  int currentShotIndex = -1;

  final GlobalKey targetKey = GlobalKey();
  final double targetSize = 280.0;

  List<SessionNote> sessionNotes = [];
  Duration accumulatedSessionTime = Duration.zero;

  // Zoom variables
  double zoomLevel = 1.0;
  final double minZoom = 1.0;
  final double maxZoom = 3.0;
  final double zoomStep = 0.5;
  Offset zoomOffset = Offset.zero;

  List<PrecisionShotGroup> shotGroups = [];
  List<MissedShot> missedShots = [];
  bool showTooltips = false;
  List<PhotoData> photos = [];
  DateTime? sessionStartTime;
  DateTime? shotStartTime;
  bool isCoach = false;

  // Environmental condition indicators
  String? selectedLight;
  String? selectedWindDirection;
  String? selectedClimate;

  // NEW: 5‑shot section logic
  // Order of sections for Day 1 rapid (example taken from your table image)
  final List<String> sectionNames = const [
    '8sec 1st series',
    '8sec 2nd series',
    '6sec 1st series',
    '6sec 2nd series',
    '4sec 1st series',
    '4sec 2nd series',
  ];
  int get globalShotNumber {
    if (retryGroupIndex != null) {
      // During retry, show retry group range
      return (retryGroupIndex! * 5) + (shots.where((s) => s.isConfirmed).skip(retryGroupIndex! * 5).take(5).length) + 1;
    }
    
    // Calculate based on section index and confirmed shots in current group
    final baseNumber = currentSectionIndex * 5;
    final confirmedInGroup = shots.where((s) => s.isConfirmed).skip(currentSectionIndex * 5).take(5).length;
    return baseNumber + confirmedInGroup + 1;
  }
    int get totalExpectedShots {
    return sectionNames.length * 5; // 6 groups * 5 = 30
  }
  int currentSectionIndex = 0; // 0..sectionNames.length-1
  bool hasPendingRetake = false; // when a malfunctioned shot is chosen to retake
  int? malfunctionShotGlobalIndex; // index in shots list for the shot to be retaken

  @override
  void initState() {
    super.initState();
    shotGroups.clear();
    loadExistingShots();
    if (widget.existingNotes != null && widget.existingNotes!.isNotEmpty) {
      sessionNotes = List<SessionNote>.from(widget.existingNotes!);
    }
    checkUserRole();
    if (shots.isEmpty) {
      addNewShot();
      shotPlaced = true;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> checkUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final isCoachRoleUser = await isCoachRole(currentUser.uid);
      setState(() {
        isCoach = isCoachRoleUser;
      });
    }
  }

  Future<bool> isCoachRole(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final role =
            userDoc.data()?['role']?.toString().toLowerCase() ?? 'student';
        return role == 'coach' || role == 'instructor';
      }
    } catch (_) {}
    return false;
  }

  void switchToActualSession() {
    setState(() {
      isSightingMode = false;
      shots.clear();
      shotGroups.clear();
      currentShotIndex = -1;
      currentShotTime = Duration.zero;
      totalSessionTime = Duration.zero;
      accumulatedSessionTime = Duration.zero;
      timer?.cancel();
      sessionTimer?.cancel();
      isTimerRunning = false;
      isSessionActive = false;
      sessionStarted = false;
      currentSectionIndex = 0;
      hasPendingRetake = false;
      malfunctionShotGlobalIndex = null;
      addNewShot();
      shotPlaced = true;
    });
    startSessionTimer();
  }

  double get calculateSightingScore {
    return sightingShots.fold(
      0.0,
      (sum, shot) => sum + shot.score,
    );
  }

void loadExistingShots() {
  if (widget.existingShots != null && widget.existingShots!.isNotEmpty) {
    setState(() {
      shotGroups.clear();
      shots = widget.existingShots!
          .map((shotData) => PrecisionShot.fromMap(shotData))
          .toList();

      if (widget.existingShotGroups != null &&
          widget.existingShotGroups!.isNotEmpty) {
        final lastGroup = widget.existingShotGroups!.last;
        accumulatedSessionTime = lastGroup.groupTime;
        totalSessionTime = accumulatedSessionTime;
        shotGroups = List<PrecisionShotGroup>.from(widget.existingShotGroups!);
        currentSectionIndex =
            (shotGroups.length).clamp(0, sectionNames.length - 1);
      }

      if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
        photos.addAll(widget.existingImages!);
      }
      if (widget.existingMissedShots != null &&
          widget.existingMissedShots!.isNotEmpty) {
        missedShots = List<MissedShot>.from(widget.existingMissedShots!);
      }

      if (widget.existingSightingShots != null &&
          widget.existingSightingShots!.isNotEmpty) {
        sightingShots =
            List<PrecisionShot>.from(widget.existingSightingShots!);
        isSightingMode = true;
      } else {
        isSightingMode = false;
      }

      final exactCenter = Offset(targetSize / 2, targetSize / 2);
      shots.add(
        PrecisionShot(
          position: exactCenter,
          shotTime: Duration.zero,
          isConfirmed: false,
          feedback: {},
          score: 0.0,
          ringNumber: 0,
        ),
      );
      currentShotIndex = shots.length - 1;
      shotPlaced = true;
    });
  } else {
    if (widget.existingSightingShots != null &&
        widget.existingSightingShots!.isNotEmpty) {
      setState(() {
        sightingShots =
            List<PrecisionShot>.from(widget.existingSightingShots!);
        isSightingMode = true;
        addNewShot();
        shotPlaced = true;
      });
    }
  }
}


  void startSessionTimer() {
    sessionStartTime = DateTime.now();
    sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        totalSessionTime =
            accumulatedSessionTime + DateTime.now().difference(sessionStartTime!);
      });
    });
  }

  void toggleTimer() {
    // Kept for logic, but no UI button will call this now
    if (!sessionStarted && !isSightingMode) {
      toggleSession();
    }

    setState(() {
      isTimerRunning = !isTimerRunning;
    });

    if (isTimerRunning) {
      shotStartTime = DateTime.now();
      timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        final elapsed = DateTime.now().difference(shotStartTime!);
        setState(() {
          if (isSightingMode) {
            sightingTime = elapsed;
            if (currentShotIndex >= 0 &&
                currentShotIndex < sightingShots.length) {
              sightingShots[currentShotIndex].shotTime = sightingTime;
            }
          } else {
            currentShotTime = elapsed;
            if (currentShotIndex >= 0 && currentShotIndex < shots.length) {
              shots[currentShotIndex].shotTime = currentShotTime;
            }
          }
        });
      });
    } else {
      timer?.cancel();
    }
  }

  void toggleSession() {
    setState(() {
      isSessionActive = !isSessionActive;
    });

    if (isSessionActive) {
      if (!sessionStarted) {
        sessionStarted = true;
        startSessionTimer();
      }
    } else {
      sessionTimer?.cancel();
      if (sessionStartTime != null) {
        accumulatedSessionTime = totalSessionTime;
        sessionStartTime = null;
      }
    }
  }

  void zoomIn() {
    setState(() {
      if (zoomLevel < maxZoom) {
        zoomLevel += zoomStep;
        zoomLevel = zoomLevel.clamp(minZoom, maxZoom);
      }
    });
  }

  void zoomOut() {
    setState(() {
      if (zoomLevel > minZoom) {
        zoomLevel -= zoomStep;
        zoomLevel = zoomLevel.clamp(minZoom, maxZoom);
        if (zoomLevel == minZoom) {
          zoomOffset = Offset.zero;
        }
      }
    });
  }

  void updateShotPosition(Offset localPosition) {
    final currentList = isSightingMode ? sightingShots : shots;
    if (currentShotIndex < 0 || currentShotIndex >= currentList.length) return;

    final adjustedPosition = adjustPositionForZoom(localPosition);
    final clampedX = adjustedPosition.dx.clamp(0.0, targetSize);
    final clampedY = adjustedPosition.dy.clamp(0.0, targetSize);
    final clampedPosition = Offset(clampedX, clampedY);

    setState(() {
      currentList[currentShotIndex].position = clampedPosition;
      currentList[currentShotIndex].light = selectedLight;
      currentList[currentShotIndex].wind = selectedWindDirection;
      currentList[currentShotIndex].climate = selectedClimate;
      calculateScore(currentList[currentShotIndex]);
    });
  }

  Offset adjustPositionForZoom(Offset localPosition) {
    if (zoomLevel == 1.0) return localPosition;
    final center = Offset(targetSize / 2, targetSize / 2);
    final offsetFromCenter = localPosition - center;
    final adjustedOffset = offsetFromCenter / zoomLevel;
    return center + adjustedOffset + zoomOffset;
  }

  void addNewShot() {
    setState(() {
      final exactCenter = Offset(targetSize / 2, targetSize / 2);
      if (isSightingMode) {
        sightingShots.add(
          PrecisionShot(
            position: exactCenter,
            shotTime: sightingTime,
            light: selectedLight,
            wind: selectedWindDirection,
            climate: selectedClimate,
          ),
        );
        currentShotIndex = sightingShots.length - 1;
      } else {
        shots.add(
          PrecisionShot(
            position: exactCenter,
            shotTime: currentShotTime,
            light: selectedLight,
            wind: selectedWindDirection,
            climate: selectedClimate,
            // groupName: sectionNames[currentSectionIndex],
          ),
        );
        currentShotIndex = shots.length - 1;
      }
      calculateScore(isSightingMode
          ? sightingShots[currentShotIndex]
          : shots[currentShotIndex]);
    });
  }

void confirmCurrentShot() {
  if (currentShotIndex < 0) return;

  final currentList = isSightingMode ? sightingShots : shots;
  if (currentShotIndex >= currentList.length) return;

  final shot = currentList[currentShotIndex];

  if (!shot.isConfirmed) {
    if (!isSightingMode) {
      final confirmedCount = shots.where((s) => s.isConfirmed).length;
      
      // FIXED: Simple check - 30 shots normally, 35 if retry is active
      final maxShots = retryGroupIndex != null ? 35 : 30;
      
      if (confirmedCount >= maxShots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(retryGroupIndex != null 
                ? 'Retry completed!' 
                : 'All 30 shots completed'),
            backgroundColor: retryGroupIndex != null 
                ? Colors.green 
                : const Color(0xFFD32F2F),
            duration: const Duration(seconds: 2),
          ),
        );
        
        if (retryGroupIndex == null) {
          // Normal flow - show retry option
          Future.delayed(const Duration(milliseconds: 300), () {
            _checkForRetryOption();
          });
        }
        return;
      }
    }

    setState(() {
      shot.isConfirmed = true;
      shot.light ??= selectedLight;
      shot.wind ??= selectedWindDirection;
      shot.climate ??= selectedClimate;

      if (!isSightingMode) {
        // Check if in retry mode
        if (retryGroupIndex != null) {
          final confirmedCount = shots.where((s) => s.isConfirmed).length;
          
          // Retry shots are from 31 to 35
          if (confirmedCount >= 35) {
            // All 5 retry shots taken, save the retry group
            final retryShots = shots
                .where((s) => s.isConfirmed)
                .skip(30) // Skip first 30 shots
                .take(5)  // Take shots 31-35
                .toList();
            
            final retryGroup = PrecisionShotGroup(
              groupNumber: retryGroupIndex! + 1,
              groupTime: totalSessionTime,
              groupName: sectionNames[retryGroupIndex!],
              isMalfunction: true,
              isRetry: true,
              shots: List<PrecisionShot>.from(retryShots),
            );

            // Update the existing malfunction group with retry data
            final existingIndex = shotGroups.indexWhere((g) => 
              g.groupNumber == retryGroup.groupNumber && g.isMalfunction);
            if (existingIndex != -1) {
              shotGroups[existingIndex] = retryGroup;
            } else {
              shotGroups.add(retryGroup);
            }

            // Clear retry mode
            retryGroupIndex = null;
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Retry completed! You can now save.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            shotPlaced = true;
            return;
          } else {
            // Continue retry - add next shot
            addNewShot();
          }
        } else {
          // Normal flow
          _update5ShotGroupingAndSection();
          addNewShot();
        }
      } else {
        addNewShot();
      }

      shotPlaced = true;

      if (isSightingMode) {
                  isTimerRunning=false;
          timer?.cancel();
        shotStartTime = DateTime.now();
        sightingTime = Duration.zero;
      } else {
                  isTimerRunning=false;
          timer?.cancel();
        shotStartTime = DateTime.now();
        currentShotTime = Duration.zero;
      }
    });
  }
}



  // NEW: build 5‑shot groups, manage section names & malfunction retake
void _update5ShotGroupingAndSection() {
  final confirmedShots = shots.where((s) => s.isConfirmed).toList();
  final confirmedCount = confirmedShots.length;

  // Build groups of 5
  if (confirmedCount % 5 == 0) {
    final groupNumber = confirmedCount ~/ 5;
    final startIndex = (groupNumber - 1) * 5;
    final endIndex = groupNumber * 5;
    final groupShots = confirmedShots.sublist(startIndex, endIndex);

    final sectionName = groupNumber - 1 < sectionNames.length
        ? sectionNames[groupNumber - 1]
        : 'Series $groupNumber';

    final existingGroupIndex =
        shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
    
    // CHANGED: Create group with List<PrecisionShot> directly
    final group = PrecisionShotGroup(
      groupNumber: groupNumber,
      groupTime: totalSessionTime,
      groupName: sectionName,
      shots: List<PrecisionShot>.from(groupShots), // FIXED
    );

    setState(() {
      if (existingGroupIndex != -1) {
        shotGroups[existingGroupIndex] = group;
      } else {
        shotGroups.add(group);
      }

      // Move to next section after completing 5 confirmed shots
      if (currentSectionIndex < sectionNames.length - 1 &&
          !hasPendingRetake) {
        currentSectionIndex++;
      }

      if (hasPendingRetake) {
        hasPendingRetake = false;
        malfunctionShotGlobalIndex = null;
      }
    });
  }
}
  void calculateScore(PrecisionShot shot) {
    final center = Offset(targetSize / 2, targetSize / 2);
    final shotCenterDistance = (shot.position - center).distance;

    const scale = 280.0 / 400.0;
    final pelletRadius = (5.6 / 2) * scale;

    final Map<int, double> ringDiameters = {
      10: 100.0,
      9: 160.0,
      8: 220.0,
      7: 280.0,
      6: 340.0,
      5: 400.0,
    };

    final Map<int, double> ringRadii = {};
    ringDiameters.forEach((ring, diameter) {
      ringRadii[ring] = (diameter / 2) * scale;
    });

    final pelletInnerEdgeDistance = shotCenterDistance - pelletRadius;

    int ringNumber = 0;
    double score = 0.0;

    if (pelletInnerEdgeDistance > ringRadii[5]!) {
      ringNumber = 0;
      score = 0.0;
      shot.ringNumber = ringNumber;
      shot.score = score;
      return;
    }

    for (int ring = 10; ring >= 5; ring--) {
      final outerRingRadius = ringRadii[ring]!;
      if (pelletInnerEdgeDistance <= outerRingRadius) {
        ringNumber = ring;

        if (ring == 10) {
          final ring10Radius = ringRadii[10]!;
          final distanceRatio = shotCenterDistance / ring10Radius;
          final scoreRatio = 1.0 - distanceRatio;
          final decimal = (scoreRatio * 0.9).clamp(0.0, 0.9);
          score = 10.0 + double.parse(decimal.toStringAsFixed(1)) - 0.0;
        } else {
          final innerRingRadius = ringRadii[ring - 1]!;
          final ringWidthInPixels = outerRingRadius - innerRingRadius;
          final distanceIntoRing =
              outerRingRadius - pelletInnerEdgeDistance;
          final clampedDistance =
              distanceIntoRing.clamp(0.0, ringWidthInPixels);
          final decimal =
              (clampedDistance / ringWidthInPixels * 0.9).clamp(0.0, 0.9);
          score = ring + double.parse(decimal.toStringAsFixed(1)) - 0.0;
        }
        break;
      }
    }

    shot.ringNumber = ringNumber;
    shot.score = score;
  }

void goToPreviousShot() {
  final currentList = isSightingMode ? sightingShots : shots;
  if (currentList.isEmpty) return;

  setState(() {
    if (currentShotIndex > 0) {
      currentShotIndex--;
      
      // Check if we moved to a previous group (crossed group boundary)
      if (!isSightingMode) {
        final newGroupIndex = currentShotIndex ~/ 5;
        final oldGroupIndex = (currentShotIndex + 1) ~/ 5;
        
        if (newGroupIndex < oldGroupIndex && newGroupIndex < sectionNames.length) {
          // We moved to previous group, update section index
          currentSectionIndex = newGroupIndex;
        }
      }
      
      if (isSightingMode) {
        sightingTime = sightingShots[currentShotIndex].shotTime;
      } else {
        currentShotTime = shots[currentShotIndex].shotTime;
      }
      shotPlaced = true;
    }
  });
}


void goToNextShot() {
  final currentList = isSightingMode ? sightingShots : shots;
  if (currentList.isEmpty) return;

  setState(() {
    if (currentShotIndex < currentList.length - 1) {
      currentShotIndex++;
      
      // Check if we moved to a next group (crossed group boundary)
      if (!isSightingMode) {
        final newGroupIndex = currentShotIndex ~/ 5;
        final oldGroupIndex = (currentShotIndex - 1) ~/ 5;
        
        if (newGroupIndex > oldGroupIndex && newGroupIndex < sectionNames.length) {
          // We moved to next group, update section index
          currentSectionIndex = newGroupIndex;
        }
      }
      
      if (isSightingMode) {
        sightingTime = sightingShots[currentShotIndex].shotTime;
      } else {
        currentShotTime = shots[currentShotIndex].shotTime;
      }
      shotPlaced = true;
    }
  });
}

List<PrecisionShot> getVisibleShots() {
  final currentList = isSightingMode ? sightingShots : shots;
  if (currentList.isEmpty) return [];

  if (isSightingMode) {
    return currentList;
  }

  // Get shots for current batch, excluding malfunction placeholders
  final batchIndex = currentShotIndex ~/ 5;
  final startIndex = batchIndex * 5;
  final endIndex = math.min((batchIndex + 1) * 5, currentList.length);
  
  final batchShots = currentList.sublist(
    startIndex.clamp(0, currentList.length),
    endIndex.clamp(0, currentList.length),
  );
  
  // Filter out malfunction shots (they shouldn't be visible on target)
  return batchShots.where((shot) => !shot.isMalfunction).toList();
}


  String formatDurationWithMillis(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final millis = duration.inMilliseconds.remainder(1000).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

  String formatDurationWithoutMillis(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '00:$minutes:$seconds';
  }

  void toggleFeedback(String feedbackId) {
    if (isSightingMode) {
      if (currentShotIndex < 0 || currentShotIndex >= sightingShots.length) {
        return;
      }
      setState(() {
        final shot = sightingShots[currentShotIndex];
        if (shot.feedback.contains(feedbackId)) {
          shot.feedback.remove(feedbackId);
        } else {
          shot.feedback.add(feedbackId);
        }
      });
    } else {
      if (currentShotIndex < 0 || currentShotIndex >= shots.length) {
        return;
      }
      setState(() {
        final shot = shots[currentShotIndex];
        if (shot.feedback.contains(feedbackId)) {
          shot.feedback.remove(feedbackId);
        } else {
          shot.feedback.add(feedbackId);
        }

        // If marked malfunction/dry/cancel, prepare for re‑shot
        if (feedbackId == 'dry' || feedbackId == 'cross') {
          if (shot.feedback.contains(feedbackId)) {
            // User just selected malfunction
            malfunctionShotGlobalIndex = currentShotIndex;
            hasPendingRetake = true;
            shotPlaced = false;
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('Select one malfunctioned shot to retake'),
            //     backgroundColor: Color(0xFF2A2A2A),
            //     duration: Duration(seconds: 2),
            //   ),
            // );
          } else {
            malfunctionShotGlobalIndex = null;
            hasPendingRetake = false;
          }
        }
      });
    }
  }

  Future<void> saveSessionWithNotes() async {
    if (isSightingMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to actual session before saving'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    final notesController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Add Session Note',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sessionNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${sessionNotes.length} previous '
                  '${sessionNotes.length == 1 ? 'note' : 'notes'} saved',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            TextField(
              controller: notesController,
              maxLines: 5,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter observations, instructions, or feedback...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFD32F2F),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFD32F2F),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              cursorColor: const Color(0xFFD32F2F),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(notesController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Save Session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      sessionNotes.add(
        SessionNote(
          note: result.trim(),
          timestamp: DateTime.now(),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SavingSessionDialog(),
    );

    await saveSession(
      result ?? '',
      photos,
    );
  }

  Future<void> saveSession(String finalNotes, List<PhotoData>? photos) async {
  sessionTimer?.cancel();
  timer?.cancel();
  createRemainingGroup();

  final sessionService = SessionService();
  final currentUser = FirebaseAuth.instance.currentUser;
  final isCoachUser = await isCoachRole(currentUser!.uid);

  // FIXED: Build final shots list - replace malfunction groups with retry shots if they exist
  final List<Map<String, dynamic>> allShots = [];
  
  for (int groupIndex = 0; groupIndex < 6; groupIndex++) {
    final startIdx = groupIndex * 5;
    final endIdx = (groupIndex + 1) * 5;
    
    // Check if this group has a retry
    final retryGroup = shotGroups.firstWhere(
      (g) => g.groupNumber == groupIndex + 1 && g.isRetry == true,
      orElse: () => PrecisionShotGroup(
        groupNumber: 0,
        groupTime: Duration.zero,
        shots: [],
      ),
    );
    
    if (retryGroup.groupNumber > 0 && retryGroup.shots.isNotEmpty) {
      // Use retry shots for this group
      print('✅ Using RETRY shots for group ${groupIndex + 1}');
      allShots.addAll(retryGroup.shots.map((shot) => shot.toMap()));
    } else {
      // Use original shots (filter out malfunction placeholders)
      final confirmedShots = shots.where((s) => s.isConfirmed).toList();
      
      if (startIdx < confirmedShots.length) {
        final groupShots = confirmedShots
            .skip(startIdx)
            .take(5)
            .where((shot) => !shot.isMalfunction) // Filter malfunction placeholders
            .map((shot) => shot.toMap())
            .toList();
        
        if (groupShots.isNotEmpty) {
          print('📊 Using ${groupShots.length} original shots for group ${groupIndex + 1}');
          allShots.addAll(groupShots);
        } else {
          // This group had malfunction and no retry - don't add shots
          print('⚠️ Group ${groupIndex + 1} had malfunction, no retry');
        }
      }
    }
  }

  print('📊 Total shots to save: ${allShots.length}');

  final List<Map<String, dynamic>> sightingData = sightingShots
      .map((shot) => shot.toMap())
      .toList();

  final List<Map<String, dynamic>> allMissedShots = [];
  if (widget.existingMissedShots != null &&
      widget.existingMissedShots!.isNotEmpty) {
    allMissedShots.addAll(
      widget.existingMissedShots!.map((missed) => missed.toJson()),
    );
  }
  allMissedShots.addAll(
    missedShots
        .skip(widget.existingMissedShots?.length ?? 0)
        .map((missed) => missed.toJson()),
  );

  final List<Map<String, dynamic>> allNotesData =
      sessionNotes.map((note) => note.toJson()).toList();

  await sessionService.saveSessionShots(
    sessionId: widget.sessionId,
    shots: allShots,
    totalScore: _calculateFinalScore(), // Calculate score from final shots
    totalTime: totalSessionTime,
    notes: finalNotes,
    notesList: allNotesData,
    shotGroups: shotGroups.map((group) => group.toMap()).toList(),
    missedShots: allMissedShots,
    sightingShots: sightingData,
    sightingTotalScore: calculateSightingScore,
  );

  if (isCoachUser && photos != null && photos.isNotEmpty) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageUploadProgressDialog(
        totalImages: photos.length,
        uploadProgress: uploadProgress,
      ),
    );

    try {
      await sessionService.saveSessionImages(
        sessionId: widget.sessionId,
        photos: photos,
        onProgress: (current, total) {
          updateUploadProgress(current, total);
        },
      );
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    }
  }

  if (isCoachUser) {
    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('trainingsessions')
          .doc(widget.sessionId)
          .get();

      if (sessionDoc.exists) {
        final data = sessionDoc.data()!;
        final studentId = data['studentId'] as String?;
        if (studentId != null && studentId.isNotEmpty) {
          await sessionService.autoShareWithStudent(widget.sessionId, studentId);
        }
      }
    } catch (e) {
      // Ignore error
    }
  }

  final reportData = PrecisionSessionReportData(
    sessionName: widget.sessionName,
    studentName: widget.studentName,
    shots: allShots,
    totalScore: _calculateFinalScore(),
    totalTime: totalSessionTime,
    eventType: '25m Rapid Pistol',
    notes: finalNotes,
    notesList: sessionNotes,
    shotGroups: shotGroups,
    missedShots: allMissedShots.isNotEmpty
        ? allMissedShots
            .map((m) => MissedShot(
                  shotNumber: m['shotNumber'] as int,
                  feedback: Set<String>.from(m['feedback'] ?? []),
                  shotTime: Duration(milliseconds: m['time'] as int? ?? 0),
                ))
            .toList()
        : null,
    sightingShots: sightingData,
    sightingTotalScore: calculateSightingScore,
  );

  Navigator.of(context, rootNavigator: true).pop();
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => RapidSessionReportScreen(
        reportData: reportData,
        sessionId: widget.sessionId,
        shotsPerTarget: widget.shotsPerTarget,
        photos: photos ?? [],
      ),
    ),
  );
}

// NEW: Calculate final score from the shots we're actually saving
double _calculateFinalScore() {
  double totalScore = 0.0;
  
  for (int groupIndex = 0; groupIndex < 6; groupIndex++) {
    // Check if retry exists for this group
    final retryGroup = shotGroups.firstWhere(
      (g) => g.groupNumber == groupIndex + 1 && g.isRetry == true,
      orElse: () => PrecisionShotGroup(
        groupNumber: 0,
        groupTime: Duration.zero,
        shots: [],
      ),
    );
    
    if (retryGroup.groupNumber > 0 && retryGroup.shots.isNotEmpty) {
      // Use retry shots score
      for (var shot in retryGroup.shots) {
        totalScore += shot.score;
      }
    } else {
      // Use original shots (excluding malfunction placeholders)
      final startIdx = groupIndex * 5;
      final confirmedShots = shots.where((s) => s.isConfirmed).toList();
      
      if (startIdx < confirmedShots.length) {
        final groupShots = confirmedShots
            .skip(startIdx)
            .take(5)
            .where((shot) => !shot.isMalfunction);
        
        for (var shot in groupShots) {
          totalScore += shot.score;
        }
      }
    }
  }
  
  return totalScore;
}


void createRemainingGroup() {
  if (shots.isEmpty) return;
  final confirmedShots = shots.where((shot) => shot.isConfirmed).toList();
  final totalGroupedShots = shotGroups.length * 5;
  final remainingShotsCount = confirmedShots.length - totalGroupedShots;
  if (remainingShotsCount <= 0) return;

  final startIndex = totalGroupedShots;
  final endIndex = confirmedShots.length;
  final remainingGroupShots = confirmedShots.sublist(startIndex, endIndex);

  final groupNumber = shotGroups.length + 1;
  final sectionName = groupNumber - 1 < sectionNames.length
      ? sectionNames[groupNumber - 1]
      : 'Series $groupNumber';

  final existingGroupIndex =
      shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
  
  // CHANGED: Create group with List<PrecisionShot> directly
  final group = PrecisionShotGroup(
    groupNumber: groupNumber,
    groupTime: totalSessionTime,
    groupName: sectionName,
    shots: List<PrecisionShot>.from(remainingGroupShots), // FIXED
  );

  if (existingGroupIndex != -1) {
    shotGroups[existingGroupIndex] = group;
  } else {
    shotGroups.add(group);
  }
}

  final ValueNotifier<int> uploadProgress = ValueNotifier<int>(0);

  void updateUploadProgress(int current, int total) {
    uploadProgress.value = current;
  }

  double get calculateTotalScore {
    final currentList = isSightingMode ? sightingShots : shots;
    return currentList.fold(
      0.0,
      (sum, shot) => sum + shot.score,
    );
  }

  // ---------- UI HELPERS (unchanged except headings & removing shot‑timer row) ----------

  Widget buildTooltipWrapper({
    required Widget child,
    required String label,
    required Alignment alignment,
  }) {
    return Tooltip(
      message: label,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      verticalOffset: 40,
      child: showTooltips
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            )
          : child,
    );
  }

  void showImageNoteDialog(
    Uint8List imageBytes,
    Function(String, Uint8List) onSave,
  ) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(imageBytes, height: 120),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final note = noteController.text;
              onSave(note, imageBytes);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> pickImageFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          showImageNoteDialog(
            bytes,
            (note, originalBytes) async {
              try {
                final localPath = await saveImageLocally(originalBytes);
                final shotGroupIndex = currentShotGroup;
                if (mounted) {
                  setState(() {
                    photos.add(
                      PhotoData(
                        localPath: localPath,
                        note: note,
                        shotGroup: shotGroupIndex,
                      ),
                    );
                  });
                }
              } catch (_) {}
            },
          );
        } else {
          showImageNoteDialog(
            bytes,
            (note, originalBytes) async {
              try {
                final localPath = await saveImageLocally(originalBytes);
                final shotGroupIndex = currentShotGroup;
                if (mounted) {
                  setState(() {
                    photos.add(
                      PhotoData(
                        localPath: localPath,
                        note: note,
                        shotGroup: shotGroupIndex,
                      ),
                    );
                  });
                }
              } catch (_) {}
            },
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error picking image')),
        );
      }
    }
  }

  Future<void> captureImageFromCamera() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          showImageNoteDialog(
            bytes,
            (note, originalBytes) async {
              try {
                final localPath = await saveImageLocally(originalBytes);
                final shotGroupIndex = currentShotGroup;
                if (mounted) {
                  setState(() {
                    photos.add(
                      PhotoData(
                        localPath: localPath,
                        note: note,
                        shotGroup: shotGroupIndex,
                      ),
                    );
                  });
                }
              } catch (_) {}
            },
          );
        } else {
          showImageNoteDialog(
            bytes,
            (note, originalBytes) async {
              try {
                final localPath = await saveImageLocally(originalBytes);
                final shotGroupIndex = currentShotGroup;
                if (mounted) {
                  setState(() {
                    photos.add(
                      PhotoData(
                        localPath: localPath,
                        note: note,
                        shotGroup: shotGroupIndex,
                      ),
                    );
                  });
                }
              } catch (_) {}
            },
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error capturing image')),
        );
      }
    }
  }

  int get currentShotGroup {
    if (shots.isEmpty) return 1;
    return ((shots.length - 1) ~/ 5) + 1;
  }

  Future<String> saveImageLocally(Uint8List imageBytes) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sessionDir =
          Directory('${directory.path}/session_${widget.sessionId}');
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'img_$timestamp.jpg';
      final filePath = '${sessionDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      return filePath;
    } catch (_) {
      rethrow;
    }
  }

  void showImageOptionDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () async {
              Navigator.of(context).pop();
              await pickImageFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () async {
              Navigator.of(context).pop();
              await captureImageFromCamera();
            },
          ),
        ],
      ),
    );
  }

  Future<void> showLightSelector() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleOptionDialog(
        title: 'Light Condition',
        options: const ['Bright', 'Medium', 'Low'],
        currentSelection: selectedLight,
        color: Colors.amber,
      ),
    );
    if (result != null) {
      setState(() {
        selectedLight = result;
      });
    }
  }

  Future<void> showWindDirectionSelector() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => WindDirectionDialog(
        currentDirection: selectedWindDirection,
      ),
    );
    if (result != null) {
      setState(() {
        selectedWindDirection = result;
      });
    }
  }

  Future<void> showClimateSelector() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleOptionDialog(
        title: 'Climate Condition',
        options: const ['Sunny', 'Cloudy', 'Rainy', 'Foggy'],
        currentSelection: selectedClimate,
        color: Colors.green,
      ),
    );
    if (result != null) {
      setState(() {
        selectedClimate = result;
      });
    }
  }

  String getLightIcon() {
    if (selectedLight == null) return 'L';
    switch (selectedLight) {
      case 'Bright':
        return 'B';
      case 'Medium':
        return 'M';
      case 'Low':
        return 'L';
      default:
        return 'L';
    }
  }

  String getWindDirectionIcon() {
    if (selectedWindDirection == null) return '';
    switch (selectedWindDirection) {
      case 'N':
        return '↑';
      case 'NE':
        return '↗';
      case 'E':
        return '→';
      case 'SE':
        return '↘';
      case 'S':
        return '↓';
      case 'SW':
        return '↙';
      case 'W':
        return '←';
      case 'NW':
        return '↖';
      case 'NONE':
        return '0';
      default:
        return '';
    }
  }

  String getClimateIcon() {
    if (selectedClimate == null) return 'C';
    switch (selectedClimate) {
      case 'Sunny':
        return 'S';
      case 'Cloudy':
        return 'C';
      case 'Rainy':
        return 'R';
      case 'Foggy':
        return 'F';
      default:
        return 'C';
    }
  }

  Widget buildSmallIndicatorButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2A2A2A),
          border: Border.all(color: color.withOpacity(0.6), width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: label.length > 1 ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Handle gun malfunction - skip current group
// Handle gun malfunction - skip remaining shots in current group
// FIXED: Safe malfunction handler without complex logic
// SIMPLIFIED: Handle malfunction by filling remaining shots with placeholders
void _handleMalfunction() async {
  if (isSightingMode) return;

  final confirmedShots = shots.where((s) => s.isConfirmed).toList();
  final shotsInCurrentGroup = confirmedShots.skip(currentSectionIndex * 5).take(5).length;
  final remainingInGroup = 5 - shotsInCurrentGroup;

  // Confirm malfunction
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text(
            'Gun Malfunction',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current group: ${sectionNames[currentSectionIndex]}',
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Shots taken: $shotsInCurrentGroup/5',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'This will skip the remaining $remainingInGroup shot${remainingInGroup > 1 ? 's' : ''} in this group.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can retry ONE group at the end.',
            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Confirm Malfunction', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() {
    // Remove any unconfirmed shot
    shots.removeWhere((s) => !s.isConfirmed);
    
    // Fill remaining shots in current group with malfunction placeholders
    final centerPosition = Offset(targetSize / 2, targetSize / 2);
    
    for (int i = 0; i < remainingInGroup; i++) {
      shots.add(
        PrecisionShot(
          position: centerPosition,
          shotTime: Duration.zero,
          isConfirmed: true, // Mark as confirmed so it's counted
          feedback: {'malfunction'}, // Special feedback tag
          score: 0.0,
          ringNumber: 0,
          light: null,
          wind: null,
          climate: null,
          isMalfunction: true, // NEW: Mark as malfunction
        ),
      );
    }

    // Track this group as having malfunction
    if (!malfunctionedGroupIndices.contains(currentSectionIndex)) {
      malfunctionedGroupIndices.add(currentSectionIndex);
    }

    // Save the group (including malfunction shots)
    final allShotsInGroup = shots.where((s) => s.isConfirmed).skip(currentSectionIndex * 5).take(5).toList();
    
    final malfunctionGroup = PrecisionShotGroup(
      groupNumber: currentSectionIndex + 1,
      groupTime: totalSessionTime,
      groupName: sectionNames[currentSectionIndex],
      isMalfunction: true,
      shots: List<PrecisionShot>.from(allShotsInGroup),
    );

    final existingIndex = shotGroups.indexWhere((g) => g.groupNumber == malfunctionGroup.groupNumber);
    if (existingIndex != -1) {
      shotGroups[existingIndex] = malfunctionGroup;
    } else {
      shotGroups.add(malfunctionGroup);
    }

    // Move to next section
    if (currentSectionIndex < sectionNames.length - 1) {
      currentSectionIndex++;
      
      // Add new shot for next section
      shots.add(
        PrecisionShot(
          position: centerPosition,
          shotTime: Duration.zero,
          isConfirmed: false,
          feedback: {},
          score: 0.0,
          ringNumber: 0,
        ),
      );
      
      currentShotIndex = shots.length - 1;
      shotPlaced = true;
    } else {
      // All sections done, check if retry available
      Future.delayed(const Duration(milliseconds: 300), () {
        _checkForRetryOption();
      });
    }
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group "${sectionNames[currentSectionIndex >= 1 ? currentSectionIndex - 1 : 0]}" marked as malfunctioned'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


// Check if user wants to retry any malfunctioned group
void _checkForRetryOption() async {
  if (malfunctionedGroupIndices.isEmpty || hasUsedRetry) {
    return;
  }

  final selectedGroupIndex = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text(
                'All Shots Placed',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${malfunctionedGroupIndices.length} Malfunction${malfunctionedGroupIndices.length > 1 ? 's' : ''} Occurred',
                  style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You can retry ONE malfunctioned group:',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...malfunctionedGroupIndices.map((groupIndex) {
            final group = shotGroups.firstWhere(
              (g) => g.groupNumber == groupIndex + 1,
              orElse: () => PrecisionShotGroup(
                groupNumber: 0,
                groupTime: Duration.zero,
                shots: [],
              ),
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, groupIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  foregroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Column(
                  children: [
                    Text(
                      sectionNames[groupIndex],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${group.shots.length} shots taken',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Skip Retry & Save'),
          ),
        ],
      ),
    ),
  );

  if (selectedGroupIndex != null) {
    _startRetryForGroup(selectedGroupIndex);
  }
}


// SIMPLIFIED: Start retry - just allow 5 more shots (31-35)
void _startRetryForGroup(int groupIndex) {
  setState(() {
    hasUsedRetry = true;
    retryGroupIndex = groupIndex;
    currentSectionIndex = groupIndex; // Show the retry section name
    
    // Just add a new shot to continue (shots 31-35 will be retry shots)
    final exactCenter = Offset(targetSize / 2, targetSize / 2);
    shots.add(
      PrecisionShot(
        position: exactCenter,
        shotTime: Duration.zero,
        isConfirmed: false,
        feedback: {},
        score: 0.0,
        ringNumber: 0,
      ),
    );
    
    currentShotIndex = shots.length - 1;
    shotPlaced = true;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Retrying: ${sectionNames[groupIndex]} - Take 5 shots'),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 2),
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    final currentList = isSightingMode ? sightingShots : shots;
    final currentShot =
        (currentShotIndex >= 0 && currentShotIndex < currentList.length)
            ? currentList[currentShotIndex]
            : null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isSightingMode ? Colors.orange : const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
              ),
child: Text(
        isSightingMode 
          ? 'Sighting' 
          : (retryGroupIndex != null 
              ? 'RETRY: ${sectionNames[currentSectionIndex]}'
              : sectionNames[currentSectionIndex]),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    
            ),
            const SizedBox(width: 12),
            if (!isSightingMode)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Session Time',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Text(
                    formatDurationWithoutMillis(totalSessionTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (isSightingMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: switchToActualSession,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!isSightingMode)
            // OutlinedButton(
            //   onPressed: toggleSession,
            //   style: OutlinedButton.styleFrom(
            //     foregroundColor:
            //         isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
            //     side: BorderSide(
            //       color:
            //           isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
            //     ),
            //     padding:
            //         const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            //     minimumSize: const Size(0, 0),
            //   ),
            //   child: Text(
            //     isSessionActive ? 'End' : 'Begin',
            //     style: const TextStyle(fontSize: 11),
            //   ),
            // ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: showTooltips ? const Color(0xFFD32F2F) : Colors.white,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                showTooltips = !showTooltips;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onPanUpdate: (details) {
                              if (!shotPlaced) return;
                              final renderBox = targetKey.currentContext
                                  ?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox
                                    .globalToLocal(details.globalPosition);
                                updateShotPosition(localPosition);
                              }
                            },
                            onTapDown: (details) {
                              if (!shotPlaced) return;
                              final renderBox = targetKey.currentContext
                                  ?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox
                                    .globalToLocal(details.globalPosition);
                                updateShotPosition(localPosition);
                              }
                            },
                            child: Container(
                              key: targetKey,
                              width: targetSize,
                              height: targetSize,
                              child: ClipOval(
                                child: Transform.scale(
                                  scale: zoomLevel,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(targetSize, targetSize),
                                        painter: RapidTargetPainter(
                                          shots: getVisibleShots(),
                                          currentShotIndex: currentShotIndex,
                                          targetSize: targetSize,
                                          shotsPerBatch: 5
                                        ),
                                      ),
                                      CustomPaint(
                                        size: Size(targetSize, targetSize),
                                        painter: BorderPainter(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isSightingMode)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: CustomPaint(
                                  painter: SightingTrianglePainter(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
// In the build method, update the row with camera icon:

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 120),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // NEW: Malfunction button
                                if (!isSightingMode)
                                  buildTooltipWrapper(
                                    label: 'Gun Malfunction',
                                    alignment: Alignment.topCenter,
                                    child: IconButton(
                                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                      onPressed: _handleMalfunction,
                                      padding: const EdgeInsets.all(6),
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                buildTooltipWrapper(
                                  label: 'Add Image',
                                  alignment: Alignment.topCenter,
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                                    onPressed: showImageOptionDialog,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildSmallIndicatorButton(
                                  label: getLightIcon(),
                                  color: Colors.amber,
                                  onTap: showLightSelector,
                                ),
                                const SizedBox(width: 8),
                                buildSmallIndicatorButton(
                                  label: getWindDirectionIcon(),
                                  color: Colors.blue,
                                  onTap: showWindDirectionSelector,
                                ),
                                const SizedBox(width: 8),
                                buildSmallIndicatorButton(
                                  label: getClimateIcon(),
                                  color: Colors.green,
                                  onTap: showClimateSelector,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 30),
                          child: buildTooltipWrapper(
                            label: 'Zoom Out',
                            alignment: Alignment.topCenter,
                            child: IconButton(
                              icon: const Icon(Icons.zoom_out),
                              color: Colors.white,

                              onPressed:
                                  zoomLevel > minZoom ? zoomOut : null,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: buildTooltipWrapper(
                              label: 'Current',
                              alignment: Alignment.topCenter,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFD32F2F),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (currentShot?.score ?? 0.0)
                                        .toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: buildTooltipWrapper(
                              label: 'Total',
                              alignment: Alignment.topCenter,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFD32F2F),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    calculateTotalScore.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 30),
                          child: buildTooltipWrapper(
                            label: 'Zoom In',
                            alignment: Alignment.topCenter,
                            child: IconButton(
                              icon: const Icon(Icons.zoom_in),
                              color: Colors.white,

                              onPressed:
                                  zoomLevel < maxZoom ? zoomIn : null,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildTooltipWrapper(
                          label: 'Previous',
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left),
                            color: Colors.white,

                            onPressed: currentList.isNotEmpty
                                ? goToPreviousShot
                                : null,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 12),
                        buildTooltipWrapper(
                          label: 'Shot',
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD32F2F),
                              ),
                            ),
                            child: Text(
                              '${currentShotIndex + 1}/${currentList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        buildTooltipWrapper(
                          label: 'Next / Confirm',
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right),
                            color: Colors.white,

                            onPressed: () {
                              if (currentShotIndex < 0 ||
                                  currentShotIndex >= currentList.length) {
                                return;
                              }
                              final current = currentList[currentShotIndex];

                              if (current.feedback.contains('dry') ||
                                  current.feedback.contains('cross')) {
                                // treat as malfunction -> store as missed & prepare new shot
                                setState(() {
                                  if (isSightingMode) {
                                    missedShots.add(
                                      MissedShot(
                                        shotNumber: currentShotIndex + 1,
                                        feedback:
                                            Set<String>.from(current.feedback),
                                        shotTime: sightingTime,
                                      ),
                                    );
                                    sightingShots.removeAt(currentShotIndex);
                                  } else {
                                    missedShots.add(
                                      MissedShot(
                                        shotNumber: currentShotIndex + 1,
                                        feedback:
                                            Set<String>.from(current.feedback),
                                        shotTime: currentShotTime,
                                      ),
                                    );
                                    shots.removeAt(currentShotIndex);
                                  }
                                  addNewShot();
                                  shotPlaced = true;
                                  if (isSightingMode) {
                                    sightingTime = Duration.zero;
                                  } else {
                                    currentShotTime = Duration.zero;
                                  }
                                });
                                return;
                              }

                              if (current.isConfirmed) {
                                goToNextShot();
                              } else {
                                confirmCurrentShot();
                              }
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // SHOT TIME ROW REMOVED FROM UI (per your request)

                    if (isCoach)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                        ),
                        child: Column(
                          children: [
                            // Row 1
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCompactFeedbackButton('lifting', 'Lifting', currentShot),
                                  _buildCompactFeedbackButton('grip', 'Grip', currentShot),
                                  _buildCompactFeedbackButton('body_twist', 'Body Movement Twist', currentShot),
                                  _buildCompactFeedbackButton('ft', 'Follow Through', currentShot),
                                  _buildCompactFeedbackButton('sight_focus', 'Sight Focus', currentShot),
                                  _buildCompactFeedbackButton('movement_target', 'Movement from Target to Target', currentShot),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Row 2
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCompactFeedbackButton('settling', 'Settling on Target', currentShot),
                                  _buildCompactFeedbackButton('wrist', 'Wrist', currentShot),
                                  _buildCompactFeedbackButton('dry', 'Dry', currentShot),
                                  _buildCompactFeedbackButton('sitting', 'Sitting', currentShot),
                                  _buildCompactFeedbackButton('cross', 'Cancel', currentShot),
                                  _buildCompactFeedbackButton('shoot_tick', 'Perfect Shot', currentShot),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Row 3
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCompactFeedbackButton('lh', 'Long Hold', currentShot),
                                  _buildCompactFeedbackButton('interaction', 'Interaction with Coach', currentShot),
                                  _buildCompactFeedbackButton('body_movement', 'Body Movement', currentShot),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                  ],
                ),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1A1A1A),
            padding:
                const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSightingMode ? null : saveSessionWithNotes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSightingMode
                          ? Colors.grey
                          : const Color(0xFFD32F2F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFeedbackButton(
      String iconId, String label, PrecisionShot? currentShot) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: buildTooltipWrapper(
        label: label,
        alignment: Alignment.topCenter,
        child: ShootingFeedbackIcons.buildFeedbackButton(
          iconId: iconId,
          isSelected: currentShot?.feedback.contains(iconId) ?? false,
          onPressed: () => toggleFeedback(iconId),
        ),
      ),
    );
  }
}

class BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Painter for 25m Precision Pistol Target
class RapidTargetPainter extends CustomPainter {
  final List<PrecisionShot> shots;
  final int currentShotIndex;
  final double targetSize;
  final int shotsPerBatch;

  RapidTargetPainter({
    required this.shots,
    required this.currentShotIndex,
    required this.targetSize,
    required this.shotsPerBatch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    // ✅ Scale factor: 400mm outer diameter (ring 5)
    final scale = targetSize / 400.0;

    // ✅ 25m Rapid Fire Target - Ring DIAMETERS in mm
    final Map<int, double> ringDiameters = {
      10: 100.0,
      9: 160.0,
      8: 220.0,
      7: 280.0,
      6: 340.0,
      5: 400.0,
    };

    // Convert diameters to radii in pixels
    final Map<int, double> ringRadii = {};
    ringDiameters.forEach((ring, diameter) {
      ringRadii[ring] = (diameter / 2) * scale;
    });

    final double innerTenRadius = (56.0 / 2.0) * scale; // Inner 10 ring (100mm diameter)

    // ✅ Draw rings 5-10 - ALL BLACK with WHITE borders
    for (int ringNum = 5; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black..style = PaintingStyle.fill,
      );
      
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale,
      );
    }

    // ✅ Draw numbers 6-9 ONLY at TOP and BOTTOM
    for (int ringNum = 5; ringNum <= 9; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;

      // TOP and BOTTOM only
      for (int angle in [90, 270]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }

    // ✅ TWO AIMING LINES with gaps
    final Paint linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5 * scale
      ..style = PaintingStyle.stroke;

    // LEFT Line: Ring 5 OUTER edge → INNER (with gap)
    final ring5Radius = ringRadii[5]!;
    final innerGap = 95.0 * scale;
    final leftInnerEndRadius = ring5Radius - innerGap;

    canvas.drawLine(
      Offset(center.dx - ring5Radius, center.dy),  // START: Ring 5 outer edge (left)
      Offset(center.dx - leftInnerEndRadius, center.dy),  // END: Inner with gap
      linePaint,
    );

    // RIGHT line: Ring 5 OUTER edge → INNER (with gap)
    final rightInnerEndRadius = ring5Radius - innerGap;

    canvas.drawLine(
      Offset(center.dx + ring5Radius, center.dy),    // START: Ring 5 outer edge (right)
      Offset(center.dx + rightInnerEndRadius, center.dy),  // END: Inner with gap
      linePaint,
    );

    // ✅ Inner ten (white border only)
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    // ✅ Draw shots - FIXED batch logic
    if (shots.isNotEmpty) {
      final pelletRadius = 5.6 / 2 * scale;

      for (int i = 0; i < shots.length; i++) {
        // FIXED: Pass the actual global currentShotIndex to get correct opacity
        double opacity = _getOpacityForShot(i, currentShotIndex, shotsPerBatch, shots.length);

        if (opacity == 0.0) continue;

        final shot = shots[i];
        
        // FIXED: Determine if current based on position within visible batch
        final currentBatchStart = (currentShotIndex ~/ shotsPerBatch) * shotsPerBatch;
        final indexInBatch = currentShotIndex - currentBatchStart;
        final isCurrent = i == indexInBatch;
        
        final baseColor = isCurrent ? Colors.red : Colors.blue;
        final shotColor = baseColor.withOpacity(opacity);

        canvas.drawCircle(
          shot.position,
          pelletRadius,
          Paint()..color = shotColor..style = PaintingStyle.fill,
        );
        
        canvas.drawCircle(
          shot.position,
          pelletRadius,
          Paint()
            ..color = Colors.white.withOpacity(opacity * 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5 * scale,
        );
      }
    }
  }

  double _getOpacityForShot(int shotIndex, int currentShotIndex, int shotsPerBatch, int totalShots) {
    // shotIndex is the position within the visible batch (0-4)
    // currentShotIndex is the global shot index
    
    // Calculate which position in the current batch we're looking at
    final currentBatchStart = (currentShotIndex ~/ shotsPerBatch) * shotsPerBatch;
    final globalShotIndex = currentBatchStart + shotIndex;
    
    // Don't show future shots
    if (globalShotIndex > currentShotIndex) return 0.0;

    // Calculate position within current batch
    final indexInBatch = currentShotIndex - currentBatchStart;
    
    // If this is the current shot
    if (shotIndex == indexInBatch) {
      return 1.0; // Full opacity for current shot
    }
    
    // For previous shots in the same batch, show with varying opacity
    if (shotIndex < indexInBatch) {
      final shotsInBatch = indexInBatch + 1; // +1 because we include current
      return 0.5 + 0.5 * (shotIndex / (shotsInBatch - 1));
    }
    
    return 0.5; // Default for other visible shots
  }

  @override
  bool shouldRepaint(covariant RapidTargetPainter oldDelegate) => true;
}


// Sighting Triangle Indicator Painter
class SightingTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0) // Top-right corner
      ..lineTo(size.width, size.height) // Bottom-right
      ..lineTo(size.width - size.height, 0) // Top-left of triangle
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// // Data model for Precision Report
// class PrecisionSessionReportData {
//   final String sessionName;
//   final String studentName;
//   final List<Map<String, dynamic>> shots;
//   final double totalScore;
//   final Duration totalTime;
//   final String eventType;
//   final String? notes;
//   final List<SessionNote>? notesList;
//   final List<PrecisionShotGroup>? shotGroups;
//   final List<MissedShot>? missedShots;
//   final List<Map<String, dynamic>>? sightingShots;
//   final double? sightingTotalScore;

//   PrecisionSessionReportData({
//     required this.sessionName,
//     required this.studentName,
//     required this.shots,
//     required this.totalScore,
//     required this.totalTime,
//     required this.eventType,
//     this.notes,
//     this.notesList,
//     this.shotGroups,
//     this.missedShots,
//     this.sightingShots,
//     this.sightingTotalScore,
//   });
// }

// Simple Option Dialog (for Light/Climate)
class SimpleOptionDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? currentSelection;
  final Color color;

  const SimpleOptionDialog({
    super.key,
    required this.title,
    required this.options,
    this.currentSelection,
    required this.color,
  });

  @override
  State<SimpleOptionDialog> createState() => _SimpleOptionDialogState();
}

class _SimpleOptionDialogState extends State<SimpleOptionDialog> {
  String? selectedOption;

  @override
  void initState() {
    super.initState();
    selectedOption = widget.currentSelection;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select an option',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ...widget.options.map((option) {
              final isSelected = selectedOption == option;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedOption = option;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.color.withOpacity(0.2)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? widget.color : widget.color.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? widget.color : Colors.transparent,
                            border: Border.all(color: widget.color, width: 2),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: selectedOption != null ? () => Navigator.pop(context, selectedOption) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Wind Direction Dialog
class WindDirectionDialog extends StatefulWidget {
  final String? currentDirection;

  const WindDirectionDialog({super.key, this.currentDirection});

  @override
  State<WindDirectionDialog> createState() => _WindDirectionDialogState();
}

class _WindDirectionDialogState extends State<WindDirectionDialog> {
  String? selectedDirection;

  @override
  void initState() {
    super.initState();
    selectedDirection = widget.currentDirection;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate responsive sizes
    final maxDialogHeight = screenHeight * 0.8; // 80% of screen height
    final maxDialogWidth = screenWidth * 0.9; // 90% of screen width
    
    // Calculate circle size based on available space
    final maxCircleSize = math.min(
      maxDialogWidth - 48, // padding consideration
      maxDialogHeight - 200, // space for header and buttons
    );
    final circleSize = math.min(280.0, maxCircleSize);
    
    // Scale other elements proportionally
    final buttonSize = circleSize * 0.214; // ~60 when circle is 280
    final centerButtonSize = buttonSize;
    final radius = circleSize * 0.393; // ~110 when circle is 280
    final centerOffset = circleSize / 2;
    
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wind Direction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select wind direction or no wind',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: circleSize,
                height: circleSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Circle background
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    // Compass lines
                    CustomPaint(
                      size: Size(circleSize, circleSize),
                      painter: CompassLinesPainter(),
                    ),
                    // Direction buttons
                    ..._buildDirectionButtons(
                      circleSize: circleSize,
                      buttonSize: buttonSize,
                      radius: radius,
                      centerOffset: centerOffset,
                    ),
                    // Center "No wind" button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDirection = 'NONE';
                        });
                      },
                      child: Container(
                        width: centerButtonSize,
                        height: centerButtonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selectedDirection == 'NONE'
                              ? Colors.blue
                              : const Color(0xFF2A2A2A),
                          border: Border.all(
                            color: selectedDirection == 'NONE'
                                ? Colors.white
                                : Colors.blue.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: selectedDirection == 'NONE'
                                  ? Colors.white
                                  : Colors.blue,
                              fontSize: centerButtonSize * 0.4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: selectedDirection != null
                        ? () => Navigator.pop(context, selectedDirection)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDirectionButtons({
    required double circleSize,
    required double buttonSize,
    required double radius,
    required double centerOffset,
  }) {
    final directions = [
      {'label': 'N', 'icon': '↑', 'angle': 0.0, 'name': 'North'},
      {'label': 'NE', 'icon': '↗', 'angle': 45.0, 'name': 'North East'},
      {'label': 'E', 'icon': '→', 'angle': 90.0, 'name': 'East'},
      {'label': 'SE', 'icon': '↘', 'angle': 135.0, 'name': 'South East'},
      {'label': 'S', 'icon': '↓', 'angle': 180.0, 'name': 'South'},
      {'label': 'SW', 'icon': '↙', 'angle': 225.0, 'name': 'South West'},
      {'label': 'W', 'icon': '←', 'angle': 270.0, 'name': 'West'},
      {'label': 'NW', 'icon': '↖', 'angle': 315.0, 'name': 'North West'},
    ];

    return directions.map((dir) {
      final angle = (dir['angle'] as double) * math.pi / 180;
      final x = radius * math.sin(angle);
      final y = -radius * math.cos(angle);

      return Positioned(
        left: centerOffset + x - (buttonSize / 2),
        top: centerOffset + y - (buttonSize / 2),
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedDirection = dir['label'] as String;
            });
          },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selectedDirection == dir['label']
                  ? Colors.blue
                  : const Color(0xFF2A2A2A),
              border: Border.all(
                color: selectedDirection == dir['label']
                    ? Colors.white
                    : Colors.blue.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dir['icon'] as String,
                  style: TextStyle(
                    color: selectedDirection == dir['label']
                        ? Colors.white
                        : Colors.blue,
                    fontSize: buttonSize * 0.33,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: buttonSize * 0.033),
                Text(
                  dir['label'] as String,
                  style: TextStyle(
                    color: selectedDirection == dir['label']
                        ? Colors.white
                        : Colors.blue.withOpacity(0.7),
                    fontSize: buttonSize * 0.167,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}


class CompassLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * math.pi / 180;
      final endX = center.dx + 140 * math.sin(angle);
      final endY = center.dy - 140 * math.cos(angle);

      canvas.drawLine(center, Offset(endX, endY), paint);
    }

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 40.0 * i, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Placeholder for report screen
// class PrecisionSessionReportScreen extends StatelessWidget {
//   final PrecisionSessionReportData reportData;
//   final String sessionId;
//   final int shotsPerTarget;
//   final List<PhotoData> photos;

//   const PrecisionSessionReportScreen({
//     super.key,
//     required this.reportData,
//     required this.sessionId,
//     required this.shotsPerTarget,
//     required this.photos,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Precision Report'),
//         backgroundColor: const Color(0xFF1A1A1A),
//       ),
//       body: Center(
//         child: Text(
//           'Precision Report Screen\n(Create separately)',
//           style: const TextStyle(color: Colors.white),
//           textAlign: TextAlign.center,
//         ),
//       ),
//       backgroundColor: const Color(0xFF1A1A1A),
//     );
//   }
// }

// Placeholder dialogs
class SavingSessionDialog extends StatelessWidget {
  const SavingSessionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Saving session...'),
          ],
        ),
      ),
    );
  }
}

class ImageUploadProgressDialog extends StatelessWidget {
  final int totalImages;
  final ValueNotifier<int> uploadProgress;

  const ImageUploadProgressDialog({
    super.key,
    required this.totalImages,
    required this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Uploading images...'),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: uploadProgress,
              builder: (context, progress, child) {
                return Text('$progress / $totalImages');
              },
            ),
          ],
        ),
      ),
    );
  }
}
