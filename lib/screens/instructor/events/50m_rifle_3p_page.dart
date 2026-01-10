import 'package:ShotMetrix/models/precision_shot_group.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../services/session_service.dart';
import '../../../../../models/photo_data.dart';
import '../../../../../models/missed_shoot.dart';
import '../../../../../models/session_notes.dart';
import 'dart:math' as math;
import '../../../models/shot_group.dart' hide ShotGroup, Shot;
import '50m_rifle_3p/kneeling_shooting_screen.dart';
import '25m_sport_pistol/precision_session_report_screen.dart'; // ✅ Import report screen

class Rifle3PPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;

  const Rifle3PPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.sessionId,
    required this.sessionName,
    required this.shotsPerTarget
  });

  String formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} | ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '50m Rifle 3P',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/customicon.png',
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.shield, color: Colors.white, size: 24);
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Student name and datetime row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatDateTime(Timestamp.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Session cards list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSubEventCard(
                  context,
                  subEvent: 'Kneeling',
                  shots: shotsPerTarget,
                ),
                const SizedBox(height: 12),
                _buildSubEventCard(
                  context,
                  subEvent: 'Prone',
                  shots: shotsPerTarget,
                ),
                const SizedBox(height: 12),
                _buildSubEventCard(
                  context,
                  subEvent: 'Standing',
                  shots: shotsPerTarget,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubEventCard(
    BuildContext context, {
    required String subEvent,
    required int shots,
  }) {
    return GestureDetector(
      onTap: () => _openSessionOrReport(context, subEvent: subEvent, shots: shots), // ✅ Changed
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subEvent,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$shots shots',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // EDIT BUTTON - Opens shooting screen for editing
                      InkWell(
                        onTap: () async {
                          final sessionService = SessionService();
                          final subSessionId = '${sessionId}_${subEvent.toLowerCase()}';
                          final sessionData = await sessionService.getSessionData(subSessionId);

                          if (sessionData != null && sessionData['hasShots'] == true) {
                            // ✅ Has shots - open shooting screen for editing
                            _openShootingScreen(context, subEvent: subEvent, shots: shots);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No shots to edit yet'),
                                backgroundColor: Color(0xFF2A2A2A),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/images/edit.png',
                            width: 20,
                            height: 20,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // DELETE BUTTON
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text('Delete Session',
                                  style: TextStyle(color: Colors.white)),
                              content: Text(
                                  'Are you sure you want to delete "$subEvent"?',
                                  style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Color(0xFFD32F2F))),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final subSessionId = '${sessionId}_${subEvent.toLowerCase()}';
                            await SessionService().deleteSession(subSessionId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$subEvent deleted'),
                                  backgroundColor: const Color(0xFF2A2A2A),
                                ),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/delete.png',
                            width: 20,
                            height: 20,
                            color: Colors.white.withOpacity(0.6),
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.delete_outline,
                                  color: Colors.white.withOpacity(0.6), size: 20);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // SHARE BUTTON
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Share functionality coming soon'),
                              backgroundColor: Color(0xFF2A2A2A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/share.png',
                            width: 20,
                            height: 20,
                            color: Colors.white.withOpacity(0.6),
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.share_outlined,
                                  color: Colors.white.withOpacity(0.6), size: 20);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW METHOD: Opens report if has shots, otherwise opens shooting screen
  Future<void> _openSessionOrReport(
    BuildContext context, {
    required String subEvent,
    required int shots,
  }) async {
    final sessionService = SessionService();
    final subSessionId = '${sessionId}_${subEvent.toLowerCase()}';
    final sessionData = await sessionService.getSessionData(subSessionId);

    if (sessionData != null && sessionData['hasShots'] == true) {
      // ✅ Has shots - open REPORT screen
      _openReportScreen(context, subEvent: subEvent, shots: shots);
    } else {
      // ✅ No shots - open SHOOTING screen
      _openShootingScreen(context, subEvent: subEvent, shots: shots);
    }
  }

  // ✅ NEW METHOD: Open report screen (uses same report as Sports Pistol)
  Future<void> _openReportScreen(
    BuildContext context, {
    required String subEvent,
    required int shots,
  }) async {
    final sessionService = SessionService();
    final subSessionId = '${sessionId}_${subEvent.toLowerCase()}';
    final sessionData = await sessionService.getSessionData(subSessionId);
    final photos = await sessionService.getSessionImages(subSessionId);

    if (sessionData == null) return;

    final allShots = List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);
    
    // Load sighting shots
    final sightingShots = sessionData['sightingShots'] as List<dynamic>?;
    final sightingData = sightingShots != null
        ? List<Map<String, dynamic>>.from(sightingShots)
        : null;
    final sightingTotalScore = (sessionData['sightingTotalScore'] as num?)?.toDouble();

    // Load missed shots
    final missedShotsData = sessionData['missedShots'] as List<dynamic>?;
    final missedShotsList = missedShotsData != null
        ? missedShotsData
            .map((d) => MissedShot(
                  shotNumber: d['shotNumber'] as int,
                  feedback: Set<String>.from(d['feedback'] ?? []),
                  shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                ))
            .toList()
        : null;

    // Load shot groups
    final List<PrecisionShotGroup> shotGroups = [];
    if (sessionData['shotGroups'] != null) {
      for (var g in sessionData['shotGroups'] as List) {
        shotGroups.add(PrecisionShotGroup.fromMap(g));
      }
    }

    // Load notes
    List<SessionNote>? notesList;
    if (sessionData['notesList'] != null) {
      notesList = (sessionData['notesList'] as List)
          .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
          .toList();
    }

    final reportData = PrecisionSessionReportData(
      sessionName: '$sessionName - $subEvent',
      studentName: studentName,
      shots: allShots,
      totalScore: (sessionData['totalScore'] ?? 0.0).toDouble(),
      totalTime: Duration(milliseconds: sessionData['totalTime'] ?? 0),
      eventType: '50m Rifle 3P ($subEvent)', // ✅ Include position in event type
      notes: sessionData['notes'] ?? '',
      notesList: notesList,
      shotGroups: shotGroups,
      missedShots: missedShotsList,
      sightingShots: sightingData,
      sightingTotalScore: sightingTotalScore,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrecisionSessionReportScreen(
          reportData: reportData,
          sessionId: subSessionId,
          shotsPerTarget: shots,
          photos: photos,
        ),
      ),
    );
  }

  // ✅ MODIFIED: Opens shooting screen (for new sessions or editing)
  Future<void> _openShootingScreen(
    BuildContext context, {
    required String subEvent,
    required int shots,
  }) async {
    final sessionService = SessionService();
    final subSessionId = '${sessionId}_${subEvent.toLowerCase()}';
    final sessionData = await sessionService.getSessionData(subSessionId);
    final photos = await sessionService.getSessionImages(subSessionId);

    if (sessionData != null && sessionData['hasShots'] == true) {
      // ✅ Has existing data - load for editing
      final allShots = List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);
      
      final sightingShots = sessionData['sightingShots'] as List<dynamic>?;
      final existingSightingShots = sightingShots != null
          ? sightingShots.map((shotData) {
              return PrecisionShot.fromMap(shotData as Map<String, dynamic>);
            }).toList()
          : null;

      final missedShotsData = sessionData['missedShots'] as List<dynamic>?;
      final missedShotsList = missedShotsData != null
          ? missedShotsData
              .map((d) => MissedShot(
                    shotNumber: d['shotNumber'] as int,
                    feedback: Set<String>.from(d['feedback'] ?? []),
                    shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                  ))
              .toList()
          : null;

      final List<PrecisionShotGroup> shotGroups = [];
      if (sessionData['shotGroups'] != null) {
        for (var g in sessionData['shotGroups'] as List) {
          shotGroups.add(PrecisionShotGroup.fromMap(g));
        }
      }

      List<SessionNote>? notesList;
      if (sessionData['notesList'] != null) {
        notesList = (sessionData['notesList'] as List)
            .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
            .toList();
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KneelingShootingScreen(
            sessionId: subSessionId,
            sessionName: '$sessionName - $subEvent',
            shotsPerTarget: shots,
            existingShots: allShots,
            existingMissedShots: missedShotsList,
            studentName: studentName,
            existingImages: photos,
            existingShotGroups: shotGroups,
            existingNotes: notesList,
            existingSightingShots: existingSightingShots,
          ),
        ),
      );
    } else {
      // ✅ New session - check for sighting shots only
      final sightingShots = sessionData?['sightingShots'] as List<dynamic>?;
      final existingSightingShots = sightingShots != null
          ? sightingShots.map((shotData) {
              return PrecisionShot.fromMap(shotData as Map<String, dynamic>);
            }).toList()
          : null;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KneelingShootingScreen(
            sessionId: subSessionId,
            sessionName: '$sessionName - $subEvent',
            shotsPerTarget: shots,
            studentName: studentName,
            existingImages: photos,
            existingSightingShots: existingSightingShots,
          ),
        ),
      );
    }
  }
}
