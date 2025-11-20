import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/session_service.dart';
import 'create_session_dialog.dart';
import 'pistol_shooting_screen.dart';
import 'rifle_shooting_screen.dart';
import 'session_report_screen.dart';
import 'dart:math' as math;
import '../../models/missed_shoot.dart';
import '../../models/photo_data.dart';
import '../../models/session_notes.dart';


class StudentSessionListScreen extends StatefulWidget {
  final String studentName;
  final String studentId;

  const StudentSessionListScreen({
    super.key,
    required this.studentName,
    required this.studentId,
  });

  @override
  State<StudentSessionListScreen> createState() => _StudentSessionListScreenState();
}

class _StudentSessionListScreenState extends State<StudentSessionListScreen> {
  int _selectedIndex = 0;
  int _selectedTab = 0; // ✅ Track which tab is selected (0 = Created by me, 1 = Created by Student)

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd-MM-yyyy | HH:mm').format(date);
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return DateFormat('dd-MM-yyyy | HH:mm').format(now);
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (index == 1) {
      // Students - already here
    } else if (index == 2) {
      // Settings
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();

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
          'Created Sessions',
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
                'assets/images/custom_icon.png',
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
          // Student name and current datetime row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getCurrentDateTime(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Interactive Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Tab 1: Created by me
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? const Color(0xFFD32F2F) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Created by me',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tab 2: Created by Student
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? const Color(0xFFD32F2F) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Created by Student',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 0
                ? _buildCoachSessions(sessionService) // Created by me
                : _buildStudentSessions(), // Created by Student
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => CreateSessionDialog(
              studentId: widget.studentId,
              studentName: widget.studentName,
            ),
          );

