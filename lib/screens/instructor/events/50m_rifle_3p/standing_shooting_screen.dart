import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
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

class StandingShootingScreen extends StatefulWidget {


  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;
  final List<Map<String, dynamic>>? existingShots;
  final List<MissedShot>? existingMissedShots; // Add this to constructor params
  final List<PhotoData>? existingImages; 
final List<ShotGroup>?existingShotGroups;
  final String studentName;
   final List<SessionNote>? existingNotes;
   final List<Map<String, dynamic>>? existingSightingShots;

  const StandingShootingScreen({
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
  State<StandingShootingScreen> createState() => _StandingShootingScreen();
}

class _StandingShootingScreen extends State<StandingShootingScreen> {
String? _selectedWindDirection;
// Light condition state
String? _selectedLight; // Values: 'Bright', 'Medium', 'Low'

// Climate condition state
String? _selectedClimate; // Values: 'Sunny', 'Cloudy', 'Rainy', 'Foggy'


    bool _isSightingMode = true; // Start in sighting mode
  List<Shot> _sightingShots = []; // Separate list for sighting shots
  Duration _sightingTime = Duration.zero; // Separate time for sighting
  Timer? _timer;
  Timer? _sessionTimer;
  Duration _currentShotTime = Duration.zero;
  Duration _totalSessionTime = Duration.zero;
  bool _isTimerRunning = false;
  bool _isSessionActive = false;
  bool _sessionStarted = false;
  bool _shotPlaced = false;
  bool _justCreatedShot = false;
  List<Shot> _shots = [];
  int _currentShotIndex = -1;
  final GlobalKey _targetKey = GlobalKey();
  final double _targetSize = 280.0;
  List<SessionNote> sessionNotes = [];
  

  Duration _accumulatedSessionTime = Duration.zero; // NEW: Track accumulated time
  // ✅ NEW: Zoom variables
  double _zoomLevel = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 3.0;
  final double _zoomStep = 0.5;
  Offset _zoomOffset = Offset.zero;

  List<ShotGroup> _shotGroups = [];
  List<MissedShot> _missedShots = [];
  bool _showTooltips = false; // ✅ Toggle for showing tooltips
  List<PhotoData> _photos = [];


@override
void initState() {
  super.initState();
  _shotGroups.clear();
  loadExistingShots();
      if (widget.existingNotes != null && widget.existingNotes!.isNotEmpty) {
      sessionNotes = List<SessionNote>.from(widget.existingNotes!);
    }
  
  // ✅ FIXED: Only add shot if no existing shots were loaded
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
      
      // Add first shot for actual session
      addNewShot();
      _shotPlaced = true;
    });
  }
    double get _calculateSightingScore {
    return _sightingShots.fold(0.0, (sum, shot) => sum + shot.score);
  }
List<Map<String, dynamic>> allShots = [];
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
      final exactCenter = Offset(_targetSize / 2, _targetSize / 2);
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


