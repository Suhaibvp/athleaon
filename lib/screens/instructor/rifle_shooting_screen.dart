import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'session_report_screen.dart';
import '../../widgets/shooting_feedback_icons.dart'; // ✅ Import
import '../../services/session_service.dart';
import 'pistol_shooting_screen.dart';
import '../../models/missed_shoot.dart';
import '../../models/session_notes.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/photo_data.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection; // ✅ Hide the conflicting class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// class Shot {
//   Offset position;
//   Duration shotTime;
//   bool isConfirmed;
//   Set<String> feedback;
//   double score;
//   int ringNumber;

//   Shot({
//     required this.position,
//     required this.shotTime,
//     this.isConfirmed = false,
//     Set<String>? feedback,
//     this.score = 0.0,
//     this.ringNumber = 0,
//   }) : feedback = feedback ?? {};
// }

class RifleShootingScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;
  final List<Map<String, dynamic>>? existingShots;
  final String? studentName;  // ✅ NEW: Add this parameter
  final List<MissedShot>? existingMissedShots;
  final List<PhotoData>? existingImages; 
  final List<ShotGroup>?existingShotGroups;
  final List<SessionNote>? existingNotes;
  final List<Map<String, dynamic>>? existingSightingShots;
  const RifleShootingScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.shotsPerTarget,
    this.existingShots,
    this.studentName,  // ✅ NEW: Add this here
    this.existingMissedShots,
    this.existingImages,
    this.existingShotGroups,
    this.existingNotes,
    this.existingSightingShots,
  });

  @override
  State<RifleShootingScreen> createState() => _RifleShootingScreenState();
}


class _RifleShootingScreenState extends State<RifleShootingScreen> {
bool _isCoach = false;
    bool _isSightingMode = true; // Start in sighting mode
  List<Shot> _sightingShots = []; // Separate list for sighting shots
  Duration _sightingTime = Duration.zero; // Separate time for sighting
  double _sightingTotalScore = 0.0; // Separate score for sighting


  Timer? _timer;
  Timer? _sessionTimer;
  
  Duration _currentShotTime = Duration.zero;
  Duration _totalSessionTime = Duration.zero; // ✅ Session time (top timer)
  Duration _accumulatedSessionTime = Duration.zero; // ✅ For session pause/resume
  bool _isTimerRunning = false;
  bool _isSessionActive = false; // ✅ Session state
  bool _sessionStarted = false; // ✅ Has session started
  bool _shotPlaced = false;
 bool _justCreatedShot = false;
  List<Shot> _shots = [];
  int _currentShotIndex = -1;
// ✅ NEW: Zoom variables
double _zoomLevel = 1.0;
final double _minZoom = 1.0;
final double _maxZoom = 3.0;
final double _zoomStep = 0.2;
Offset _zoomOffset = Offset.zero;
final double _targetSize = 280.0;
  final GlobalKey _targetKey = GlobalKey();
  final double targetSize = 280.0;
  List<SessionNote> sessionNotes = [];
  Offset? _magnifierPosition;
  List<ShotGroup> _shotGroups = []; // ✅ Add this with other variables
List<MissedShot> _missedShots = []; // ✅ Add this with other variables
bool _showTooltips = false;
List<PhotoData> _photos = [];
  @override
  void initState() {
    super.initState();
     _shotGroups.clear();
    loadExistingShots();
    _checkUserRole();
          if (widget.existingNotes != null && widget.existingNotes!.isNotEmpty) {
      sessionNotes = List<SessionNote>.from(widget.existingNotes!);
    }
      if (_shots.isEmpty) {
    addNewShot();
    _shotPlaced = true;
  }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final isCoach = await _isCoachRole(currentUser.uid);
    setState(() {
      _isCoach = isCoach;
    });
  }
}
// ✅ NEW: Zoom In function
void _zoomIn() {
  setState(() {
    if (_zoomLevel < _maxZoom) {
      _zoomLevel += _zoomStep;
      _zoomLevel = _zoomLevel.clamp(_minZoom, _maxZoom);
    }
  });
}

// ✅ NEW: Zoom Out function
void _zoomOut() {
  setState(() {
    if (_zoomLevel > _minZoom) {
      _zoomLevel -= _zoomStep;
      _zoomLevel = _zoomLevel.clamp(_minZoom, _maxZoom);
      if (_zoomLevel == _minZoom) {
        _zoomOffset = Offset.zero;
      }
    }
  });
}

  void _switchToActualSession() {
    setState(() {
      _isSightingMode = false;
      
      // Reset everything for actual session
      _shots.clear();
      _currentShotIndex = -1;
      _shotGroups.clear();
      _currentShotTime = Duration.zero;
      _totalSessionTime = Duration.zero;
      _accumulatedSessionTime = Duration.zero;
      
      // Stop all timers
      _timer?.cancel();
      _sessionTimer?.cancel();
      _isTimerRunning = false;
      _isSessionActive = false;
      _sessionStarted = false;
      
      // Reset zoom
      _zoomLevel = 1.0;
      _zoomOffset = Offset.zero;
      
      // Add first shot for actual session
      addNewShot();
      _shotPlaced = true;
    });
    _startSessionTimer();
  }

    double get _calculateSightingScore {
    return _sightingShots.fold(0.0, (sum, shot) => sum + shot.score);
  }

// ✅ NEW: Adjust position for zoom level
Offset _adjustPositionForZoom(Offset localPosition) {
  if (_zoomLevel == 1.0) return localPosition;
  
  final center = Offset(280 / 2, 280 / 2);
  final offsetFromCenter = localPosition - center;
  final adjustedOffset = offsetFromCenter / _zoomLevel;
  return center + adjustedOffset + _zoomOffset;
}