          if (result == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session created successfully'),
                backgroundColor: Color(0xFF2A2A2A),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFFD32F2F),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   backgroundColor: const Color(0xFF1A1A1A),
      //   selectedItemColor: const Color(0xFFD32F2F),
      //   unselectedItemColor: Colors.white.withOpacity(0.5),
      //   currentIndex: _selectedIndex,
      //   onTap: _onBottomNavTap,
      //   type: BottomNavigationBarType.fixed,
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.home),
      //       label: 'Home',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.search),
      //       label: 'Students',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.access_time),
      //       label: 'Settings',
      //     ),
      //   ],
      // ),
    );
  }

  // Coach-created sessions (Created by me)
  Widget _buildCoachSessions(SessionService sessionService) {
    return StreamBuilder<QuerySnapshot>(
      stream: sessionService.getStudentSessions(widget.studentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sessions yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a session using the + button',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final sessions = snapshot.data!.docs.toList();
        sessions.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index].data() as Map<String, dynamic>;
            return _buildSessionCard(
              context,
              sessionId: session['sessionId'],
              sessionName: session['sessionName'] ?? 'Unnamed Session',
              eventName: session['eventName'],
              createdAt: session['createdAt'] as Timestamp?,
              shotsPerTarget: session['shotsPerTarget'],
            );
          },
        );
      },
    );
  }

  // Student-created sessions (Created by Student) - Empty for now
  Widget _buildStudentSessions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No student sessions yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Student-created sessions will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context, {
    required String sessionId,
    required String sessionName,
    required String eventName,
    required Timestamp? createdAt,
    required int shotsPerTarget,
  }) {
    final dateStr = _formatDateTime(createdAt);

    return GestureDetector(
        onTap: () async {
      final sessionService = SessionService();
      final hasShots = await sessionService.hasShots(sessionId);

      if (hasShots) {
        final sessionData = await sessionService.getSessionData(sessionId);
        if (sessionData != null) {
          final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
          final allShots = List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);

          final missedShotsData = sessionData['missedShots'] as List<dynamic>?;
          final missedShotsList = missedShotsData != null
              ? missedShotsData.map((d) => MissedShot(
                    shotNumber: d['shotNumber'] as int,
                    feedback: Set<String>.from(d['feedback'] ?? []),
                    shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                  )).toList()
              : null;

          final List<ShotGroup> shotGroups = [];
          for (int i = 0; i < allShots.length; i += 10) {
            final endIndex = math.min(i + 10, allShots.length);
            final groupShotMaps = allShots.sublist(i, endIndex);
            final groupShots = groupShotMaps
                .map((shotData) => Shot(
                      position: Offset(shotData['x'] ?? 0.0, shotData['y'] ?? 0.0),
                      shotTime: Duration(milliseconds: shotData['time'] ?? 0),
                      isConfirmed: true,
                      feedback: Set<String>.from(shotData['feedback'] ?? []),
                      score: (shotData['score'] ?? 0.0).toDouble(),
                      ringNumber: shotData['ring'] ?? 0,
                    ))
                .toList();

            int? groupTimeMs;
            if (sessionData['shotGroups'] != null) {
              try {
                final matchingGroup = (sessionData['shotGroups'] as List).firstWhere(
                  (g) => g['groupNumber'] == (shotGroups.length + 1),
                  orElse: () => null,
                );
                groupTimeMs = matchingGroup != null ? matchingGroup['groupTime'] as int? : null;
              } catch (e) {
                groupTimeMs = null;
              }
            } else {
              groupTimeMs = null;
            }

            shotGroups.add(ShotGroup(
              groupNumber: shotGroups.length + 1,
              groupTime: Duration(milliseconds: groupTimeMs ?? (sessionData['totalTime'] ?? 0)),
              shots: groupShots,
            ));
          }
                    List<SessionNote>? notesList;
                      if (sessionData['notesList'] != null) {
                        notesList = (sessionData['notesList'] as List)
                            .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
                            .toList();
                        // Sort by timestamp
                        notesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      }
          final reportData = SessionReportData(
            sessionName: sessionName,
            studentName: widget.studentName,
            shots: allShots,
            totalScore: (sessionData['totalScore'] ?? 0.0).toDouble(),
            totalTime: Duration(milliseconds: sessionData['totalTime'] ?? 0),
            eventType: eventName.toLowerCase().contains('rifle') ? 'Rifle' : 'Pistol',
            notesList: notesList,
            notes: sessionData['notes'] ?? '',
            shotGroups: shotGroups.isNotEmpty ? shotGroups : null,
            missedShots: missedShotsList, // Include missed shots here
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionReportScreen(
                reportData: reportData,
                sessionId: sessionId,
                shotsPerTarget: shotsPerTarget,
                photos:photos,
              ),
            ),
          );
        }
      } else {
        if (eventName.toLowerCase().contains('rifle')) {
          final sessionData = await sessionService.getSessionData(sessionId);
          final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RifleShootingScreen(
                sessionId: sessionId,
                sessionName: sessionName,
                shotsPerTarget: shotsPerTarget,
                studentName: widget.studentName,
                existingMissedShots: sessionData != null
                    ? (sessionData['missedShots'] as List<dynamic>?)
                        ?.map((d) => MissedShot(
                              shotNumber: d['shotNumber'] as int,
                              feedback: Set<String>.from(d['feedback'] ?? []),
                              shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                            ))
                        .toList()
                    : null,
                    existingImages: photos,
                // You can also consider passing existing missed shots here if needed
              ),
            ),
          );
        } else if (eventName.toLowerCase().contains('pistol')) {
          final sessionData = await sessionService.getSessionData(sessionId);
          final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PistolShootingScreen(
                sessionId: sessionId,
                sessionName: sessionName,
                shotsPerTarget: shotsPerTarget,
                studentName: widget.studentName,
                // Pass existing missed shots as well when editing
                existingMissedShots: sessionData != null
                    ? (sessionData['missedShots'] as List<dynamic>?)
                        ?.map((d) => MissedShot(
                              shotNumber: d['shotNumber'] as int,
                              feedback: Set<String>.from(d['feedback'] ?? []),
                              shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                            ))
                        .toList()
                    : null,
                    existingImages: photos,
              ),
            ),
          );
        }
      }
    },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  (eventName.toLowerCase().contains('rifle')) ? 'Rifle' : 'Pistol',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
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
            // In the session card, find the Edit icon tap handler and replace it:
// ✅ IMPROVED: Edit button with larger touch area
                InkWell(
                  onTap: () async {
                    // Edit button - Open shooting screen with existing shots
                    final sessionService = SessionService();
                    final sessionData = await sessionService.getSessionData(sessionId);
                    
                    final missedShotsData = sessionData?['missedShots'] as List<dynamic>?;

                    final missedShotsList = missedShotsData != null
                        ? missedShotsData.map((d) => MissedShot(
                              shotNumber: d['shotNumber'] as int,
                              feedback: Set<String>.from(d['feedback'] ?? []),
                              shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                            )).toList()
                        : null;

                    if (sessionData != null && sessionData['hasShots'] == true) {
                      final allShots = List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);
                      final List<ShotGroup> shotGroups = [];
                      for (int i = 0; i < allShots.length; i += 10) {
                        final endIndex = math.min(i + 10, allShots.length);
                        final groupShotMaps = allShots.sublist(i, endIndex);
                        final groupShots = groupShotMaps
                            .map((shotData) => Shot(
                                  position: Offset(shotData['x'] ?? 0.0, shotData['y'] ?? 0.0),
                                  shotTime: Duration(milliseconds: shotData['time'] ?? 0),
                                  isConfirmed: true,
                                  feedback: Set<String>.from(shotData['feedback'] ?? []),
                                  score: (shotData['score'] ?? 0.0).toDouble(),
                                  ringNumber: shotData['ring'] ?? 0,
                                ))
                            .toList();

                        int? groupTimeMs;
                        if (sessionData['shotGroups'] != null) {
                          try {
                            final matchingGroup = (sessionData['shotGroups'] as List).firstWhere(
                              (g) => g['groupNumber'] == (shotGroups.length + 1),
                              orElse: () => null,
                            );
                            groupTimeMs = matchingGroup != null ? matchingGroup['groupTime'] as int? : null;
                          } catch (e) {
                            groupTimeMs = null;
                          }
                        } else {
                          groupTimeMs = null;
                        }

                        shotGroups.add(ShotGroup(
                          groupNumber: shotGroups.length + 1,
                          groupTime: Duration(milliseconds: groupTimeMs ?? (sessionData['totalTime'] ?? 0)),
                          shots: groupShots,
                        ));
                      }
                      final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
                      List<SessionNote>? notesList;
                      if (sessionData['notesList'] != null) {
                        notesList = (sessionData['notesList'] as List)
                            .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
                            .toList();
                        notesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                      }
                      
                      // Has shots - load them for editing
                      if (eventName.toLowerCase().contains('rifle')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RifleShootingScreen(
                              sessionId: sessionId,
                              sessionName: sessionName,
                              shotsPerTarget: shotsPerTarget,
                              existingShots: List<Map<String, dynamic>>.from(sessionData['shots'] ?? []),
                              existingMissedShots: missedShotsList,
                              studentName: widget.studentName,
                              existingImages: photos,
                              existingShotGroups: shotGroups,
                              existingNotes: notesList,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PistolShootingScreen(
                              sessionId: sessionId,
                              sessionName: sessionName,
                              shotsPerTarget: shotsPerTarget,
                              existingShots: List<Map<String, dynamic>>.from(sessionData['shots'] ?? []),
                              existingMissedShots: missedShotsList,
                              studentName: widget.studentName,
                              existingImages: photos,
                              existingShotGroups: shotGroups,
                              existingNotes: notesList,
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No shots to edit yet',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF2A2A2A),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(6), // ✅ Visual feedback
                  child: Container(
                    padding: const EdgeInsets.all(10), // ✅ Larger touch area (40x40 total)
                    child: Image.asset(
                      'assets/images/edit.png',
                      width: 20,
                      height: 20,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ),


                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A2A),
                              title: const Text('Delete Session', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Are you sure you want to delete this session?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Color(0xFFD32F2F))),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await SessionService().deleteSession(sessionId);
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
                              return Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.6), size: 20);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              return Icon(Icons.share_outlined, color: Colors.white.withOpacity(0.6), size: 20);
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
}