 // Add these variables to your state
DateTime? _sessionStartTime;
DateTime? _shotStartTime;

// Replace _startSessionTimer with:
  // ✅ Session timer: tracks TOTAL elapsed time (independent of shot timers)
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
void _toggleTimer() {
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
  // ✅ Toggle session (Begin/End button)
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

 void updateShotPosition(Offset localPosition) {
    if (_justCreatedShot) return;
    
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (_currentShotIndex < 0 || _currentShotIndex >= currentList.length) return;

    final adjustedPosition = _adjustPositionForZoom(localPosition);
    final clampedX = adjustedPosition.dx.clamp(0.0, _targetSize);
    final clampedY = adjustedPosition.dy.clamp(0.0, _targetSize);
    final clampedPosition = Offset(clampedX, clampedY);

    setState(() {
      currentList[_currentShotIndex].position = clampedPosition;
      _calculateScore(currentList[_currentShotIndex]);
    });
  }

  // ✅ NEW: Adjust position for zoom level
  Offset _adjustPositionForZoom(Offset localPosition) {
    if (_zoomLevel == 1.0) return localPosition;
    
    final center = Offset(_targetSize / 2, _targetSize / 2);
    final offsetFromCenter = localPosition - center;
    final adjustedOffset = offsetFromCenter / _zoomLevel;
    return center + adjustedOffset + _zoomOffset;
  }

  void addNewShot() {
    setState(() {
      final exactCenter = Offset(_targetSize / 2, _targetSize / 2);
      
      if (_isSightingMode) {
        _sightingShots.add(Shot(
          position: exactCenter,
          shotTime: _sightingTime,
        ));
        _currentShotIndex = _sightingShots.length - 1;
      } else {
        _shots.add(Shot(
          position: exactCenter,
          shotTime: _currentShotTime,
        ));
        _currentShotIndex = _shots.length - 1;
      }
      
      _calculateScore(_isSightingMode ? _sightingShots[_currentShotIndex] : _shots[_currentShotIndex]);
    });
  }
// Helper method to build indicator buttons
// Small circular indicator buttons
Widget _buildSmallIndicatorButton({
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
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: label == '↔' ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
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
          final confirmedShots = _shots.where((s) => s.isConfirmed).toList();
          if (confirmedShots.length % 10 == 0) {
            final groupNumber = confirmedShots.length ~/ 10;
            final startIndex = (groupNumber - 1) * 10;
            final endIndex = groupNumber * 10;
            final groupShots = confirmedShots.sublist(startIndex, endIndex);
            
            final existingGroupIndex = _shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
            if (existingGroupIndex != -1) {
              _shotGroups[existingGroupIndex] = ShotGroup(
                groupNumber: groupNumber,
                groupTime: _totalSessionTime,
                shots: groupShots,
              );
            } else {
              _shotGroups.add(ShotGroup(
                groupNumber: groupNumber,
                groupTime: _totalSessionTime,
                shots: groupShots,
              ));
            }
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
      });
    }
  }




void _calculateScore(Shot shot) {
  final center = Offset(_targetSize / 2, _targetSize / 2);
  final shotCenterDistance = (shot.position - center).distance;
  
  // ✅ Use EXACT same scale as your existing PistolTargetPainter
  final visualScale = 1.0;
  final scale = _targetSize / 170.0 * visualScale;
  
  // ✅ Calculate pellet radius in pixels
  final pelletRadius = (4.5 / 2) * scale;

  // ✅ Ring radii in pixels - EXACTLY matching your painter
  final Map<int, double> ringRadii = {
    1: 155.5 / 2 * scale,
    2: 139.5 / 2 * scale,
    3: 123.5 / 2 * scale,
    4: 107.5 / 2 * scale,
    5: 91.5 / 2 * scale,
    6: 75.5 / 2 * scale,
    7: 59.5 / 2 * scale,
    8: 43.5 / 2 * scale,
    9: 27.5 / 2 * scale,
    10: 11.5 / 2 * scale,
  };

  // ✅ Inner circle radius (center dot boundary)
  final innerCircleRadius = 5.0 / 2 * scale;

  // ✅ Use pellet INNER edge (closest to center) for scoring
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

  // ✅ Check each ring from 10 down to 1
  for (int ring = 10; ring >= 1; ring--) {
    final outerRingRadius = ringRadii[ring]!;
    
    // Check if pellet's inner edge is within this ring
    if (pelletInnerEdgeDistance <= outerRingRadius) {
      ringNumber = ring;
      
      // ✅ SPECIAL HANDLING FOR 10-RING ONLY
      if (ring == 10) {
        // ✅ 10-ring has TWO zones:
        // Zone 1: From 9-10 boundary to inner circle edge → 10.0 to 10.4 (use pellet inner edge)
        // Zone 2: From inner circle edge to center → 10.4 to 10.9 (use shot center)
        
        final ring10Radius = ringRadii[10]!; // 9-10 boundary
        
        // ✅ Determine zone based on PELLET INNER EDGE touching inner circle
        if (pelletInnerEdgeDistance <= innerCircleRadius) {
          // ✅ ZONE 2: Pellet inner edge inside inner circle (10.4 to 10.9)
          // BUT use SHOT CENTER distance for scoring distribution
          // At exact center (shot center = 0): score = 10.9
          // At inner circle edge: score = 10.4
          
          final distanceRatio = shotCenterDistance / innerCircleRadius;
          final scoreRatio = 1.0 - distanceRatio; // Invert: center=1.0, edge=0.0
          
          // Map to 10.4-10.9 range (0.5 range)
          final decimal = 0.4 + (scoreRatio * 0.5);
          score = 10.0 + decimal.clamp(0.4, 0.9);
          
        } else {
          // ✅ ZONE 1: Pellet inner edge between inner circle and 9-10 boundary (10.0 to 10.4)
          // Use pellet inner edge for scoring (consistent with other rings)
          // At 9-10 boundary: score = 10.0
          // At inner circle edge: score = 10.4
          
          final zoneWidth = ring10Radius - innerCircleRadius;
          final distanceFromInnerCircle = pelletInnerEdgeDistance - innerCircleRadius;
          final distanceRatio = distanceFromInnerCircle / zoneWidth;
          
          // Invert: innerCircle=1.0, boundary=0.0
          final scoreRatio = 1.0 - distanceRatio;
          
          // Map to 10.0-10.4 range (0.4 range)
          final decimal = scoreRatio * 0.4;
          score = 10.0 + decimal.clamp(0.0, 0.4);
        }
        
        score = double.parse(score.toStringAsFixed(1));
        
      } else {
        // ✅ For rings 1-9: Use pellet inner edge (unchanged)
        double innerRingRadius = ringRadii[ring + 1]!;
        
        final ringWidthInPixels = outerRingRadius - innerRingRadius;
        final distanceIntoRing = outerRingRadius - pelletInnerEdgeDistance;
        final clampedDistance = distanceIntoRing.clamp(0.0, ringWidthInPixels);
        
        final decimal = (clampedDistance / ringWidthInPixels * 0.9).clamp(0.0, 0.9);
        
        score = ring + decimal;
        score = double.parse(score.toStringAsFixed(1));
      }
      break;
    }
  }

  shot.ringNumber = ringNumber;
  shot.score = score;
}

Future<void> _showWindDirectionSelector() async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => WindDirectionDialog(
      currentDirection: _selectedWindDirection,
    ),
  );

  if (result != null) {
    setState(() {
      _selectedWindDirection = result;
    });
  }
}