void loadExistingShots() {
  if (widget.existingShots != null && widget.existingShots!.isNotEmpty) {
    setState(() {
      _shotGroups.clear();
      _shots = widget.existingShots!.map((shotData) {
        return Shot(
          position: Offset(shotData['x'], shotData['y']),
          shotTime: Duration(milliseconds: shotData['time']),
          isConfirmed: true,
          feedback: Set<String>.from(shotData['feedback'] ?? []),
          score: (shotData['score'] ?? 0.0).toDouble(),
          ringNumber: shotData['ring'] ?? 0,
        );
      }).toList();

      // Restore session time
      if (widget.existingShotGroups != null &&
          widget.existingShotGroups!.isNotEmpty) {
        final lastGroup = widget.existingShotGroups!.last;
        _accumulatedSessionTime = lastGroup.groupTime;
        _totalSessionTime = _accumulatedSessionTime;
      }

      // Load existing images
      if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
        _photos.addAll(widget.existingImages!);
      }

      // Load missed shots
      if (widget.existingMissedShots != null &&
          widget.existingMissedShots!.isNotEmpty) {
        _missedShots = List<MissedShot>.from(widget.existingMissedShots!);
      }

      // NEW: Load sighting shots
      if (widget.existingSightingShots != null &&
          widget.existingSightingShots!.isNotEmpty) {
        _sightingShots = widget.existingSightingShots!.map((shotData) {
          return Shot(
            position: Offset(shotData['x'], shotData['y']),
            shotTime: Duration(milliseconds: shotData['time']),
            isConfirmed: true,
            feedback: Set<String>.from(shotData['feedback'] ?? []),
            score: (shotData['score'] ?? 0.0).toDouble(),
            ringNumber: shotData['ring'] ?? 0,
          );
        }).toList();
        
        // If sighting shots exist, we're NOT in sighting mode (we've already completed sighting)
        _isSightingMode = false;
      }

      // Add new shot for editing
      final exactCenter = Offset(targetSize / 2, targetSize / 2);
      _shots.add(Shot(
        position: exactCenter,
        shotTime: Duration.zero,
        isConfirmed: false,
        feedback: {},
        score: 0.0,
        ringNumber: 0,
      ));
      _currentShotIndex = _shots.length - 1;
      _shotPlaced = true;
    });
  } else {
    // NEW: Check if there are existing sighting shots (editing session with only sighting)
    if (widget.existingSightingShots != null &&
        widget.existingSightingShots!.isNotEmpty) {
      setState(() {
        _sightingShots = widget.existingSightingShots!.map((shotData) {
          return Shot(
            position: Offset(shotData['x'], shotData['y']),
            shotTime: Duration(milliseconds: shotData['time']),
            isConfirmed: true,
            feedback: Set<String>.from(shotData['feedback'] ?? []),
            score: (shotData['score'] ?? 0.0).toDouble(),
            ringNumber: shotData['ring'] ?? 0,
          );
        }).toList();
        
        // Start in sighting mode to add more sighting shots
        _isSightingMode = true;
        
        // Add new sighting shot
        addNewShot();
        _shotPlaced = true;
      });
    }
  }
}



Widget _buildTooltipWrapper({
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
    child: _showTooltips
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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


  // ✅ Toggle Begin/End session
 // Add these variables to your state
DateTime? _sessionStartTime;
DateTime? _shotStartTime;

// Replace _startSessionTimer with:
  void _startSessionTimer() {
    _sessionStartTime = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        // Session time = accumulated (from previous session) + current elapsed
        _totalSessionTime = _accumulatedSessionTime + 
                          DateTime.now().difference(_sessionStartTime!);
      });
    });
  }

// Replace _toggleTimer with:
  void toggleTimer() {
    if (!_sessionStarted && !_isSightingMode) {
      _toggleSession(); // Auto-start session if not started (only in actual mode)
    }

    setState(() {
      _isTimerRunning = !_isTimerRunning;
      
      if (_isTimerRunning) {
        _shotStartTime = DateTime.now();
        _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          setState(() {
            final elapsed = DateTime.now().difference(_shotStartTime!);
            
            if (_isSightingMode) {
              _sightingTime = elapsed;
              if (_currentShotIndex >= 0 && _currentShotIndex < _sightingShots.length) {
                _sightingShots[_currentShotIndex].shotTime = _sightingTime;
              }
            } else {
              _currentShotTime = elapsed;
              if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
                _shots[_currentShotIndex].shotTime = _currentShotTime;
              }
            }
          });
        });
      } else {
        _timer?.cancel();
      }
    });
  }


// Update _toggleSession to handle pause/resume:
  void _toggleSession() {
    setState(() {
      _isSessionActive = !_isSessionActive;

      if (_isSessionActive) {
        if (!_sessionStarted) {
          _sessionStarted = true;
        }
        _startSessionTimer();
      } else {
        // Pause session timer
        _sessionTimer?.cancel();
        if (_sessionStartTime != null) {
          _accumulatedSessionTime = _totalSessionTime; // Save current total
        }
        _sessionStartTime = null;
      }
    });
  }

  void addNewShot() {
    setState(() {
      if (_isSightingMode) {
        _sightingShots.add(Shot(
          position: Offset(targetSize / 2, targetSize / 2),
          shotTime: _sightingTime,
        ));
        _currentShotIndex = _sightingShots.length - 1;
      } else {
        _shots.add(Shot(
          position: Offset(targetSize / 2, targetSize / 2),
          shotTime: _currentShotTime,
        ));
        _currentShotIndex = _shots.length - 1;
      }
    });
  }

  void confirmCurrentShot() {
    if (_currentShotIndex < 0) return;
    
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (_currentShotIndex >= currentList.length) return;
    
    final shot = currentList[_currentShotIndex];
    
    if (!shot.isConfirmed) {
      _calculateScore(shot);
      
      setState(() {
        shot.isConfirmed = true;
        _printShotData(shot, _currentShotIndex + 1);
        
        // Only create shot groups in actual session mode
        if (!_isSightingMode) {
          if (_shots.length % 10 == 0) {
            final groupNumber = _shots.length ~/ 10;
            final startIndex = (groupNumber - 1) * 10;
            final endIndex = groupNumber * 10;
            final groupShots = _shots.sublist(startIndex, endIndex);
            final groupTime = _totalSessionTime;
            
            _shotGroups.add(ShotGroup(
              groupNumber: groupNumber,
              groupTime: groupTime,
              shots: groupShots,
            ));
          }
        }
        
        // Create next shot
        addNewShot();
        _shotPlaced = true;
        
        if (_isSightingMode) {
          _sightingTime = Duration.zero;
        } else {
          _currentShotTime = Duration.zero;
        }
        
        _zoomLevel = 1.0;
        _zoomOffset = Offset.zero;
      });
    }
  }

  void _createRemainingGroup() {
    if (_shots.isEmpty) return;

    // Count only CONFIRMED shots
    final confirmedShots = _shots.where((shot) => shot.isConfirmed).toList();
    final totalGroupedShots = _shotGroups.length * 10;
    final remainingShots = confirmedShots.length - totalGroupedShots;

    if (remainingShots > 0) {
      final startIndex = totalGroupedShots;
      final endIndex = confirmedShots.length;
      final remainingGroupShots = confirmedShots.sublist(startIndex, endIndex);
      
      final groupNumber = _shotGroups.length + 1;
      
      // ✅ Check if this partial group already exists
      final existingGroupIndex = _shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
      
      if (existingGroupIndex != -1) {
        // ✅ Update existing partial group
        _shotGroups[existingGroupIndex] = ShotGroup(
          groupNumber: groupNumber,
          groupTime: _totalSessionTime, // ✅ Current accumulated time
          shots: remainingGroupShots,
        );
        print('✅ Updated remaining group $groupNumber (${remainingShots} shots) with time: ${_totalSessionTime.inSeconds}s');
      } else {
        // ✅ Create new partial group
        _shotGroups.add(ShotGroup(
          groupNumber: groupNumber,
          groupTime: _totalSessionTime, // ✅ Current accumulated time
          shots: remainingGroupShots,
        ));
        print('✅ Created remaining group $groupNumber (${remainingShots} shots) with time: ${_totalSessionTime.inSeconds}s');
      }
    }
  }


