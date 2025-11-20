import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'session_report_screen.dart';
import '../../widgets/shooting_feedback_icons.dart';
import '../../services/session_service.dart';
import '../../models/missed_shoot.dart';
import '../../models/photo_data.dart';
import '../../models/session_notes.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart' hide TextDirection; // ✅ Hide the conflicting class



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

class PistolShootingScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;
  final List<Map<String, dynamic>>? existingShots;
  final List<MissedShot>? existingMissedShots; // Add this to constructor params
  final List<PhotoData>? existingImages; 
final List<ShotGroup>?existingShotGroups;
  final String studentName;
   final List<SessionNote>? existingNotes;

  const PistolShootingScreen({
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
  });

  @override
  State<PistolShootingScreen> createState() => _PistolShootingScreenState();
}

class _PistolShootingScreenState extends State<PistolShootingScreen> {
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
  _loadExistingShots();
      if (widget.existingNotes != null && widget.existingNotes!.isNotEmpty) {
      sessionNotes = List<SessionNote>.from(widget.existingNotes!);
    }
  
  // ✅ FIXED: Only add shot if no existing shots were loaded
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
List<Map<String, dynamic>> allShots = [];
void _loadExistingShots() {
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

      // ✅ Restore session time from LAST group's groupTime
      if (widget.existingShotGroups != null && widget.existingShotGroups!.isNotEmpty) {
        final lastGroup = widget.existingShotGroups!.last;
        _accumulatedSessionTime = lastGroup.groupTime;
        _totalSessionTime = _accumulatedSessionTime;
        
        print('✅ Restored session time from group ${lastGroup.groupNumber}: ${_accumulatedSessionTime.inSeconds}s');
      } else {
        _accumulatedSessionTime = Duration.zero;
        _totalSessionTime = Duration.zero;
      }

      // ✅ CRITICAL FIX: DON'T load existing shot groups yet
      // They will be recreated from the shots array during confirmCurrentShot()
      // This prevents duplicate groups
      
      // However, we DO need to populate shotGroups with COMPLETE groups that won't change
      // Calculate how many confirmed shots we have
      final confirmedCount = widget.existingShots!.length;
      final completeGroupCount = confirmedCount ~/ 10;
      
      // Only add complete groups that are fully loaded from existing shots
      if (widget.existingShotGroups != null && widget.existingShotGroups!.isNotEmpty) {
        // Add only the complete groups (first completeGroupCount groups)
        for (int i = 0; i < completeGroupCount; i++) {
          final existingGroup = widget.existingShotGroups!
              .firstWhere((g) => g.groupNumber == (i + 1), orElse: () => null as ShotGroup);
          
          if (existingGroup != null) {
            _shotGroups.add(existingGroup);
          }
        }
        print('✅ Loaded ${_shotGroups.length} complete groups from existing data');
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
  }

  // Load missed shots
  if (widget.existingMissedShots != null && widget.existingMissedShots!.isNotEmpty) {
    _missedShots = List<MissedShot>.from(widget.existingMissedShots!);
  } else {
    _missedShots = [];
  }

  // Load existing images
  if (widget.existingImages != null && widget.existingImages!.isNotEmpty) {
    setState(() {
      _photos.addAll(widget.existingImages!);
    });
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
    if (!_sessionStarted) {
      _toggleSession(); // Auto-start session if not started
    }

    setState(() {
      _isTimerRunning = !_isTimerRunning;

      if (_isTimerRunning) {
        // Start shot timer from current shot's existing time
        _shotStartTime = DateTime.now();
        _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          setState(() {
            // Calculate elapsed time for THIS shot only
            final elapsed = DateTime.now().difference(_shotStartTime!);
            
            // For NEW shots, start from zero
            // For EXISTING shots being edited, preserve their time (but this is rare)
            _currentShotTime = elapsed;

            // Update the current shot's time
            if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
              _shots[_currentShotIndex].shotTime = _currentShotTime;
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

  void _updateShotPosition(Offset localPosition) {
    if (_justCreatedShot) return;

    if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
      // ✅ Adjust for zoom
      final adjustedPosition = _adjustPositionForZoom(localPosition);
      
      final clampedX = adjustedPosition.dx.clamp(0.0, _targetSize);
      final clampedY = adjustedPosition.dy.clamp(0.0, _targetSize);
      final clampedPosition = Offset(clampedX, clampedY);

      setState(() {
        _shots[_currentShotIndex].position = clampedPosition;
        _calculateScore(_shots[_currentShotIndex]);
      });
    }
  }

  // ✅ NEW: Adjust position for zoom level
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
      _shots.add(Shot(
        position: exactCenter,
        shotTime: _currentShotTime,
      ));
      _currentShotIndex = _shots.length - 1;
      _calculateScore(_shots[_currentShotIndex]);
    });
  }

  void _confirmCurrentShot() {
    if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
      final shot = _shots[_currentShotIndex];

      if (!shot.isConfirmed) {
        _calculateScore(shot);
        
        setState(() {
          shot.isConfirmed = true;
          _printShotData(shot, _currentShotIndex + 1);

          // ✅ Create shot group every 10 CONFIRMED shots
          // Count only CONFIRMED shots to determine if group is complete
          final confirmedShots = _shots.where((s) => s.isConfirmed).toList();
          
          if (confirmedShots.length % 10 == 0) {
            final groupNumber = confirmedShots.length ~/ 10;
            final startIndex = (groupNumber - 1) * 10;
            final endIndex = groupNumber * 10;
            final groupShots = confirmedShots.sublist(startIndex, endIndex);
            
            // ✅ CRITICAL: Check if this group already exists (from previous edit session)
            final existingGroupIndex = _shotGroups.indexWhere((g) => g.groupNumber == groupNumber);
            
            if (existingGroupIndex != -1) {
              // ✅ Group exists - UPDATE it with new session time
              _shotGroups[existingGroupIndex] = ShotGroup(
                groupNumber: groupNumber,
                groupTime: _totalSessionTime, // ✅ Accumulated + current
                shots: groupShots,
              );
              print('✅ Updated group $groupNumber with session time: ${_totalSessionTime.inSeconds}s');
            } else {
              // ✅ New group - ADD it
              _shotGroups.add(ShotGroup(
                groupNumber: groupNumber,
                groupTime: _totalSessionTime, // ✅ Accumulated + current
                shots: groupShots,
              ));
              print('✅ Created group $groupNumber with session time: ${_totalSessionTime.inSeconds}s');
            }
          }

          // Create next shot
          _addNewShot();
          _shotPlaced = true;
          _currentShotTime = Duration.zero;

        });
      }
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










  void _printShotData(Shot shot, int shotNumber) {
    print('Shot $shotNumber:');
    print('  Position: (${shot.position.dx.toStringAsFixed(2)}, ${shot.position.dy.toStringAsFixed(2)})');
    print('  Time: ${_formatDurationWithMillis(shot.shotTime)}');
    print('  Ring: ${shot.ringNumber}');
    print('  Score: ${shot.score.toStringAsFixed(1)}');
    print('  Feedback: ${shot.feedback.join(', ')}');
    print('---');
  }

void _goToPreviousShot() {
  if (_shots.isEmpty) return;

  setState(() {
    if (_currentShotIndex > 0) {
      _currentShotIndex--;

      // Reset timer and currentShotTime from selected shot
      _currentShotTime = _shots[_currentShotIndex].shotTime;
      _shotPlaced = true;
    }
  });
}

void _goToNextShot() {
  if (_shots.isEmpty) return;

  setState(() {
    if (_currentShotIndex < _shots.length - 1) {
      _currentShotIndex++;

      // Reset timer and currentShotTime from selected shot
      _currentShotTime = _shots[_currentShotIndex].shotTime;
      _shotPlaced = true;
    }
  });
}


List<Shot> getVisibleShots() {
  if (_shots.isEmpty) return [];

  final int batchNumber = _currentShotIndex ~/ widget.shotsPerTarget;

  final int start = batchNumber * widget.shotsPerTarget;
  final int end = (start + widget.shotsPerTarget).clamp(0, _shots.length);

  return _shots.sublist(start, end);
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
          // Optional: Show count of existing notes
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
    // Add new note to list if not empty
    if (result.trim().isNotEmpty) {
      sessionNotes.add(SessionNote(
        note: result.trim(),
        timestamp: DateTime.now(),
      ));
    }
    
    await _saveSession(result, _photos);
  }
}



 // ✅ FIXED: Save ALL shots (existing + new), not just new ones
  Future<void> _saveSession(String finalNotes, [List<PhotoData>? photos]) async {
    _sessionTimer?.cancel();
    _timer?.cancel();

    _createRemainingGroup();

    final sessionService = SessionService();

    // ✅ CRITICAL: Prepare ALL shots (existing + new)
    // Remove the unconfirmed "placeholder" shot at the end
    final confirmedShots = _shots.where((shot) => shot.isConfirmed).toList();
    
    List<Map<String, dynamic>> allShots = confirmedShots.map((shot) => {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds, // Individual shot time
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
    }).toList();

    // ✅ Prepare ALL missed shots (existing + new)
    List<Map<String, dynamic>> allMissedShots = [];
    if (widget.existingMissedShots != null && widget.existingMissedShots!.isNotEmpty) {
      allMissedShots.addAll(widget.existingMissedShots!.map((missed) => missed.toJson()));
    }
    allMissedShots.addAll(
      _missedShots.skip(widget.existingMissedShots?.length ?? 0).map((missed) => missed.toJson())
    );
  List<Map<String, dynamic>> allNotesData = sessionNotes.map((note) => note.toJson()).toList();
    // ✅ SAVE: totalTime = totalSessionTime (accumulated from all sessions)
    await sessionService.saveSessionShots(
      sessionId: widget.sessionId,
      shots: allShots, // ✅ ALL shots, not just new ones
      totalScore: _calculateTotalScore(),
      totalTime: _totalSessionTime, // ✅ Accumulated session time
      notes: finalNotes,
      notesList: allNotesData,
      shotGroups: _shotGroups.map((group) => {
        'groupNumber': group.groupNumber,
        'groupTime': group.groupTime.inMilliseconds, // ✅ Each group's accumulated time
        'shotCount': group.shots.length,
      }).toList(),
      missedShots: allMissedShots,
    );

    print('✅ Saved ${allShots.length} shots with total session time: ${_totalSessionTime.inSeconds}s');
    print('✅ Saved ${_shotGroups.length} complete groups');

    // Upload images if any
  if (photos != null && photos.isNotEmpty) {
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => _ImageUploadProgressDialog(
    totalImages: photos.length,
    uploadProgress: _uploadProgress, // <-- REQUIRED ARGUMENT!
  ),
);

    try {
      await sessionService.saveSessionImages(
        sessionId: widget.sessionId,
        photos: photos,
        onProgress: (current, total) {
          // Update progress in dialog
          _updateUploadProgress(current, total);
        },
      );

      Navigator.of(context).pop(); // Close loading dialog
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog on error
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
      return;
    }
  }

    // Navigate to report
    final reportData = SessionReportData(
      sessionName: widget.sessionName,
      studentName: widget.studentName,
      shots: allShots,
      totalScore: _calculateTotalScore(),
      totalTime: _totalSessionTime,
      eventType: 'Pistol',
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
    );

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


  // void _createRemainingGroup() {
  //   if (_shots.isEmpty) return;

  //   final totalGroupedShots = _shotGroups.length * 10;
  //   final remainingShots = _shots.length - totalGroupedShots;

  //   if (remainingShots > 0) {
  //     final startIndex = totalGroupedShots;
  //     final endIndex = _shots.length;
  //     final remainingGroupShots = _shots.sublist(startIndex, endIndex);
  //     final groupNumber = _shotGroups.length + 1;

  //     _shotGroups.add(ShotGroup(
  //       groupNumber: groupNumber,
  //       groupTime: _totalSessionTime,
  //       shots: remainingGroupShots,
  //     ));
  //   }
  // }
final ValueNotifier<int> _uploadProgress = ValueNotifier(0);
void _updateUploadProgress(int current, int total) {
  _uploadProgress.value = current;
}
  double _calculateTotalScore() {
    return _shots.fold(0.0, (sum, shot) => sum + shot.score);
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
@override
Widget build(BuildContext context) {
  final currentShot = _currentShotIndex >= 0 && _currentShotIndex < _shots.length
      ? _shots[_currentShotIndex]
      : null;

  // ✅ Calculate responsive sizes
  final screenHeight = MediaQuery.of(context).size.height;
  final appBarHeight = kToolbarHeight;
  final statusBarHeight = MediaQuery.of(context).padding.top;
  final availableHeight = screenHeight - appBarHeight - statusBarHeight;
  
  // ✅ Adjust target size based on available space
  final responsiveTargetSize = math.min(_targetSize, availableHeight * 0.35);

  return Scaffold(
    backgroundColor: const Color(0xFF1A1A1A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // ✅ NEW: Title with Pistol badge
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Pistol',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Session Time
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
        // ✅ Begin/End button
        OutlinedButton(
          onPressed: _toggleSession,
          style: OutlinedButton.styleFrom(
            foregroundColor: _isSessionActive
                ? const Color(0xFFD32F2F)
                : Colors.grey,
            side: BorderSide(
              color: _isSessionActive
                  ? const Color(0xFFD32F2F)
                  : Colors.grey,
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
    // ✅ Scrollable content area
    Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 8),
              
              // Target
              Center(
                child: GestureDetector(
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
                              painter: PistolTargetPainter(
                                shots: getVisibleShots(),
                                currentShotIndex:  _currentShotIndex % widget.shotsPerTarget,
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
              // Zoom buttons
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
                                _calculateTotalScore().toStringAsFixed(1),
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
              Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation (Previous, Shot #, Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTooltipWrapper(
                label: 'Previous',
                alignment: Alignment.topCenter,
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                  onPressed: _shots.isNotEmpty ? _goToPreviousShot : null,
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
                    '${_currentShotIndex >= 0 ? _currentShotIndex + 1 : _shots.length}',
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
                    if (_currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
                      final currentShot = _shots[_currentShotIndex];
                      if (currentShot.feedback.contains('dry') || currentShot.feedback.contains('cross')) {
                        setState(() {
                          _missedShots.add(MissedShot(
                            shotNumber: _currentShotIndex + 1,
                            feedback: Set<String>.from(currentShot.feedback),
                            shotTime: _currentShotTime,
                          ));
                          _shots.removeAt(_currentShotIndex);
                          _addNewShot();
                          _shotPlaced = true;
                          _currentShotTime = Duration.zero;
                          _zoomLevel = 1.0;
                          _zoomOffset = Offset.zero;
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
                        _currentShotTime = Duration.zero;
                        _isTimerRunning = false;
                        _timer?.cancel();
                        if (_shots.isNotEmpty && _currentShotIndex >= 0 && _currentShotIndex < _shots.length) {
                          _shots[_currentShotIndex].feedback.clear();
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
                  _formatDurationWithMillis(_currentShotTime),
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
        ],
      ),
    ),
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
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
    
    // ✅ PINNED bottom section
    Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Navigation (Previous/Next/Shot#)

          
          

          
          // ✅ Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSessionWithNotes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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