Future<void> _showLightSelector() async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => SimpleOptionDialog(
      title: 'Light Condition',
      options: const ['Bright', 'Medium', 'Low'],
      currentSelection: _selectedLight,
      color: Colors.amber,
    ),
  );

  if (result != null) {
    setState(() {
      _selectedLight = result;
    });
  }
}

Future<void> _showClimateSelector() async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => SimpleOptionDialog(
      title: 'Climate Condition',
      options: const ['Sunny', 'Cloudy', 'Rainy', 'Foggy'],
      currentSelection: _selectedClimate,
      color: Colors.green,
    ),
  );

  if (result != null) {
    setState(() {
      _selectedClimate = result;
    });
  }
}









  void _printShotData(Shot shot, int shotNumber) {
    print('Shot $shotNumber:');
    print('  Position: (${shot.position.dx.toStringAsFixed(2)}, ${shot.position.dy.toStringAsFixed(2)})');
    print('  Time: ${_formatDurationWithMillis(shot.shotTime)}');
    print('  Ring: ${shot.ringNumber}');
    print('  Score: ${shot.score.toStringAsFixed(1)}');
    print('  Feedback: ${shot.feedback.join(', ')}');
    print('---');
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
void _toggleFeedback(String feedbackId) {
  if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
    setState(() {
      final shot = _shots[_currentShotIndex];
      if (shot.feedback.contains(feedbackId)) {
        shot.feedback.remove(feedbackId);
      } else {
        shot.feedback.add(feedbackId);
      }
      
      // ✅ NEW: If dry or cross is selected, reset pellet
      if (feedbackId == 'dry' || feedbackId == 'cross') {
        if (shot.feedback.contains(feedbackId)) {
          // User just selected dry/cross - prepare for reset
          // _shotPlaced = false;
        }
      }
    });
  }
}


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