void _calculateScore(Shot shot) {
  final center = Offset(_targetSize / 2, _targetSize / 2);
  final shotCenterDistance = (shot.position - center).distance;
  
  // Match the scale from RifleTargetPainter
  final visualScale = 1.3;
  final scale = (_targetSize / 60.0) * visualScale;
  
  // Calculate pellet radius in pixels
  final pelletRadius = 4.5 / 2 * scale;

  // Ring radii in pixels
  final Map<int, double> ringRadii = {
    1: 45.5 / 2 * scale,
    2: 40.5 / 2 * scale,
    3: 35.5 / 2 * scale,
    4: 30.5 / 2 * scale,
    5: 25.5 / 2 * scale,
    6: 20.5 / 2 * scale,
    7: 15.5 / 2 * scale,
    8: 10.5 / 2 * scale,
    9: 5.5 / 2 * scale,
  };

  // Center dot radius
  final centerDotRadius = 0.5 / 2 * scale;

  // Use pellet INNER edge for ring detection
  final pelletInnerEdgeDistance = shotCenterDistance - pelletRadius;
  
  int ringNumber = 0;
  double score = 0.0;

  // Check if pellet's inner edge is beyond the 1-ring
  if (pelletInnerEdgeDistance > ringRadii[1]!) {
    ringNumber = 0;
    score = 0.0;
    shot.ringNumber = ringNumber;
    shot.score = score;
    return;
  }

  // CHECK FOR 9-RING FIRST (this includes the 10-zone)
  if (pelletInnerEdgeDistance <= ringRadii[9]!) {
    ringNumber = 9;
    
    final ring9Radius = ringRadii[9]!; // 9-ring boundary
    
    // Determine if it's a 10 or a 9 based on SHOT CENTER
    if (shotCenterDistance <= ring9Radius) {
      // INSIDE 9-ring circle = 10-zone scoring
      ringNumber = 10;
      
      // ✅ FIXED: Score from 10.0 (at 9-ring boundary) to 10.9 (at center)
      // When shotCenterDistance = ring9Radius → decimal = 0.0 → score = 10.0
      // When shotCenterDistance = 0 (center) → decimal = 0.9 → score = 10.9
      
      // Distance from center to 9-ring boundary
      final distanceFromCenter = shotCenterDistance;
      
      // ✅ Calculate decimal: starts at 0.0 (at boundary), ends at 0.9 (at center)
      // Invert the ratio so boundary = 0.0
      final decimal = 0.9 * (1.0 - (distanceFromCenter / ring9Radius));
      
      score = 10.0 + decimal.clamp(0.0, 0.9);
      
    } else {
      // OUTSIDE 9-ring circle = 9-ring scoring
      ringNumber = 9;
      
      // Score 9.0 to 9.9 based on pellet inner edge
      final outerRingRadius = ringRadii[9]!;
      final innerRingRadius = centerDotRadius;
      
      final ringWidthInPixels = outerRingRadius - innerRingRadius;
      final distanceIntoRing = outerRingRadius - pelletInnerEdgeDistance;
      final clampedDistance = distanceIntoRing.clamp(0.0, ringWidthInPixels);
      
      final decimal = (clampedDistance / ringWidthInPixels * 0.9).clamp(0.0, 0.9);
      score = 9.0 + decimal;
    }
    
    score = double.parse(score.toStringAsFixed(1));
    shot.ringNumber = ringNumber;
    shot.score = score;
    return;
  }

  // Check rings 8 down to 1
  for (int ring = 8; ring >= 1; ring--) {
    final outerRingRadius = ringRadii[ring]!;
    
    if (pelletInnerEdgeDistance <= outerRingRadius) {
      ringNumber = ring;
      
      double innerRingRadius = ringRadii[ring + 1]!;
      
      final ringWidthInPixels = outerRingRadius - innerRingRadius;
      final distanceIntoRing = outerRingRadius - pelletInnerEdgeDistance;
      final clampedDistance = distanceIntoRing.clamp(0.0, ringWidthInPixels);
      
      final decimal = (clampedDistance / ringWidthInPixels * 0.9).clamp(0.0, 0.9);
      
      score = ring + decimal;
      score = double.parse(score.toStringAsFixed(1));
      break;
    }
  }

  shot.ringNumber = ringNumber;
  shot.score = score;
}




  void _printShotData(Shot shot, int shotNumber) {
    print('=== Rifle Shot #$shotNumber ===');
    print('Position: (${shot.position.dx.toStringAsFixed(2)}, ${shot.position.dy.toStringAsFixed(2)})');
    print('Time: ${_formatDurationWithMillis(shot.shotTime)}');
    print('Ring: ${shot.ringNumber}');
    print('Score: ${shot.score.toStringAsFixed(1)}');
    print('Feedback: ${shot.feedback.join(', ')}');
    print('==================\n');
  }

  void goToPreviousShot() {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (currentList.isEmpty) return;

    setState(() {
      if (_currentShotIndex > 0) {
        _currentShotIndex--;
        
        if (_isSightingMode) {
          _sightingTime = _sightingShots[_currentShotIndex].shotTime;
        } else {
          _currentShotTime = _shots[_currentShotIndex].shotTime;
        }
        _shotPlaced = true;
      }
    });
  }


  void goToNextShot() {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (currentList.isEmpty) return;

    setState(() {
      if (_currentShotIndex < currentList.length - 1) {
        _currentShotIndex++;
        
        if (_isSightingMode) {
          _sightingTime = _sightingShots[_currentShotIndex].shotTime;
        } else {
          _currentShotTime = _shots[_currentShotIndex].shotTime;
        }
        _shotPlaced = true;
      }
    });
  }

  List<Shot> getVisibleShots() {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (currentList.isEmpty) return [];

    final int batchNumber = _currentShotIndex ~/ widget.shotsPerTarget;
    final int start = batchNumber * widget.shotsPerTarget;
    final int end = (start + widget.shotsPerTarget).clamp(0, currentList.length);

    return currentList.sublist(start, end);
  }




  String _formatDurationWithMillis(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final millis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }
String _formatDurationWithoutMillis(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));

  if (hours > 0) {
    return '$hours:$minutes:$seconds'; // Show hours only if non-zero
  } else {
    return '00:$minutes:$seconds'; // Otherwise show mm:ss
  }
}

  void updateShotPosition(Offset localPosition) {
    if (_justCreatedShot) return;
    
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (_currentShotIndex < 0 || _currentShotIndex >= currentList.length) return;

    final adjustedPosition = _adjustPositionForZoom(localPosition);
    final clampedX = adjustedPosition.dx.clamp(0.0, targetSize);
    final clampedY = adjustedPosition.dy.clamp(0.0, targetSize);
    final clampedPosition = Offset(clampedX, clampedY);

    setState(() {
      currentList[_currentShotIndex].position = clampedPosition;
      _calculateScore(currentList[_currentShotIndex]);
    });
  }


  void _onPanEnd() {
    setState(() {
      _magnifierPosition = null;
    });
  }

void toggleFeedback(String feedbackId) {
  // Handle both sighting and actual session
  if (_isSightingMode) {
    // SIGHTING MODE
    if (_currentShotIndex < 0 || _currentShotIndex >= _sightingShots.length) return;
    
    setState(() {
      print("feedback clicked - sighting mode");
      final shot = _sightingShots[_currentShotIndex];
      
      if (shot.feedback.contains(feedbackId)) {
        shot.feedback.remove(feedbackId);
      } else {
        shot.feedback.add(feedbackId);
      }
      
      // If dry or cross is selected, prepare for reset
      if (feedbackId == 'dry' || feedbackId == 'cross') {
        if (shot.feedback.contains(feedbackId)) {
          _shotPlaced = false;
        }
      }
    });
  } else {
    // ACTUAL SESSION MODE
    if (_currentShotIndex < 0 || _currentShotIndex >= _shots.length) return;
    
    setState(() {
      print("feedback clicked - actual session");
      final shot = _shots[_currentShotIndex];
      
      if (shot.feedback.contains(feedbackId)) {
        shot.feedback.remove(feedbackId);
      } else {
        shot.feedback.add(feedbackId);
      }
      
      // If dry or cross is selected, prepare for reset
      if (feedbackId == 'dry' || feedbackId == 'cross') {
        if (shot.feedback.contains(feedbackId)) {
          _shotPlaced = false;
        }
      }
    });
  }
}


  // ✅ Save with session timer
