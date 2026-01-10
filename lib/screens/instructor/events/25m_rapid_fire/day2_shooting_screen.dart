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
import '../25m_sport_pistol/precision_session_report_screen.dart';
import '../../../../models/precision_shot_group.dart';
// Shot model with environmental conditions
// class PrecisionShot {
//   Offset position;
//   Duration shotTime;
//   bool isConfirmed;
//   Set<String> feedback;
//   double score;
//   int ringNumber;
  
//   // Environmental conditions
//   String? light;      // 'Bright', 'Medium', 'Low'
//   String? wind;       // 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'NONE'
//   String? climate;    // 'Sunny', 'Cloudy', 'Rainy', 'Foggy'

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
//   }) : feedback = feedback ?? {};
// }
// Shot Group model for Precision (includes environmental data)
// class PrecisionShotGroup {
//   final int groupNumber;
//   final Duration groupTime;
//   final List<Map<String, dynamic>> shots; // Each shot includes light, wind, climate

//   PrecisionShotGroup({
//     required this.groupNumber,
//     required this.groupTime,
//     required this.shots,
//   });
// }

class SportsRapidShootingScreen extends StatefulWidget {
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

  const SportsRapidShootingScreen({
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
  State<SportsRapidShootingScreen> createState() => _SportsRapidShootingScreen();
}

class _SportsRapidShootingScreen extends State<SportsRapidShootingScreen> {
  bool _isSightingMode = true;
  List<PrecisionShot> _sightingShots = [];
  List<PrecisionShot> _shots = [];
  Duration _sightingTime = Duration.zero;
  
  Timer? _timer;
  Timer? _sessionTimer;
  Duration _currentShotTime = Duration.zero;
  Duration _totalSessionTime = Duration.zero;
  bool _isTimerRunning = false;
  bool _isSessionActive = false;
  bool _sessionStarted = false;
  bool _shotPlaced = false;
  
  int _currentShotIndex = -1;
  final GlobalKey _targetKey = GlobalKey();
  final double _targetSize = 280.0;
  
  List<SessionNote> _sessionNotes = [];
  Duration _accumulatedSessionTime = Duration.zero;
  
  // Zoom variables
  double _zoomLevel = 1.0;
  final double _minZoom = 1.0;
  final double _maxZoom = 3.0;
  final double _zoomStep = 0.5;
  Offset _zoomOffset = Offset.zero;
  
  List<PrecisionShotGroup> _shotGroups = [];
  List<MissedShot> _missedShots = [];
  bool _showTooltips = false;
  List<PhotoData> _photos = [];
  
  DateTime? _sessionStartTime;
  DateTime? _shotStartTime;
  
  bool _isCoach = false;
  
  // Environmental condition indicators
  String? _selectedLight;
  String? _selectedWindDirection;
  String? _selectedClimate;

  @override
  void initState() {
    super.initState();
    _shotGroups.clear();
    _loadExistingShots();
    
    if (widget.existingNotes != null && widget.existingNotes!.isNotEmpty) {
      _sessionNotes = List<SessionNote>.from(widget.existingNotes!);
    }
    
    _checkUserRole();
    
    if (_shots.isEmpty) {
      _addNewShot();
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

  Future<bool> _isCoachRole(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final role = userDoc.data()?['role']?.toString().toLowerCase() ?? 'student';
        return role == 'coach' || role == 'instructor';
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _switchToActualSession() {
    setState(() {
      _isSightingMode = false;
      _shots.clear();
      _currentShotIndex = -1;
      _shotGroups.clear();
      _currentShotTime = Duration.zero;
      _totalSessionTime = Duration.zero;
      _accumulatedSessionTime = Duration.zero;
      
      _timer?.cancel();
      _sessionTimer?.cancel();
      _isTimerRunning = false;
      _isSessionActive = false;
      _sessionStarted = false;
      
      _addNewShot();
      _shotPlaced = true;
    });
    _startSessionTimer();
  }

  double get _calculateSightingScore {
    return _sightingShots.fold(0.0, (sum, shot) => sum + shot.score);
  }

  void _loadExistingShots() {
  if (widget.existingShots != null && widget.existingShots!.isNotEmpty) {
    setState(() {
      _shotGroups.clear();
      _shots = widget.existingShots!.map((shotData) {
        return PrecisionShot.fromMap(shotData); // ✅ Use fromMap
      }).toList();

      if (widget.existingShotGroups != null && widget.existingShotGroups!.isNotEmpty) {
        final lastGroup = widget.existingShotGroups!.last;
        _accumulatedSessionTime = lastGroup.groupTime;
        _totalSessionTime = _accumulatedSessionTime;
      }

      if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
        _photos.addAll(widget.existingImages!);
      }

      if (widget.existingMissedShots != null && widget.existingMissedShots!.isNotEmpty) {
        _missedShots = List<MissedShot>.from(widget.existingMissedShots!);
      }

      // ✅ FIXED: widget.existingSightingShots is now List<PrecisionShot>?
      if (widget.existingSightingShots != null && widget.existingSightingShots!.isNotEmpty) {
        _sightingShots = List<PrecisionShot>.from(widget.existingSightingShots!); // ✅ Just copy the list
        _isSightingMode = false;
      }

      final exactCenter = Offset(_targetSize / 2, _targetSize / 2);
      _shots.add(PrecisionShot(
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
    // ✅ FIXED: widget.existingSightingShots is now List<PrecisionShot>?
    if (widget.existingSightingShots != null && widget.existingSightingShots!.isNotEmpty) {
      setState(() {
        _sightingShots = List<PrecisionShot>.from(widget.existingSightingShots!); // ✅ Just copy the list
        
        _isSightingMode = true;
        _addNewShot();
        _shotPlaced = true;
      });
    }
  }
}


  void _startSessionTimer() {
    _sessionStartTime = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _totalSessionTime = _accumulatedSessionTime + DateTime.now().difference(_sessionStartTime!);
      });
    });
  }

  void _toggleTimer() {
    if (!_sessionStarted && !_isSightingMode) {
      _toggleSession();
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

  void _toggleSession() {
    setState(() {
      _isSessionActive = !_isSessionActive;
      if (_isSessionActive) {
        if (!_sessionStarted) {
          _sessionStarted = true;
          _startSessionTimer();
        }
      } else {
        _sessionTimer?.cancel();
        if (_sessionStartTime != null) {
          _accumulatedSessionTime = _totalSessionTime;
          _sessionStartTime = null;
        }
      }
    });
  }

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < _maxZoom) {
        _zoomLevel += _zoomStep;
        _zoomLevel = _zoomLevel.clamp(_minZoom, _maxZoom);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > _minZoom) {
        _zoomLevel -= _zoomStep;
        _zoomLevel = _zoomLevel.clamp(_minZoom, _maxZoom);
      }
      if (_zoomLevel == _minZoom) {
        _zoomOffset = Offset.zero;
      }
    });
  }

  void _updateShotPosition(Offset localPosition) {
    final currentList = _isSightingMode ? _sightingShots : _shots;
    if (_currentShotIndex < 0 || _currentShotIndex >= currentList.length) return;

    final adjustedPosition = _adjustPositionForZoom(localPosition);
    final clampedX = adjustedPosition.dx.clamp(0.0, _targetSize);
    final clampedY = adjustedPosition.dy.clamp(0.0, _targetSize);
    final clampedPosition = Offset(clampedX, clampedY);

    setState(() {
      currentList[_currentShotIndex].position = clampedPosition;
      // Copy environmental conditions from indicators
      currentList[_currentShotIndex].light = _selectedLight;
      currentList[_currentShotIndex].wind = _selectedWindDirection;
      currentList[_currentShotIndex].climate = _selectedClimate;
      _calculateScore(currentList[_currentShotIndex]);
    });
  }

  Offset _adjustPositionForZoom(Offset localPosition) {
    if (_zoomLevel == 1.0) return localPosition;
    final center = Offset(_targetSize / 2, _targetSize / 2);
    final offsetFromCenter = localPosition - center;
    final adjustedOffset = offsetFromCenter / _zoomLevel;
    return center + adjustedOffset + _zoomOffset;
  }

void _addNewShot() {
  setState(() {
    final exactCenter = Offset(_targetSize / 2, _targetSize / 2);
    if (_isSightingMode) {
      _sightingShots.add(PrecisionShot(
        position: exactCenter,
        shotTime: _sightingTime,
        light: _selectedLight, // ✅ ADD THIS
        wind: _selectedWindDirection, // ✅ ADD THIS
        climate: _selectedClimate, // ✅ ADD THIS
      ));
      _currentShotIndex = _sightingShots.length - 1;
    } else {
      _shots.add(PrecisionShot(
        position: exactCenter,
        shotTime: _currentShotTime,
        light: _selectedLight, // ✅ ADD THIS
        wind: _selectedWindDirection, // ✅ ADD THIS
        climate: _selectedClimate, // ✅ ADD THIS
      ));
      _currentShotIndex = _shots.length - 1;
    }
    _calculateScore(_isSightingMode ? _sightingShots[_currentShotIndex] : _shots[_currentShotIndex]);
  });
}


void _confirmCurrentShot() {
  if (_currentShotIndex < 0) return;

  final currentList = _isSightingMode ? _sightingShots : _shots;

  if (_currentShotIndex >= currentList.length) return;

  final shot = currentList[_currentShotIndex];

  if (!shot.isConfirmed) {
    // ✅ MAXIMUM SHOTS LIMIT CHECK (30 for this event)
    if (!_isSightingMode) {
      final confirmedCount = _shots.where((s) => s.isConfirmed).length;
      if (confirmedCount >= 29) {
        // Show limit reached message
        // Assuming you have a ScaffoldMessenger context available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 30 shots reached'),
            backgroundColor: Color(0xFFD32F2F),
            duration: Duration(seconds: 2),
          ),
        );
        return; // STOP - don't confirm more shots
      }
    }

    _calculateScore(shot);

    setState(() {
      shot.isConfirmed = true;
      
      // ✅ ENSURE environmental data is set before confirming
      if (shot.light == null) shot.light = _selectedLight;
      if (shot.wind == null) shot.wind = _selectedWindDirection;
      if (shot.climate == null) shot.climate = _selectedClimate;

      if (!_isSightingMode) {
        final confirmedShots = _shots.where((s) => s.isConfirmed).toList();

        if (confirmedShots.length % 10 == 0) {
          final groupNumber = confirmedShots.length ~/ 10;
          final startIndex = (groupNumber - 1) * 10;
          final endIndex = groupNumber * 10;
          final groupShots = confirmedShots.sublist(startIndex, endIndex);

          final existingGroupIndex =
              _shotGroups.indexWhere((g) => g.groupNumber == groupNumber);

          if (existingGroupIndex != -1) {
            _shotGroups[existingGroupIndex] = PrecisionShotGroup(
              groupNumber: groupNumber,
              groupTime: _totalSessionTime,
              shots: List<PrecisionShot>.from(groupShots),
            );
          } else {
            _shotGroups.add(PrecisionShotGroup(
              groupNumber: groupNumber,
              groupTime: _totalSessionTime,
              shots: List<PrecisionShot>.from(groupShots),
            ));
          }
        }
      }

      _addNewShot();
      _shotPlaced = true;

      if (_isSightingMode) {
                  _isTimerRunning=false;
          _timer?.cancel();
        _shotStartTime=DateTime.now();
        _sightingTime = Duration.zero;
      } else {
                  _isTimerRunning=false;
          _timer?.cancel();
        _shotStartTime=DateTime.now();
        _currentShotTime = Duration.zero;
      }
    });
  }
}


void _calculateScore(PrecisionShot shot) {
  final center = Offset(_targetSize / 2, _targetSize / 2);
  final shotCenterDistance = (shot.position - center).distance;
  
  // ✅ Scale factor matching the painter: 400mm outer diameter
  final scale = _targetSize / 400.0;
  
  final pelletRadius = 5.6 / 2 * scale; // 5.6mm for .22 LR

  // ✅ 25m Rapid Fire Target - Ring DIAMETERS in mm (from specification)
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
  
  // ✅ Calculate pellet inner edge distance (inward gauging)
  final pelletInnerEdgeDistance = shotCenterDistance - pelletRadius;

  int ringNumber = 0;
  double score = 0.0;

  // ✅ Check if completely outside ring 5 (outermost ring)
  if (pelletInnerEdgeDistance > ringRadii[5]!) {
    ringNumber = 0;
    score = 0.0;
    shot.ringNumber = ringNumber;
    shot.score = score;
    return;
  }

  // ✅ Score from rings 10 down to 5 (no rings 1-4)
  for (int ring = 10; ring >= 5; ring--) {
    final outerRingRadius = ringRadii[ring]!;
    
    if (pelletInnerEdgeDistance <= outerRingRadius) {
      ringNumber = ring;
      
      if (ring == 10) {
        // ✅ FIXED: Ring 10 scoring - 10.0 to 10.9 based on distance from center
        // NO separate inner circle for Rapid Fire targets!
        // When shotCenterDistance = ring10Radius → score = 10.0  
        // When shotCenterDistance = 0 (center) → score = 10.9
        
        final ring10Radius = ringRadii[10]!; // 50mm radius
        
        // Calculate decimal based on shot center distance from center
        // Closer to center = higher score
        final distanceRatio = shotCenterDistance / ring10Radius;
        final scoreRatio = 1.0 - distanceRatio;
        final decimal = scoreRatio * 0.9; // 0.0 to 0.9
        
        score = 10.0 + decimal.clamp(0.0, 0.9);
        score = double.parse(score.toStringAsFixed(1));
      } else {
        // ✅ Rings 9-5: score with decimal (e.g., 9.0 to 9.9)
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


  void _goToPreviousShot() {
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

  void _goToNextShot() {
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

  List<PrecisionShot> _getVisibleShots() {
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
      return '$hours:$minutes:$seconds';
    } else {
      return '00:$minutes:$seconds';
    }
  }

  void _toggleFeedback(String feedbackId) {
      if(_isSightingMode){
 if (_currentShotIndex >= 0 && _currentShotIndex < _sightingShots.length) {
    print("feedback clicked ..");
    setState(() {
      final shot = _sightingShots[_currentShotIndex];
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
    if (_currentShotIndex < 0 || _currentShotIndex >= _shots.length) return;

    setState(() {
      final shot = _shots[_currentShotIndex];
      if (shot.feedback.contains(feedbackId)) {
        shot.feedback.remove(feedbackId);
      } else {
        shot.feedback.add(feedbackId);
      }

      if (feedbackId == 'dry' || feedbackId == 'cross') {
        if (shot.feedback.contains(feedbackId)) {
          _shotPlaced = false;
        }
      }
    });
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
            if (_sessionNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_sessionNotes.length} previous ${_sessionNotes.length == 1 ? "note" : "notes"} saved',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

    if (result != null) {
      if (result.trim().isNotEmpty) {
        _sessionNotes.add(SessionNote(
          note: result.trim(),
          timestamp: DateTime.now(),
        ));
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SavingSessionDialog(),
      );

      await _saveSession(result, _photos);
    }
  }

  Future<void> _saveSession(String finalNotes, List<PhotoData>? photos) async {
    _sessionTimer?.cancel();
    _timer?.cancel();
    _createRemainingGroup();

    final sessionService = SessionService();
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCoach = await _isCoachRole(currentUser!.uid);

    final confirmedShots = _shots.where((shot) => shot.isConfirmed).toList();
    
    // Convert PrecisionShot to Map with environmental data
    List<Map<String, dynamic>> allShots = confirmedShots.map((shot) => {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds,
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
      'light': shot.light,      // NEW
      'wind': shot.wind,        // NEW
      'climate': shot.climate,  // NEW
    }).toList();

    // Sighting shots with environmental data
    List<Map<String, dynamic>> sightingData = _sightingShots.map((shot) => {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds,
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
      'light': shot.light,      // NEW
      'wind': shot.wind,        // NEW
      'climate': shot.climate,  // NEW
    }).toList();

    List<Map<String, dynamic>> allMissedShots = [];
    if (widget.existingMissedShots != null && widget.existingMissedShots!.isNotEmpty) {
      allMissedShots.addAll(widget.existingMissedShots!.map((missed) => missed.toJson()));
    }
    allMissedShots.addAll(
      _missedShots.skip(widget.existingMissedShots?.length ?? 0).map((missed) => missed.toJson())
    );

    List<Map<String, dynamic>> allNotesData = _sessionNotes.map((note) => note.toJson()).toList();

        await sessionService.saveSessionShots(
          sessionId: widget.sessionId,
          shots: allShots,
          totalScore: _calculateTotalScore,
          totalTime: _totalSessionTime,
          notes: finalNotes,
          notesList: allNotesData,
          shotGroups: _shotGroups.map((group) => {
          'groupNumber': group.groupNumber,
          'groupTime': group.groupTime.inMilliseconds,
          'shotCount': group.shots.length,
          'shots': group.shots.map((shot) => {  // ✅ Convert each PrecisionShot to Map!
        'x': shot.position.dx,
        'y': shot.position.dy,
        'score': shot.score,
        'time': shot.shotTime.inMilliseconds,
        'feedback': shot.feedback.toList(),
        'ring': shot.ringNumber,
        'light': shot.light,
        'wind': shot.wind,
        'climate': shot.climate,
      }).toList(),  // Already in correct Map format!
        }).toList(),
          missedShots: allMissedShots,
          sightingShots: sightingData,
          sightingTotalScore: _calculateSightingScore,
        );


    if (isCoach && photos != null && photos.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ImageUploadProgressDialog(
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
        print('Auto-share failed: $e');
      }
    }

    // Navigate to Precision Report Screen (create this separately)
final reportData = PrecisionSessionReportData(
  sessionName: widget.sessionName,
  studentName: widget.studentName,
  shots: allShots,
  totalScore: _calculateTotalScore,
  totalTime: _totalSessionTime,
  eventType: '25m Rapid Pistol',
  notes: finalNotes,
  notesList: _sessionNotes,
  shotGroups: _shotGroups,
  missedShots: allMissedShots.isNotEmpty
      ? allMissedShots.map((m) => MissedShot(
            shotNumber: m['shotNumber'],
            feedback: Set<String>.from(m['feedback']),
            shotTime: Duration(milliseconds: m['time']),
          )).toList()
      : null,
  sightingShots: sightingData,
  sightingTotalScore: _calculateSightingScore,
);


    Navigator.of(context, rootNavigator: true).pop();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PrecisionSessionReportScreen(
          reportData: reportData,
          sessionId: widget.sessionId,
          shotsPerTarget: widget.shotsPerTarget,
          photos: photos ?? [],
        ),
      ),
    );
  }

  void _createRemainingGroup() {
    if (_shots.isEmpty) return;
    
    final confirmedShots = _shots.where((shot) => shot.isConfirmed).toList();
    final totalGroupedShots = _shotGroups.length * 10;
    final remainingShots = confirmedShots.length - totalGroupedShots;

    if (remainingShots > 0) {
      final startIndex = totalGroupedShots;
      final endIndex = confirmedShots.length;
      final remainingGroupShots = confirmedShots.sublist(startIndex, endIndex);
      final groupNumber = _shotGroups.length + 1;

      final existingGroupIndex = _shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
      
if (existingGroupIndex != -1) {
  _shotGroups[existingGroupIndex] = PrecisionShotGroup(
    groupNumber: groupNumber,
    groupTime: _totalSessionTime,
    shots: List<PrecisionShot>.from(remainingGroupShots), // ✅ Store PrecisionShot directly
  );
} else {
  _shotGroups.add(PrecisionShotGroup(
    groupNumber: groupNumber,
    groupTime: _totalSessionTime,
    shots: List<PrecisionShot>.from(remainingGroupShots), // ✅ Store PrecisionShot directly
  ));
}

    }
  }

  final ValueNotifier<int> _uploadProgress = ValueNotifier(0);

  void _updateUploadProgress(int current, int total) {
    _uploadProgress.value = current;
  }

  double get _calculateTotalScore {
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

  void _showImageNoteDialog(Uint8List imageBytes, Function(String, Uint8List) onSave) {
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

  Future<void> _pickImageFromGallery() async {
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
        print('⚠️ Large image file: ${bytes.length / (1024*1024)}MB');
      }
      
      _showImageNoteDialog(bytes, (note, originalBytes) async {
        try {
          final localPath = await _saveImageLocally(originalBytes);
          final shotGroup = _currentShotGroup;
          
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
          print('❌ Error saving image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving image: $e')),
            );
          }
        }
      });
    }
  } catch (e) {
    print('❌ Error picking image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}

Future<void> _captureImageFromCamera() async {
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
        print('⚠️ Large image file: ${bytes.length / (1024*1024)}MB');
      }
      
      _showImageNoteDialog(bytes, (note, originalBytes) async {
        try {
          final localPath = await _saveImageLocally(originalBytes);
          final shotGroup = _currentShotGroup;
          
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
          print('❌ Error saving image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving image: $e')),
            );
          }
        }
      });
    }
  } catch (e) {
    print('❌ Error capturing image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }
}


  int get _currentShotGroup {
    if (_shots.isEmpty) return 1;
    return (_shots.length - 1) ~/ 10 + 1;
  }

  Future<String> _saveImageLocally(Uint8List imageBytes) async {
  try {
    // ✅ FIXED: Create session directory first
    final directory = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${directory.path}/session_${widget.sessionId}');
    
    // ✅ Create directory if it doesn't exist
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
      print('✅ Created session directory: ${sessionDir.path}');
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'img_$timestamp.jpg';
    final filePath = '${sessionDir.path}/$fileName';
    
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    
    print('✅ Image saved: $filePath');
    return filePath;
  } catch (e) {
    print('❌ Error saving image locally: $e');
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
              await _pickImageFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () async {
              Navigator.of(context).pop();
              await _captureImageFromCamera();
            },
          ),
        ],
      ),
    );
  }

  // Environmental condition dialogs
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isSightingMode ? Colors.orange : const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isSightingMode ? 'Sighting' : 'Rapid',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
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
          if (!_isSightingMode)
            // OutlinedButton(
            //   onPressed: _toggleSession,
            //   style: OutlinedButton.styleFrom(
            //     foregroundColor: _isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
            //     side: BorderSide(
            //       color: _isSessionActive ? const Color(0xFFD32F2F) : Colors.grey,
            //     ),
            //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            //     minimumSize: const Size(0, 0),
            //   ),
            //   child: Text(
            //     _isSessionActive ? 'End' : 'Begin',
            //     style: const TextStyle(fontSize: 11),
            //   ),
            // ),
          const SizedBox(width: 8),
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
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Target
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
                                _updateShotPosition(localPosition);
                              }
                            }
                          },
                          onTapDown: (details) {
                            if (_shotPlaced) {
                              final RenderBox? renderBox =
                                  _targetKey.currentContext?.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox.globalToLocal(details.globalPosition);
                                _updateShotPosition(localPosition);
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
                                      painter: RapidTargetPainter(
                                        shots: _getVisibleShots(),
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

                    // Camera Icon (centered) with 3 Indicator Buttons on the right
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

                    // Zoom buttons & Scores
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                    _calculateTotalScore.toStringAsFixed(1),
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

                    // Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTooltipWrapper(
                          label: 'Previous',
                          alignment: Alignment.topCenter,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                            onPressed: currentList.isNotEmpty ? _goToPreviousShot : null,
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
                              '${_currentShotIndex + 1}/${currentList.length}',
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

                                    _addNewShot();
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
                                  _goToNextShot();
                                } else {
                                  _confirmCurrentShot();
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

                    // Feedback buttons - Only show for coaches
                    if (_isCoach)
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

          // PINNED bottom section
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
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

  Widget _buildCompactFeedbackButton(String iconId, String label, PrecisionShot? currentShot) {
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

    // ✅ CORRECT: Horizontal line ACROSS ENTIRE TARGET (ring 5 left to ring 5 right)
    // ✅ UPDATED: Horizontal aiming line from RING 7 INNER to RING 5 OUTER edge only
// ✅ FIXED: Line from RING 7 INNER (left) to RING 5 OUTER (right)
// After numbers section, before inner ten:
// ✅ TWO LINES: Center → LEFT (ring 7 inner) + Center → RIGHT (ring 5 outer)
// ✅ LEFT LINE with GAP from center (shortened radius)
// ✅ LEFT LINE: Gap at OUTER END (ring 7 side)
// ✅ LEFT LINE: Gap at RIGHT END (opposite side near ring 7)
// ✅ LEFT LINE like "Line 2": OUTER ring 7 edge → INNER (with gap)
final Paint linePaint = Paint()
  ..color = Colors.white
  ..strokeWidth = 2.5 * scale
  ..style = PaintingStyle.stroke;

// LEFT Line 2: Ring 7 OUTER edge → shortened inner end
final ring7Radius = ringRadii[5]!;
final innerGap = 95.0 * scale;  // Gap from center side (like Line 2)
final leftInnerEndRadius = ring7Radius - innerGap;  // Inner stop point

canvas.drawLine(
  Offset(center.dx - ring7Radius, center.dy),  // START: Ring 7 outer edge
  Offset(center.dx - leftInnerEndRadius, center.dy),  // END: Inner with gap
  linePaint,
);

// RIGHT line: Full center to ring 5 outer
// ✅ RIGHT LINE: Ring 5 OUTER edge → INNER (same Line 2 style)
final ring5Radius = ringRadii[5]!;
final rightInnerGap = 95.0 * scale;  // Same gap as left (adjust as needed)
final rightInnerEndRadius = ring5Radius - rightInnerGap;

canvas.drawLine(
  Offset(center.dx + ring5Radius, center.dy),    // START: Ring 5 outer edge
  Offset(center.dx + rightInnerEndRadius, center.dy),  // END: Inner with gap
  linePaint,
);




    // ✅ Inner ten (black with white border)
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );

    // ✅ Draw shots
    if (shots.isNotEmpty) {
      final pelletRadius = 5.6 / 2 * scale;

      for (int i = 0; i < shots.length; i++) {
        double opacity = _getOpacityForShot(i, currentShotIndex, shotsPerBatch, shots.length);

        if (opacity == 0.0) continue;

        final shot = shots[i];
        final isCurrent = i == currentShotIndex;
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
    if (shotIndex > currentShotIndex) return 0.0;

    int batchStart = (currentShotIndex ~/ shotsPerBatch) * shotsPerBatch;
    int batchEnd = math.min(batchStart + shotsPerBatch, totalShots);

    int shotsInCurrentBatch = batchEnd - batchStart;
    int age = shotIndex - batchStart;

    if (age < 0) {
      return 0.3;
    }

    if (age == currentShotIndex % shotsPerBatch) {
      return 1.0;
    }

    return 0.5 + 0.5 * (age / (shotsInCurrentBatch - 1));
  }

  @override
  bool shouldRepaint(covariant RapidTargetPainter oldDelegate) => true;
}



// Border Painter
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