// ✅ FIXED: Save ALL shots + Auto-share with student
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
    }

    if (isCoach) {
      try {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('training_sessions')
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
        print('Auto-share failed: $e');
      }
    }

    // final reportData = SessionReportData(
    //   sessionName: widget.sessionName,
    //   studentName: widget.studentName,
    //   shots: allShots,
    //   totalScore: calculateTotalScore(),
    //   totalTime: _totalSessionTime,
    //   eventType: 'Pistol',
    //   notes: finalNotes,
    //   notesList: sessionNotes,
    //   shotGroups: _shotGroups,
    //   missedShots: allMissedShots.isNotEmpty
    //       ? allMissedShots.map((m) => MissedShot(
    //             shotNumber: m['shotNumber'],
    //             feedback: Set<String>.from(m['feedback']),
    //             shotTime: Duration(milliseconds: m['time']),
    //           )).toList()
    //       : null,
    //   sightingShots: sightingData, // NEW: Pass to report
    //   sightingTotalScore: _calculateSightingScore, // NEW: Pass to report
    // );

    // Navigator.of(context, rootNavigator: true).pop();
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => SessionReportScreen(
    //       reportData: reportData,
    //       sessionId: widget.sessionId,
    //       shotsPerTarget: widget.shotsPerTarget,
    //       photos: photos ?? [],
    //     ),
    //   ),
    // );
  }


// ✅ ADD THIS HELPER METHOD (at bottom of class)
Future<bool> _isCoachRole(String userId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (userDoc.exists) {
      final role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'student';
      print('Role normalized to: $role');

      return role == 'coach' || role == 'instructor';
    }
    return false; // Default to student
  } catch (e) {
    print('Error checking role: $e');
    return false; // Default to student on error
  }
}





  // ✅ FIXED: Create or update remaining group
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