Future<void> _saveSessionWithNotes() async {
    if (_isSightingMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to actual session before saving'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

  final notesController = TextEditingController();

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Add Session Note',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sessionNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${sessionNotes.length} previous ${sessionNotes.length == 1 ? 'note' : 'notes'} saved',
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
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
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
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(notesController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text(
            'Save Session',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  if (result != null) {
    if (result.trim().isNotEmpty) {
      sessionNotes.add(SessionNote(
        note: result.trim(),
        timestamp: DateTime.now(),
      ));
    }

    // ✅ Show global saving loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SavingSessionDialog(),
    );

    await saveSession(result, _photos);

    // _saveSession will close the dialog right before navigation
  }
}


// ✅ Save with auto-share
// ✅ Save with auto-share (Coach/Student role check)
  Future<void> saveSession(String finalNotes, List<PhotoData>? photos) async {
    _sessionTimer?.cancel();
    _timer?.cancel();
    _createRemainingGroup();

    final sessionService = SessionService();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCoach = await _isCoachRole(currentUser!.uid);

    final confirmedShots = _shots.where((shot) => shot.isConfirmed).toList();

    List<Map<String, dynamic>> allShots = confirmedShots.map((shot) => {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds,
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
    }).toList();

    // NEW: Add sighting shots as a separate list
    List<Map<String, dynamic>> sightingData = _sightingShots.map((shot) => {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds,
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
    }).toList();

    List<Map<String, dynamic>> allMissedShots = [];
    if (widget.existingMissedShots != null && widget.existingMissedShots!.isNotEmpty) {
      allMissedShots.addAll(widget.existingMissedShots!.map((missed) => missed.toJson()));
    }
    allMissedShots.addAll(
      _missedShots.skip(widget.existingMissedShots?.length ?? 0).map((missed) => missed.toJson())
    );

    List<Map<String, dynamic>> allNotesData = sessionNotes.map((note) => note.toJson()).toList();

    await sessionService.saveSessionShots(
      sessionId: widget.sessionId,
      shots: allShots,
      totalScore: calculateTotalScore(),
      totalTime: _totalSessionTime,
      notes: finalNotes,
      notesList: allNotesData,
      shotGroups: _shotGroups.map((group) => {
        'groupNumber': group.groupNumber,
        'groupTime': group.groupTime.inMilliseconds,
        'shotCount': group.shots.length,
      }).toList(),
      missedShots: allMissedShots,
      sightingShots: sightingData, // NEW: Pass sighting data
      sightingTotalScore: _calculateSightingScore, // NEW: Pass sighting score
    );

    // UPLOAD IMAGES ONLY FOR COACHES
    if (isCoach && photos != null && photos.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ImageUploadProgressDialog(
          totalImages: photos.length,
          uploadProgress: _uploadProgress,
        ),
      );

      try {
        await sessionService.saveSessionImages(
          sessionId: widget.sessionId,
          photos: photos,
          onProgress: (current, total) {
            _updateUploadProgress(current, total);
          },
        );
        Navigator.of(context).pop();
      } catch (e) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading images: $e')),
        );
      }
    } else if (!isCoach && photos != null && photos.isNotEmpty) {
      print('Student: Images saved locally, no upload');
    }

    // AUTO-SHARE ONLY FOR COACHES
    if (isCoach) {
      try {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('training_sessions')
            .doc(widget.sessionId)
            .get();

        if (sessionDoc.exists) {
          final sessionData = sessionDoc.data()!;
          final studentId = sessionData['studentId'] as String?;

          if (studentId != null && studentId.isNotEmpty) {
            print('COACH: Auto-sharing RIFLE session with student $studentId');
            await sessionService.autoShareWithStudent(widget.sessionId, studentId);
            print('RIFLE session auto-shared with student');
          }
        }
      } catch (e) {
        print('Auto-share failed: $e');
      }
    } else {
      print('STUDENT: RIFLE session saved locally only, no sharing');
    }

    // Navigate to report
    final reportData = SessionReportData(
      sessionName: widget.sessionName,
      studentName: widget.studentName!,
      shots: allShots,
      totalScore: calculateTotalScore(),
      totalTime: _totalSessionTime,
      eventType: 'Rifle', // RIFLE SPECIFIC
      notes: finalNotes,
      notesList: sessionNotes,
      shotGroups: _shotGroups,
      missedShots: allMissedShots.isNotEmpty
          ? allMissedShots.map((m) => MissedShot(
                shotNumber: m['shotNumber'],
                feedback: Set<String>.from(m['feedback']),
                shotTime: Duration(milliseconds: m['time']),
              )).toList()
          : null,
      sightingShots: sightingData, // NEW: Pass to report
      sightingTotalScore: _calculateSightingScore, // NEW: Pass to report
    );

    Navigator.of(context, rootNavigator: true).pop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionReportScreen(
          reportData: reportData,
          sessionId: widget.sessionId,
          shotsPerTarget: widget.shotsPerTarget,
          photos: photos ?? [],
        ),
      ),
    );
  }


// ✅ ADD THIS HELPER METHOD (at bottom of class - SAME for both screens)
Future<bool> _isCoachRole(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      final role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'student';
      return role == 'coach';
    }
    return false; // Default to student
  } catch (e) {
    print('❌ Error checking role: $e');
    return false; // Default to student on error
  }
}


// Assume you have a way to identify existing images uniquely, e.g., by 'id' or hash
// For demo, assuming PhotoData has some unique 'id' field or you can compare by imageBytes

List<PhotoData> filterNewPhotos(List<PhotoData> existingPhotos, List<PhotoData> allPhotos) {
  // Example: remove exact duplicates by comparing the imageBytes
  final existingBytesSet = existingPhotos.map((photo) => photo.localPath).toSet();

  return allPhotos.where((photo) => !existingBytesSet.contains(photo.localPath)).toList();
}

// Helper to update progress (use a ValueNotifier or setState depending on implementation)
final ValueNotifier<int> _uploadProgress = ValueNotifier(0);
void _updateUploadProgress(int current, int total) {
  _uploadProgress.value = current;
}

  double calculateTotalScore() {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    return currentList.fold(0.0, (sum, shot) => sum + shot.score);
  }

  Widget _buildScoreBox(String score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
Widget _buildCompactFeedbackButton(String iconId, String label, Shot? currentShot) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: _buildTooltipWrapper(
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

Future<Uint8List> _compressImage(Uint8List imageBytes) async {
  final compressedBytes = await FlutterImageCompress.compressWithList(
    imageBytes,
    minWidth: 400,
    minHeight: 300,
    quality: 30, // Adjust quality and resolution as needed
  );
  return compressedBytes;
}
void _showImageOptionDialog() {
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


Future<void> pickImageFromGallery() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked != null) {
    Uint8List bytes = await picked.readAsBytes();
    showImageNoteDialog(bytes, (note, compressedBytes) async {
      // ✅ Save locally and get the path
      final localPath = await saveImageLocally(compressedBytes);
      
      // ✅ Calculate shot group based on current shot index
      final shotGroup = currentShotGroup;
      
      setState(() {
        _photos.add(PhotoData(
          localPath: localPath,
          note: note,
          shotGroup: shotGroup,
        ));
      });
    });
  }
}

Future<void> captureImageFromCamera() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.camera);
  if (picked != null) {
    Uint8List bytes = await picked.readAsBytes();
    showImageNoteDialog(bytes, (note, compressedBytes) async {
      // ✅ Save locally and get the path
      final localPath = await saveImageLocally(compressedBytes);
      
      // ✅ Calculate shot group
      final shotGroup = currentShotGroup;
      
      setState(() {
        _photos.add(PhotoData(
          localPath: localPath,
          note: note,
          shotGroup: shotGroup,
        ));
      });
    });
  }
}
int get currentShotGroup {
  if (_shots.isEmpty) return 1;
  return ((_shots.length - 1) ~/ 10) + 1;
}
Future<String> saveImageLocally(Uint8List imageBytes) async {
  try {
    // Get application documents directory
    final directory = await getApplicationDocumentsDirectory();
    
    // Create a unique filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/session_${widget.sessionId}_$timestamp.jpg';
    
    // Write the file
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    
    return filePath;
  } catch (e) {
    print('Error saving image locally: $e');
    rethrow;
  }
}


void showImageNoteDialog(Uint8List imageBytes, Function(String, Uint8List) onSave) {
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
            // ✅ Pass original bytes WITHOUT compression
            onSave(note, imageBytes);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}



String? _imageNote; // Keep note associated with selected image



@override
Widget build(BuildContext context) {
  final currentList = _isSightingMode ? _sightingShots : _shots;
  final currentShot = _currentShotIndex >= 0 && _currentShotIndex < currentList.length
      ? currentList[_currentShotIndex]
      : null;

  final screenHeight = MediaQuery.of(context).size.height;
  final appBarHeight = kToolbarHeight;
  final statusBarHeight = MediaQuery.of(context).padding.top;
  final availableHeight = screenHeight - appBarHeight - statusBarHeight;
  final responsiveTargetSize = math.min(targetSize, availableHeight * 0.35);

  return Scaffold(
    backgroundColor: const Color(0xFF1A1A1A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Sighting badge or Rifle badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isSightingMode ? Colors.orange : const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isSightingMode ? 'Sighting' : 'Rifle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Session Time (hide in sighting mode)
          if (!_isSightingMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Session Time',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text(
                  _formatDurationWithoutMillis(_totalSessionTime),
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
        // Sighting mode switch button (only show in sighting mode)
        if (_isSightingMode)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _switchToActualSession,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        // Begin/End button (only in actual session)
        if (!_isSightingMode)
          OutlinedButton(
            onPressed: _toggleSession,
            style: OutlinedButton.styleFrom(
              foregroundColor: _isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
              side: BorderSide(
                color: _isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 0),
            ),
            child: Text(
              _isSessionActive ? 'End' : 'Begin',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        const SizedBox(width: 8),
        // Help icon
        IconButton(
          icon: Icon(
            Icons.info_outline,
            color: _showTooltips ? const Color(0xFFD32F2F) : Colors.white,
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _showTooltips = !_showTooltips;
            });
          },
        ),
      ],
    ),
    body: Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // Target with Sighting Triangle Indicator
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Main Target
                        GestureDetector(
                          onPanUpdate: (details) {
                            if (_shotPlaced) {
                              final RenderBox? renderBox =
                                  _targetKey.currentContext?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox.globalToLocal(details.globalPosition);
                                updateShotPosition(localPosition);
                              }
                            }
                          },
                          onTapDown: (details) {
                            if (_shotPlaced) {
                              final RenderBox? renderBox =
                                  _targetKey.currentContext?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox.globalToLocal(details.globalPosition);
                                updateShotPosition(localPosition);
                              }
                            }
                          },
                          child: Container(
                            key: _targetKey,
                            width: targetSize,
                            height: targetSize,
                            child: ClipOval(
                              child: Transform.scale(
                                scale: _zoomLevel,
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(targetSize, targetSize),
                                      painter: RifleTargetPainter(
                                        shots: getVisibleShots(),
                                        currentShotIndex: _currentShotIndex % widget.shotsPerTarget,
                                        targetSize: targetSize,
                                        shotsPerBatch: widget.shotsPerTarget,
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
                        
                        // NEW: Sighting Triangle Indicator (only visible in sighting mode)
                        if (_isSightingMode)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: CustomPaint(
                              size: const Size(60, 60),
                              painter: SightingTrianglePainter(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  _buildTooltipWrapper(
                    label: 'Add Image',
                    alignment: Alignment.topCenter,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                      onPressed: _showImageOptionDialog,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  // Zoom buttons + Scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Zoom Out button with left padding
                      Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: _buildTooltipWrapper(
                          label: 'Zoom Out',
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            icon: const Icon(Icons.zoom_out, color: Colors.white, size: 24),
                            onPressed: _zoomLevel > _minZoom ? _zoomOut : null,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),

                      // Current score display with tooltip wrapper
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildTooltipWrapper(
                            label: 'Current',
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD32F2F)),
                              ),
                              child: Center(
                                child: Text(
                                  currentShot?.score.toStringAsFixed(1) ?? '0.0',
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

                      // Total score display with tooltip wrapper
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildTooltipWrapper(
                            label: 'Total',
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD32F2F)),
                              ),
                              child: Center(
                                child: Text(
                                  calculateTotalScore().toStringAsFixed(1),
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

                      // Zoom In button with right padding
                      Padding(
                        padding: const EdgeInsets.only(right: 30),
                        child: _buildTooltipWrapper(
                          label: 'Zoom In',
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            icon: const Icon(Icons.zoom_in, color: Colors.white, size: 24),
                            onPressed: _zoomLevel < _maxZoom ? _zoomIn : null,
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
                  _buildTooltipWrapper(
                    label: 'Previous',
                    alignment: Alignment.topCenter,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                      onPressed: currentList.isNotEmpty ? goToPreviousShot : null,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTooltipWrapper(
                    label: 'Shot #',
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD32F2F)),
                      ),
                      child: Text(
                        '${_currentShotIndex + 1} / ${currentList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTooltipWrapper(
                    label: 'Next',
                    alignment: Alignment.topCenter,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 26),
                      onPressed: () {
                        if (_currentShotIndex >= 0 && _currentShotIndex < currentList.length) {
                          final currentShot = currentList[_currentShotIndex];
                          if (currentShot.feedback.contains('dry') ||
                              currentShot.feedback.contains('cross')) {
                            setState(() {
                              if (_isSightingMode) {
                                _missedShots.add(MissedShot(
                                  shotNumber: _currentShotIndex + 1,
                                  feedback: Set<String>.from(currentShot.feedback),
                                  shotTime: _sightingTime,
                                ));
                                _sightingShots.removeAt(_currentShotIndex);
                              } else {
                                _missedShots.add(MissedShot(
                                  shotNumber: _currentShotIndex + 1,
                                  feedback: Set<String>.from(currentShot.feedback),
                                  shotTime: _currentShotTime,
                                ));
                                _shots.removeAt(_currentShotIndex);
                              }
                              addNewShot();
                              _shotPlaced = true;
                              
                              if (_isSightingMode) {
                                _sightingTime = Duration.zero;
                              } else {
                                _currentShotTime = Duration.zero;
                              }
                            });
                            return;
                          }

                          if (currentShot.isConfirmed) {
                            goToNextShot();
                          } else {
                            confirmCurrentShot();
                          }
                        }
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Timer controls (Reset, Shot Time, Start/Stop Timer)
              Row(
                children: [
                  Expanded(
                    child: _buildTooltipWrapper(
                      label: 'Reset',
                      alignment: Alignment.topCenter,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            if (_isSightingMode) {
                              _sightingTime = Duration.zero;
                            } else {
                              _currentShotTime = Duration.zero;
                            }
                            _isTimerRunning = false;
                            _timer?.cancel();
                            
                            if (currentList.isNotEmpty &&
                                _currentShotIndex >= 0 &&
                                _currentShotIndex < currentList.length) {
                              currentList[_currentShotIndex].feedback.clear();
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTooltipWrapper(
                    label: 'Shot Time',
                    alignment: Alignment.topCenter,
                    child: Text(
                      _isSightingMode
                          ? _formatDurationWithMillis(_sightingTime)
                          : _formatDurationWithMillis(_currentShotTime),
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTooltipWrapper(
                      label: 'Start Timer',
                      alignment: Alignment.topCenter,
                      child: ElevatedButton(
                        onPressed: toggleTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(
                          _isTimerRunning ? 'Stop' : 'Start',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Feedback buttons - Only show for coaches
              if (!_isCoach)

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
                          _buildCompactFeedbackButton('balance', 'Balance', currentShot),
                          _buildCompactFeedbackButton('npa', 'Natural Point of Aim', currentShot),
                          _buildCompactFeedbackButton('breathing', 'Breathing', currentShot),
                          _buildCompactFeedbackButton('preparation', 'Preparation', currentShot),
                          _buildCompactFeedbackButton('trigger_release', 'Trigger Release', currentShot),
                          _buildCompactFeedbackButton('timing', 'Timing', currentShot),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Row 2
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCompactFeedbackButton('ft', 'Follow Through', currentShot),//
                          _buildCompactFeedbackButton('long_aim', 'Long Aim', currentShot),
                          _buildCompactFeedbackButton('cross', 'Cancel', currentShot),
                          _buildCompactFeedbackButton('shoot_tick', 'Good Shot', currentShot),//
                          _buildCompactFeedbackButton('distraction', 'Distraction', currentShot),
                          _buildCompactFeedbackButton('dry', 'Dry Fire', currentShot),//
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Row 3
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCompactFeedbackButton('rest', 'Rest', currentShot),
                          _buildCompactFeedbackButton('coach_feedback', 'Coach Feedback', currentShot),
                          _buildCompactFeedbackButton('rifle_recoil', 'Rifle Recoil', currentShot),
                          _buildCompactFeedbackButton('reaction', 'Reaction to Result', currentShot),
                          _buildCompactFeedbackButton('talk_with_friends', 'Interaction with Coach', currentShot),//
                          _buildCompactFeedbackButton('stand', 'Standing', currentShot),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // PINNED bottom section
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation (Previous, Shot #, Next)
             

              // Save button (disabled in sighting mode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSightingMode ? null : _saveSessionWithNotes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSightingMode ? Colors.grey : const Color(0xFFD32F2F),
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


}




// [Keep all the existing Painter classes: RifleTargetPainter and RifleMagnifierPainter - unchanged]

// Professional ISSF 10m Air Rifle Target Painter
class RifleTargetPainter extends CustomPainter {
  final List<Shot> shots;
  final int currentShotIndex;
  final double targetSize;
  final int shotsPerBatch;

  RifleTargetPainter({
    required this.shots,
    required this.currentShotIndex,
    required this.targetSize,
    required this.shotsPerBatch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    final visualScale = 1.3;
    final scale = (targetSize / 60.0) * visualScale;
    
    final Map<int, double> ringRadii = {
      1: 45.5 / 2 * scale,
      2: 40.5 / 2 * scale,
      3: 35.5 / 2 * scale,
      4: 30.5 / 2 * scale,
      5: 25.5 / 2 * scale,
      6: 20.5 / 2 * scale,
      7: 15.5 / 2 * scale,
      8: 10.5 / 2 * scale,
      9: 5.5 / 2 * scale,
      10: 0.5 / 2 * scale,
    };

    // Draw rings
    for (int ringNum = 1; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 4;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;
      
      canvas.drawCircle(center, radius, Paint()..color = fillColor..style = PaintingStyle.fill);
      canvas.drawCircle(center, radius, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 0.15 * scale);
    }

    // Draw numbers
    for (int ringNum = 1; ringNum <= 8; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;
      final textColor = ringNum <= 3 ? Colors.black : Colors.white;

      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(color: textColor, fontSize: 3 * scale / visualScale, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
      }
    }

    // Center dot
    final centerDotRadius = (0.6 / 2 * scale).clamp(1.5, double.infinity);
    canvas.drawCircle(center, centerDotRadius, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Draw shots
    if (shots.isNotEmpty) {
      final currentBatch = (shots.length - 1) ~/ shotsPerBatch;
      final batchStartIndex = currentBatch * shotsPerBatch;
      final batchEndIndex = math.min(batchStartIndex + shotsPerBatch, shots.length);
      
      final pelletRadius = 4.5 / 2 * scale;
      
      for (int i = 0; i < shots.length; i++) {
        double opacity = getOpacityForShot(i, currentShotIndex, shotsPerBatch, shots.length);

        if (opacity == 0.0) continue; // Hide shots higher than current shot

        final shot = shots[i];
        final isCurrent = i == currentShotIndex;
        final baseColor = isCurrent ? Colors.red : Colors.blue;
        final shotColor = baseColor.withOpacity(opacity);

        canvas.drawCircle(shot.position, pelletRadius, Paint()..color = shotColor..style = PaintingStyle.fill);
      }
    }
  }
double getOpacityForShot(int shotIndex, int currentShotIndex, int shotsPerBatch, int totalShots) {
  if (shotIndex > currentShotIndex) return 0.0; // hide shots higher than current

  int batchStart = (currentShotIndex ~/ shotsPerBatch) * shotsPerBatch;
  int batchEnd = math.min(batchStart + shotsPerBatch, totalShots);

  int shotsInCurrentBatch = batchEnd - batchStart;
  int age = shotIndex - batchStart; // age within current batch

  if (age < 0) {
    // shot before current batch - low opacity
    return 0.3;
  }

  if (age == currentShotIndex % shotsPerBatch) {
    // current shot full opacity
    return 1.0;
  }

  // For previous shots, scale opacity between 0.5 and 1.0 depending on shots placed in batch
  return 0.5 + 0.5 * (age / (shotsInCurrentBatch - 1));
}

  @override
  bool shouldRepaint(covariant RifleTargetPainter oldDelegate) => true;
}

// Rifle Magnifier Loupe Painter
// Rifle Magnifier Loupe Painter
class RifleMagnifierPainter extends CustomPainter {
  final Offset position;
  final List<Shot> shots;
  final int currentShotIndex;
  final double targetSize;
  final int shotsPerBatch; // ✅ Added

  RifleMagnifierPainter({
    required this.position,
    required this.shots,
    required this.currentShotIndex,
    required this.targetSize,
    required this.shotsPerBatch, // ✅ Added
  });

  @override
  void paint(Canvas canvas, Size size) {
    final magnifierSize = 120.0;
    final zoomFactor = 2.0; // ✅ Reduced from 3.0 to 2.0 to show more context
    
    final magnifierCenter = Offset(
      position.dx.clamp(magnifierSize / 2, targetSize - magnifierSize / 2),
      (position.dy - 80).clamp(magnifierSize / 2, targetSize - magnifierSize / 2),
    );

    canvas.save();

    final magnifierPath = Path()..addOval(Rect.fromCircle(center: magnifierCenter, radius: magnifierSize / 2));
    canvas.clipPath(magnifierPath);

    canvas.translate(magnifierCenter.dx, magnifierCenter.dy);
    canvas.scale(zoomFactor);
    canvas.translate(-position.dx, -position.dy);

    _drawZoomedTarget(canvas, size);

    canvas.restore();

    final borderPaint = Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawCircle(magnifierCenter, magnifierSize / 2, borderPaint);

    final outerBorderPaint = Paint()..color = const Color(0xFFD32F2F)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawCircle(magnifierCenter, magnifierSize / 2 + 2, outerBorderPaint);

    final crosshairPaint = Paint()..color = Colors.red..strokeWidth = 1.5;
    final crosshairLength = 15.0;
    canvas.drawLine(Offset(magnifierCenter.dx - crosshairLength, magnifierCenter.dy), Offset(magnifierCenter.dx + crosshairLength, magnifierCenter.dy), crosshairPaint);
    canvas.drawLine(Offset(magnifierCenter.dx, magnifierCenter.dy - crosshairLength), Offset(magnifierCenter.dx, magnifierCenter.dy + crosshairLength), crosshairPaint);

    canvas.drawCircle(magnifierCenter, 2, Paint()..color = Colors.red..style = PaintingStyle.fill);

    final linePaint = Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 1.5;
    canvas.drawLine(magnifierCenter, position, linePaint);
  }

  void _drawZoomedTarget(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    // ✅ Match visual scale with main target (1.3, not 1.5)
    final visualScale = 1.3;
    final scale = (targetSize / 60.0) * visualScale;
    
    final Map<int, double> ringRadii = {
      1: 45.5 / 2 * scale,
      2: 40.5 / 2 * scale,
      3: 35.5 / 2 * scale,
      4: 30.5 / 2 * scale,
      5: 25.5 / 2 * scale,
      6: 20.5 / 2 * scale,
      7: 15.5 / 2 * scale,
      8: 10.5 / 2 * scale,
      9: 5.5 / 2 * scale,
      10: 0.5 / 2 * scale,
    };

    // Draw rings
    for (int ringNum = 1; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 4;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;
      
      canvas.drawCircle(center, radius, Paint()..color = fillColor..style = PaintingStyle.fill);
      canvas.drawCircle(center, radius, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 0.15 * scale);
    }

    // Center dot
    canvas.drawCircle(center, (0.5 / 2 * scale).clamp(1.5, double.infinity), Paint()..color = Colors.white..style = PaintingStyle.fill);

    // ✅ Draw only current batch shots (batch filtering added!)
    if (shots.isNotEmpty) {
      final currentBatch = (shots.length - 1) ~/ shotsPerBatch;
      final batchStartIndex = currentBatch * shotsPerBatch;
      final batchEndIndex = math.min(batchStartIndex + shotsPerBatch, shots.length);
      
      final pelletRadius = 4.5 / 2 * scale;
      
      for (int i = batchStartIndex; i < batchEndIndex; i++) {
        final shot = shots[i];
        final isCurrent = i == currentShotIndex;
        final shotColor = isCurrent ? Colors.red : Colors.blue;

        canvas.drawCircle(shot.position, pelletRadius, Paint()..color = shotColor..style = PaintingStyle.fill);
        canvas.drawCircle(shot.position, pelletRadius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.3 * scale);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RifleMagnifierPainter oldDelegate) => true;
}

// Border Painter for Rifle Target
class BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5, // Offset by half stroke width
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _ImageUploadProgressDialog extends StatelessWidget {
  final int totalImages;
  final ValueNotifier<int> uploadProgress;

  const _ImageUploadProgressDialog({
    Key? key,
    required this.totalImages,
    required this.uploadProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFD32F2F)),
          const SizedBox(height: 16),
          ValueListenableBuilder<int>(
            valueListenable: uploadProgress,
            builder: (context, current, child) {
              return Text(
                'Uploading $current of $totalImages images',
                style: const TextStyle(color: Colors.white),
              );
            },
          ),
        ],
      ),
    );
  }
}
class _SavingSessionDialog extends StatelessWidget {
  const _SavingSessionDialog();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // block back
      child: Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: Color(0xFFD32F2F)),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Saving session, please wait...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