final ValueNotifier<int> _uploadProgress = ValueNotifier(0);
void _updateUploadProgress(int current, int total) {
  _uploadProgress.value = current;
}
  double calculateTotalScore() {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    return currentList.fold(0.0, (sum, shot) => sum + shot.score);
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


// ✅ Updated pickImageFromGallery with size limits and error handling
Future<void> pickImageFromGallery() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,  // ✅ Limit image size
      maxHeight: 1920,
      imageQuality: 85, // ✅ Reasonable quality
    );
    
    if (picked != null) {
      Uint8List bytes = await picked.readAsBytes();
      
      // ✅ Check file size (warn if > 5MB)
      if (bytes.length > 5 * 1024 * 1024) {
        print('Warning: Large image file (${bytes.length ~/ (1024 * 1024)}MB)');
      }
      
      showImageNoteDialog(bytes, (note, originalBytes) async {
        try {
          // ✅ Save locally and get the path
          final localPath = await saveImageLocally(originalBytes);
          
          // ✅ Calculate shot group based on current shot index
          final shotGroup = currentShotGroup;
          
          if (mounted) {
            setState(() {
              _photos.add(PhotoData(
                localPath: localPath,
                note: note,
                shotGroup: shotGroup,
              ));
            });
          }
        } catch (e) {
          print('Error saving image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving image: $e')),
            );
          }
        }
      });
    }
  } catch (e) {
    print('Error picking image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}

// ✅ Updated captureImageFromCamera with size limits and error handling
Future<void> captureImageFromCamera() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,  // ✅ Limit image size
      maxHeight: 1920,
      imageQuality: 85, // ✅ Reasonable quality
    );
    
    if (picked != null) {
      Uint8List bytes = await picked.readAsBytes();
      
      // ✅ Check file size
      if (bytes.length > 5 * 1024 * 1024) {
        print('Warning: Large image file (${bytes.length ~/ (1024 * 1024)}MB)');
      }
      
      showImageNoteDialog(bytes, (note, originalBytes) async {
        try {
          // ✅ Save locally and get the path
          final localPath = await saveImageLocally(originalBytes);
          
          // ✅ Calculate shot group
          final shotGroup = currentShotGroup;
          
          if (mounted) {
            setState(() {
              _photos.add(PhotoData(
                localPath: localPath,
                note: note,
                shotGroup: shotGroup,
              ));
            });
          }
        } catch (e) {
          print('Error saving image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving image: $e')),
            );
          }
        }
      });
    }
  } catch (e) {
    print('Error capturing image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }
}


int get currentShotGroup {
  if (_shots.isEmpty) return 1;
  return ((_shots.length - 1) ~/ 10) + 1;
}

// Updated method to save image locally
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

String _getWindDirectionIcon() {
  if (_selectedWindDirection == null) return '↔';
  
  switch (_selectedWindDirection) {
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
      return '↔';
  }
}

String _getLightIcon() {
  if (_selectedLight == null) return 'L';
  
  switch (_selectedLight) {
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

String _getClimateIcon() {
  if (_selectedClimate == null) return 'C';
  
  switch (_selectedClimate) {
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



@override
Widget build(BuildContext context) {
  final currentList = _isSightingMode ? _sightingShots : _shots;
  final currentShot = _currentShotIndex >= 0 && _currentShotIndex < currentList.length
      ? currentList[_currentShotIndex]
      : null;



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
          // Sighting badge or Pistol badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isSightingMode ? Colors.orange : const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isSightingMode ? 'Sighting' : 'Pistol',
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
// Target with 3 Indicator Buttons on the right
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
                            width: _targetSize,
                            height: _targetSize,
                            child: ClipOval(
                              child: Transform.scale(
                                scale: _zoomLevel,
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(_targetSize, _targetSize),
                                      painter: PistolTargetPainter(
                                        shots: getVisibleShots(),
                                        currentShotIndex: _currentShotIndex % widget.shotsPerTarget,
                                        targetSize: _targetSize,
                                        shotsPerBatch: widget.shotsPerTarget,
                                      ),
                                    ),
                                    CustomPaint(
                                      size: Size(_targetSize, _targetSize),
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

// Row with 3 columns: Empty (left) | Camera (center) | 3 Indicators (right)
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Left side: Empty spacer (same width as right side for balance)
      SizedBox(
        width: 120, // Same width as the 3 buttons on right
        child: Container(), // Empty
      ),

      // Center: Camera Icon
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

      // Right side: 3 Small Indicator Buttons
// Right side: 3 Small Indicator Buttons
Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    _buildSmallIndicatorButton(
      label: _getLightIcon(),
      color: Colors.amber,
      onTap: _showLightSelector,
    ),
    const SizedBox(width: 8),
    _buildSmallIndicatorButton(
      label: _getWindDirectionIcon(),
      color: Colors.blue,
      onTap: _showWindDirectionSelector,
    ),
    const SizedBox(width: 8),
    _buildSmallIndicatorButton(
      label: _getClimateIcon(),
      color: Colors.green,
      onTap: _showClimateSelector,
    ),
  ],
),

    ],
  ),
),


                  // Zoom buttons + Scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Zoom Out
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

                      // Current score
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

                      // Total score
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

                      // Zoom In
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

              // Timer controls
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
                        onPressed: _toggleTimer,
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

              // Feedback buttons
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCompactFeedbackButton('movement', 'Body Movement', currentShot),
                          _buildCompactFeedbackButton('stand', 'Standing', currentShot),
                          _buildCompactFeedbackButton('sitting', 'Sitting', currentShot),
                          _buildCompactFeedbackButton('talk_with_friends', 'Interaction with coach', currentShot),
                          _buildCompactFeedbackButton('random_shoot', 'Weapon Movement', currentShot),
                          _buildCompactFeedbackButton('grip', 'GRIP', currentShot),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCompactFeedbackButton('shoot_tick', 'Perfect Shot', currentShot),
                          _buildCompactFeedbackButton('tr', 'Trigger', currentShot),
                          _buildCompactFeedbackButton('ft', 'Follow Through', currentShot),
                          _buildCompactFeedbackButton('lh', 'Long Hold', currentShot),
                          _buildCompactFeedbackButton('dry', 'Dry', currentShot),
                          _buildCompactFeedbackButton('cross', 'Cancel', currentShot),
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

        // PINNED bottom section
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation (Previous, Shot #, Next)





              const SizedBox(height: 16),

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

// ✅ Helper method for compact feedback buttons
Widget _buildCompactFeedbackButton(String iconId, String label, Shot? currentShot) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: _buildTooltipWrapper(
      label: label,
      alignment: Alignment.topCenter,
      child: ShootingFeedbackIcons.buildFeedbackButton(
        iconId: iconId,
        isSelected: currentShot?.feedback.contains(iconId) ?? false,
        onPressed: () => _toggleFeedback(iconId),
      ),
    ),
  );
}

}
// NEW: Sighting Triangle Indicator Painter
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

// Keep existing PistolTargetPainter and BorderPainter
class PistolTargetPainter extends CustomPainter {
  final List<Shot> shots;
  final int currentShotIndex;
  final double targetSize;
  final int shotsPerBatch;

  PistolTargetPainter({
    required this.shots,
    required this.currentShotIndex,
    required this.targetSize,
    required this.shotsPerBatch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    final visualScale = 1.0;
    final scale = targetSize / 170.0 * visualScale;

    final Map<int, double> ringRadii = {
      1: 155.5 / 2 * scale,
      2: 139.5 / 2 * scale,
      3: 123.5 / 2 * scale,
      4: 107.5 / 2 * scale,
      5: 91.5 / 2 * scale,
      6: 75.5 / 2 * scale,
      7: 59.5 / 2 * scale,
      8: 43.5 / 2 * scale,
      9: 27.5 / 2 * scale,
      10: 11.5 / 2 * scale,
    };

    final innerTenRadius = 5.0 / 2 * scale;

    // Draw rings
    for (int ringNum = 1; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 7;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;

      canvas.drawCircle(center, radius, Paint()..color = fillColor..style = PaintingStyle.fill);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 0.15 * scale,
      );
    }

// ✅ FIXED: Draw numbers 1-8 on target rings
for (int ringNum = 1; ringNum <= 8; ringNum++) {
  // Get the CORRECT inner radius for each ring
  int nextRing = ringNum + 1;
  if (nextRing > 10) nextRing = 10; // Safety check
  
  final outerRadius = ringRadii[ringNum]!;
  final innerRadius = ringRadii[nextRing]!;
  final midRadius = (outerRadius + innerRadius) / 2;
  
  // Color logic: rings 1-5 are white sections (black text)
  // rings 6-8 are on black background (white text)
  final textColor = ringNum <= 6 ? Colors.black : Colors.white;

  // Draw number at 4 positions (top, right, bottom, left)
  for (int angle in [270, 0, 90, 180]) {
    final radians = angle * math.pi / 180;
    final x = center.dx + midRadius * math.cos(radians);
    final y = center.dy + midRadius * math.sin(radians);

    final textPainter = TextPainter(
      text: TextSpan(
        text: ringNum.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 5 * scale / visualScale, // Slightly larger for visibility
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


    // Inner ten
    canvas.drawCircle(center, innerTenRadius, Paint()..color = Colors.black..style = PaintingStyle.fill);
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.2 * scale,
    );

    // Draw shots
    if (shots.isNotEmpty) {
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
  bool shouldRepaint(covariant PistolTargetPainter oldDelegate) => true;
}

class BorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
class WindDirectionDialog extends StatefulWidget {
  final String? currentDirection;

  const WindDirectionDialog({
    super.key,
    this.currentDirection,
  });

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
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
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

            // Wind Direction Compass
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),

                  // Center circle lines (decorative)
                  CustomPaint(
                    size: const Size(280, 280),
                    painter: CompassLinesPainter(),
                  ),

                  // 8 Direction Buttons
                  ..._buildDirectionButtons(),

                  // Center "No Wind" Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDirection = 'NONE';
                      });
                    },
                    child: Container(
                      width: 60,
                      height: 60,
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
                            fontSize: 24,
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

            // Action Buttons
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
    );
  }

  List<Widget> _buildDirectionButtons() {
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
      final radius = 110.0; // Distance from center
      final x = radius * math.sin(angle);
      final y = -radius * math.cos(angle);

      return Positioned(
        left: 140 + x - 30, // Center (140) + offset - half button width
        top: 140 + y - 30,
        child: GestureDetector(
          onTap: () {
            setState(() {
              selectedDirection = dir['label'] as String;
            });
          },
          child: Container(
            width: 60,
            height: 60,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dir['label'] as String,
                  style: TextStyle(
                    color: selectedDirection == dir['label']
                        ? Colors.white
                        : Colors.blue.withOpacity(0.7),
                    fontSize: 10,
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

// Custom Painter for decorative compass lines
class CompassLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw 8 lines from center to edges
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * math.pi / 180;
      final endX = center.dx + 140 * math.sin(angle);
      final endY = center.dy - 140 * math.cos(angle);

      canvas.drawLine(
        center,
        Offset(endX, endY),
        paint,
      );
    }

    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        40.0 * i,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
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
            // Title
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

            // Options List
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.color.withOpacity(0.2)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? widget.color
                            : widget.color.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Selection indicator
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? widget.color
                                : Colors.transparent,
                            border: Border.all(
                              color: widget.color,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Option text
                        Text(
                          option,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Action Buttons
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
                  onPressed: selectedOption != null
                      ? () => Navigator.pop(context, selectedOption)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
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
    );
  }
}
