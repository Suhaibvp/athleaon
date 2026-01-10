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
import '../../services/session_sharing_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session_download_manager.dart';
import 'events/25m_sports_pistol_page.dart';
import 'events/25m_rapid_fire_page.dart';
import 'events/50m_rifle_3p_page.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SessionDownloadManager _downloadManager = SessionDownloadManager();
  final Set<String> _downloadingSessionIds = {};


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
            barrierDismissible: false,
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
// Student-created sessions (Created by Student) - Show only on request
// Student-created sessions (Created by Student) - Show sessions shared by students
Widget _buildStudentSessions() {
  final _currentUserId = _auth.currentUser!.uid;


  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('shared_sessions')
        .where('sharedWithCoaches', arrayContains: _currentUserId)
        .snapshots(),
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
                Icons.school_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No shared sessions',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sessions will appear when students share them',
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

      final sharedSessions = snapshot.data!.docs;

      // Group by student name
      final Map<String, List<QueryDocumentSnapshot>> groupedByStudent = {};
      for (final doc in sharedSessions) {
        final data = doc.data() as Map<String, dynamic>;
        final studentName = data['studentName'] as String? ?? 'Unknown Student';
        
        if (!groupedByStudent.containsKey(studentName)) {
          groupedByStudent[studentName] = [];
        }
        groupedByStudent[studentName]!.add(doc);
      }

      final studentNames = groupedByStudent.keys.toList()..sort();

      // Get unique first letters
      final Map<String, String> initialToFirstStudent = {};
      for (final name in studentNames) {
        if (name.isNotEmpty) {
          final initial = name[0].toUpperCase();
          if (!initialToFirstStudent.containsKey(initial)) {
            initialToFirstStudent[initial] = name;
          }
        }
      }
      
      final sortedInitials = initialToFirstStudent.keys.toList()..sort();

      // Generate keys for scrolling
      final Map<String, GlobalKey> studentKeys = {};
      for (final name in studentNames) {
        studentKeys[name] = GlobalKey();
      }

      return Stack(
        children: [
          // Sessions list grouped by student
          ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            itemCount: studentNames.length,
            itemBuilder: (context, index) {
              final studentName = studentNames[index];
              final sessions = groupedByStudent[studentName]!;

              return Column(
                key: studentKeys[studentName],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student name header
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                studentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${sessions.length} ${sessions.length == 1 ? "session" : "sessions"}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sessions for this student
                  ...sessions.map((sharedDoc) {
                    final sharedData = sharedDoc.data() as Map<String, dynamic>;
                    final sessionId = sharedData['sessionId'] as String;
                    final sessionName = sharedData['sessionName'] as String? ?? 'Unnamed Session';
                    final eventName = sharedData['eventName'] as String? ?? 'Unknown Event';
                    final studentId = sharedData['studentId'] as String;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('training_sessions')
                          .doc(sessionId)
                          .get(),
                      builder: (context, sessionSnapshot) {
                        if (!sessionSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final sessionData = sessionSnapshot.data?.data() as Map<String, dynamic>?;
                        if (sessionData == null) {
                          return const SizedBox.shrink();
                        }

                        final createdAt = sessionData['createdAt'] as Timestamp?;
                        final shotsPerTarget = sessionData['shotsPerTarget'] as int? ?? 10;

                        return _buildSharedSessionCard(
                          context,
                          sessionId: sessionId,
                          sessionName: sessionName,
                          eventName: eventName,
                          createdAt: createdAt,
                          shotsPerTarget: shotsPerTarget,
                          studentName: studentName,
                          studentId: studentId,
                        );
                      },
                    );
                  }).toList(),
                ],
              );
            },
          ),

          // A-Z navigation for students
          if (sortedInitials.length > 1)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD32F2F).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sortedInitials.map((initial) {
                    final firstStudentName = initialToFirstStudent[initial]!;
                    return GestureDetector(
                      onTap: () {
                        final key = studentKeys[firstStudentName];
                        if (key?.currentContext != null) {
                          Scrollable.ensureVisible(
                            key!.currentContext!,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            alignment: 0.1,
                          );
                        }
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      );
    },
  );
}
Widget _buildSharedSessionCard(
  BuildContext context, {
  required String sessionId,
  required String sessionName,
  required String eventName,
  required Timestamp? createdAt,
  required int shotsPerTarget,
  required String studentName,
  required String studentId,
}) {
  final dateStr = _formatDateTime(createdAt);

  return GestureDetector(
    onTap: () async {
      final sessionService = SessionService();
      final sessionData = await sessionService.getSessionData(sessionId);

      if (sessionData != null && sessionData['hasShots'] == true) {
        // Navigate to report view
        final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
        final allShots = List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);

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
          notesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }

        final reportData = SessionReportData(
          sessionName: sessionName,
          studentName: studentName,
          shots: allShots,
          totalScore: (sessionData['totalScore'] ?? 0.0).toDouble(),
          totalTime: Duration(milliseconds: sessionData['totalTime'] ?? 0),
          eventType: eventName.toLowerCase().contains('rifle') ? 'Rifle' : 'Pistol',
          notesList: notesList,
          notes: sessionData['notes'] ?? '',
          shotGroups: shotGroups.isNotEmpty ? shotGroups : null,
          missedShots: missedShotsList,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionReportScreen(
              reportData: reportData,
              sessionId: sessionId,
              shotsPerTarget: shotsPerTarget,
              photos: photos,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This session has no data yet'),
            backgroundColor: Color(0xFF2A2A2A),
          ),
        );
      }
    },
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3), // Different color to show it's shared
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Event badge
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
                eventName.toLowerCase().contains('rifle') ? 'Rifle' : 'Pistol',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Shared badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.share, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Shared',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: SizedBox(
              width: double.infinity,
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
          ),
        ],
      ),
    ),
  );
}
  // Student-created sessions (Created by Student) - Empty for now
// Widget _buildStudentSessions() {
//   final sessionSharingService = SessionSharingService();
//   final currentCoachId = _auth.currentUser!.uid;
  
//   return StreamBuilder<QuerySnapshot>(
//     stream: sessionSharingService.getSharedSessionsForCoach(currentCoachId),
//     builder: (context, snapshot) {
//       if (snapshot.hasError) {
//         return Center(
//           child: Text('Error: ${snapshot.error}',
//             style: TextStyle(color: Colors.white.withOpacity(0.7)),
//           ),
//         );
//       }
      
//       if (snapshot.connectionState == ConnectionState.waiting) {
//         return const Center(
//           child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
//         );
//       }
      
//       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//         return Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(Icons.school_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
//               const SizedBox(height: 16),
//               Text('No shared sessions yet',
//                 style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
//               ),
//             ],
//           ),
//         );
//       }

//       final sharedSessions = snapshot.data!.docs.toList();
//       sharedSessions.sort((a, b) {
//         final aData = a.data() as Map<String, dynamic>;
//         final bData = b.data() as Map<String, dynamic>;
//         final aTime = aData['sharedAt'] as Timestamp?;
//         final bTime = bData['sharedAt'] as Timestamp?;
//         if (aTime == null && bTime == null) return 0;
//         if (aTime == null) return 1;
//         if (bTime == null) return -1;
//         return bTime.compareTo(aTime);
//       });

//       return ListView.builder(
//         padding: const EdgeInsets.symmetric(horizontal: 16),
//         itemCount: sharedSessions.length,
//         itemBuilder: (context, index) {
//           final session = sharedSessions[index].data() as Map<String, dynamic>;
          
//           // ✅ GET masterSessionId from the document
//           final masterSessionId = session['masterSessionId'] ?? '';
          
//           return _buildSharedSessionCard(
//             context,
//             masterSessionId: masterSessionId,  // ✅ PASS THIS
//             sessionName: session['sessionName'] ?? 'Unnamed Session',
//             eventName: session['eventName'] ?? '',
//             sharedAt: session['sharedAt'] as Timestamp?,
//             studentId: session['studentId'],
//             shotsPerTarget: session['shotsPerTarget'] ?? 10,
//             hasImages: session['hasImages'] ?? false,
//             imageCount: session['imageCount'] ?? 0,
//             isViewed: session['isViewed'] ?? false,
//             isDownloaded: session['isDownloaded'] ?? false,
//           );
//         },
//       );
//     },
//   );
// }



Future<void> _navigateToSession({
  required String masterSessionId,  // ✅ CHANGED
  required String sessionName,
  required String eventName,
  required int shotsPerTarget,
  required bool hasImages,
  required int imageCount,
  required String coachId,  // ✅ ADDED
}) async {
  // Mark as viewed
  await SessionSharingService().markAsViewed(coachId, masterSessionId);
  
  final sessionSharingService = SessionSharingService();
  
  // Get master session data
  final masterSessionDoc = await FirebaseFirestore.instance
      .collection('shared_sessions_master')
      .doc(masterSessionId)
      .get();
  
  if (!masterSessionDoc.exists) return;
  
  final sessionData = masterSessionDoc.data()!;
  
  // Load images from local cache
  List<PhotoData> photos = [];
  if (hasImages && imageCount > 0) {
    try {
      photos = await sessionSharingService.downloadSharedSessionImages(coachId, masterSessionId);
    } catch (e) {
      print('Error loading images: $e');
    }
  }
  
  final hasShots = sessionData['shots'] != null && (sessionData['shots'] as List).isNotEmpty;
  
  if (hasShots) {
    // Navigate to report screen
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

      shotGroups.add(ShotGroup(
        groupNumber: shotGroups.length + 1,
        groupTime: Duration(milliseconds: sessionData['totalTime'] ?? 0),
        shots: groupShots,
      ));
    }

    List<SessionNote>? notesList;
    if (sessionData['notesList'] != null) {
      notesList = (sessionData['notesList'] as List)
          .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
          .toList();
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
      shotGroups: shotGroups,
      missedShots: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionReportScreen(
          reportData: reportData,
          sessionId: masterSessionId,
          shotsPerTarget: shotsPerTarget,
          photos: photos,
        ),
      ),
    );
  } else {
    // Navigate to shooting screen (if needed)
    if (eventName.toLowerCase().contains('rifle')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RifleShootingScreen(
            sessionId: masterSessionId,
            sessionName: sessionName,
            shotsPerTarget: shotsPerTarget,
            studentName: widget.studentName,
            existingImages: photos,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PistolShootingScreen(
            sessionId: masterSessionId,
            sessionName: sessionName,
            shotsPerTarget: shotsPerTarget,
            studentName: widget.studentName,
            existingImages: photos,
          ),
        ),
      );
    }
  }
}

// Widget _buildSharedSessionCard(
//   BuildContext context, {
//   required String masterSessionId,  // ✅ CHANGED
//   required String sessionName,
//   required String eventName,
//   required Timestamp? sharedAt,
//   required String studentId,
//   required int shotsPerTarget,
//   required bool hasImages,
//   required int imageCount,
//   required bool isViewed,
//   required bool isDownloaded,  // ✅ ADDED
// }) {
//   final dateStr = _formatDateTime(sharedAt);
//   final isDownloading = _downloadingSessionIds.contains(masterSessionId);
//   final currentCoachId = _auth.currentUser!.uid;
  
//   return GestureDetector(
//     onTap: () async {
//       if (isDownloaded) {
//         await _navigateToSession(
//           masterSessionId: masterSessionId,
//           sessionName: sessionName,
//           eventName: eventName,
//           shotsPerTarget: shotsPerTarget,
//           hasImages: hasImages,
//           imageCount: imageCount,
//           coachId: currentCoachId,
//         );
//         return;
//       }
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please download the session first'),
//           backgroundColor: Color(0xFFD32F2F),
//           duration: Duration(seconds: 2),
//         ),
//       );
//     },
//     child: Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: isViewed ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(12),
//         border: isViewed ? null : Border.all(color: const Color(0xFFD32F2F), width: 1),
//       ),
//       child: Stack(
//         children: [
//           // Event badge
//           Positioned(
//             top: 0,
//             left: 0,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: const BoxDecoration(
//                 color: Color(0xFFD32F2F),
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(12),
//                   bottomRight: Radius.circular(12),
//                 ),
//               ),
//               child: Text(
//                 (eventName.toLowerCase().contains('rifle')) ? 'Rifle' : 'Pistol',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 11,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
          
//           // Status badge
//           Positioned(
//             top: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: isDownloaded 
//                     ? Colors.green.withOpacity(0.8)
//                     : Colors.orange.withOpacity(0.8),
//                 borderRadius: const BorderRadius.only(
//                   topRight: Radius.circular(12),
//                   bottomLeft: Radius.circular(6),
//                 ),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     isDownloaded ? Icons.check_circle : Icons.cloud_download,
//                     size: 12,
//                     color: Colors.white,
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     isDownloaded ? 'Downloaded' : 'Pending',
//                     style: const TextStyle(color: Colors.white, fontSize: 10),
//                   ),
//                 ],
//               ),
//             ),
//           ),
          
//           // Content
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(sessionName,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.w600,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 4),
//                       Text('Shared: $dateStr',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.5),
//                           fontSize: 12,
//                         ),
//                       ),
//                       if (hasImages)
//                         Text('$imageCount images',
//                           style: TextStyle(
//                             color: Colors.white.withOpacity(0.5),
//                             fontSize: 11,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
                
//                 // Actions
//                 Row(
//                   children: [
//                     // Download button
//                     if (!isDownloaded && hasImages)
//                       GestureDetector(
//                         onTap: isDownloading ? null : () async {
//                           setState(() {
//                             _downloadingSessionIds.add(masterSessionId);
//                           });
//                           try {
//                             final photos = await SessionSharingService()
//                                 .downloadSharedSessionImages(currentCoachId, masterSessionId);
                            
//                             await _downloadManager.markAsDownloaded(masterSessionId);
                            
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text('Downloaded successfully'),
//                                 backgroundColor: Colors.green,
//                               ),
//                             );
//                           } catch (e) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text('Download failed: $e'),
//                                 backgroundColor: Colors.red,
//                               ),
//                             );
//                           } finally {
//                             setState(() {
//                               _downloadingSessionIds.remove(masterSessionId);
//                             });
//                           }
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.all(8),
//                           child: isDownloading
//                               ? const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(
//                                     strokeWidth: 2,
//                                     valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                                   ),
//                                 )
//                               : const Icon(
//                                   Icons.download,
//                                   color: Colors.green,
//                                   size: 20,
//                                 ),
//                         ),
//                       ),
                    
//                     const SizedBox(width: 8),
                    
//                     // Delete button
//                     GestureDetector(
//                       onTap: () async {
//                         final confirm = await showDialog<bool>(
//                           context: context,
//                           builder: (context) => AlertDialog(
//                             backgroundColor: const Color(0xFF2A2A2A),
//                             title: const Text('Delete Session', 
//                                 style: TextStyle(color: Colors.white)),
//                             content: const Text(
//                               'Remove this session? Local data will be deleted.',
//                               style: TextStyle(color: Colors.white70),
//                             ),
//                             actions: [
//                               TextButton(
//                                 onPressed: () => Navigator.pop(context, false),
//                                 child: const Text('Cancel', 
//                                     style: TextStyle(color: Colors.grey)),
//                               ),
//                               TextButton(
//                                 onPressed: () => Navigator.pop(context, true),
//                                 child: const Text('Delete', 
//                                     style: TextStyle(color: Color(0xFFD32F2F))),
//                               ),
//                             ],
//                           ),
//                         );

//                         if (confirm == true) {
//                           await _downloadManager.deleteLocalImages(masterSessionId);
//                           await _downloadManager.clearLocalCache(masterSessionId);
//                           await SessionSharingService().deleteCoachSession(currentCoachId, masterSessionId);
//                         }
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(8),
//                         child: const Icon(
//                           Icons.delete_outline,
//                           color: Color(0xFFD32F2F),
//                           size: 20,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

String _getEventBadge(String eventName) {
  final lowerEvent = eventName.toLowerCase();
  
  // Check for specific events
  if (lowerEvent == '25m sports pistol') {
    return '25m Sports Pistol';
  }
  
  if (lowerEvent == '25m rapid fire') {
    return '25m Rapid Fire';
  }
  
  if (lowerEvent == '50m rifle 3p') {
    return '50m Rifle 3P';
  }
  
  // Default events (Pistol = 10m Pistol, Rifle = 10m Rifle)
  if (lowerEvent.contains('rifle')) {
    return '10m Rifle';
  }
  
  if (lowerEvent.contains('pistol')) {
    return '10m Pistol';
  }
  
  // Fallback - return the original name
  return eventName;
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
 final eventCategory = _getEventBadge(eventName);
  return GestureDetector(
    onTap: () async {
      final sessionService = SessionService();
      final hasShots = await sessionService.hasShots(sessionId);
      if (eventName == '25m Sports Pistol') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SportsPistolPage(
              studentId: widget.studentId,
              studentName: widget.studentName,
              sessionId: sessionId,
              sessionName: sessionName,
              shotsPerTarget:shotsPerTarget,
            ),
          ),
        );
        return;
      }
      if (eventName == '25m Rapid Fire') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RapidFirePage(
              studentId: widget.studentId,
              studentName: widget.studentName,
              sessionId: sessionId,
              sessionName: sessionName,
              shotsPerTarget:shotsPerTarget,
            ),
          ),
        );
        return;
      }
      if (eventName == '50m Rifle 3P') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Rifle3PPage(
              studentId: widget.studentId,
              studentName: widget.studentName,
              sessionId: sessionId,
              sessionName: sessionName,
              shotsPerTarget:shotsPerTarget,
            ),
          ),
        );
        return;
      }
      if (hasShots) {
        final sessionData = await sessionService.getSessionData(sessionId);
        if (sessionData != null) {
          final List<PhotoData> photos =
              await sessionService.getSessionImages(sessionId);
          final allShots =
              List<Map<String, dynamic>>.from(sessionData['shots'] ?? []);
          
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

          // NEW: Load sighting shots
          final sightingShots = sessionData['sightingShots'] as List<dynamic>?;
          final sightingData = sightingShots != null
              ? List<Map<String, dynamic>>.from(sightingShots)
              : null;
          final sightingTotalScore =
              (sessionData['sightingTotalScore'] as num?)?.toDouble();

          final List<ShotGroup> shotGroups = [];
          for (int i = 0; i < allShots.length; i += 10) {
            final endIndex = math.min(i + 10, allShots.length);
            final groupShotMaps = allShots.sublist(i, endIndex);
            final groupShots = groupShotMaps.map((shotData) {
              return Shot(
                position: Offset(shotData['x'] ?? 0.0, shotData['y'] ?? 0.0),
                shotTime: Duration(milliseconds: shotData['time'] ?? 0),
                isConfirmed: true,
                feedback: Set<String>.from(shotData['feedback'] ?? []),
                score: (shotData['score'] ?? 0.0).toDouble(),
                ringNumber: shotData['ring'] ?? 0,
              );
            }).toList();

            int? groupTimeMs;
            if (sessionData['shotGroups'] != null) {
              try {
                final matchingGroup = (sessionData['shotGroups'] as List)
                    .firstWhere(
                      (g) => g['groupNumber'] == shotGroups.length + 1,
                      orElse: () => null,
                    );
                groupTimeMs = matchingGroup != null
                    ? matchingGroup['groupTime'] as int?
                    : null;
              } catch (e) {
                groupTimeMs = null;
              }
            }

            shotGroups.add(ShotGroup(
              groupNumber: shotGroups.length + 1,
              groupTime: Duration(
                  milliseconds: groupTimeMs ?? sessionData['totalTime'] ?? 0),
              shots: groupShots,
            ));
          }

          List<SessionNote>? notesList;
          if (sessionData['notesList'] != null) {
            notesList = (sessionData['notesList'] as List)
                .map((n) => SessionNote.fromJson(n as Map<String, dynamic>))
                .toList();
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
            missedShots: missedShotsList,
            sightingShots: sightingData, // NEW: Pass sighting data
            sightingTotalScore: sightingTotalScore, // NEW: Pass sighting score
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionReportScreen(
                reportData: reportData,
                sessionId: sessionId,
                shotsPerTarget: shotsPerTarget,
                photos: photos,
              ),
            ),
          );
        }
      } else {
        // No shots - open shooting screen
        if (eventName.toLowerCase().contains('rifle')) {
          final sessionData = await sessionService.getSessionData(sessionId);
          final List<PhotoData> photos =
              await sessionService.getSessionImages(sessionId);
          
          // NEW: Load sighting shots for editing
          final sightingShots = sessionData?['sightingShots'] as List<dynamic>?;
          final existingSightingShots = sightingShots != null
              ? List<Map<String, dynamic>>.from(sightingShots)
              : null;

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
                              shotTime:
                                  Duration(milliseconds: d['time'] as int? ?? 0),
                            ))
                        .toList()
                    : null,
                existingImages: photos,
                existingSightingShots: existingSightingShots, // NEW
              ),
            ),
          );
        } else if (eventName.toLowerCase().contains('pistol')) {
          final sessionData = await sessionService.getSessionData(sessionId);
          final List<PhotoData> photos =
              await sessionService.getSessionImages(sessionId);
          
          // NEW: Load sighting shots for editing
          final sightingShots = sessionData?['sightingShots'] as List<dynamic>?;
          final existingSightingShots = sightingShots != null
              ? List<Map<String, dynamic>>.from(sightingShots)
              : null;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PistolShootingScreen(
                sessionId: sessionId,
                sessionName: sessionName,
                shotsPerTarget: shotsPerTarget,
                studentName: widget.studentName,
                existingMissedShots: sessionData != null
                    ? (sessionData['missedShots'] as List<dynamic>?)
                        ?.map((d) => MissedShot(
                              shotNumber: d['shotNumber'] as int,
                              feedback: Set<String>.from(d['feedback'] ?? []),
                              shotTime:
                                  Duration(milliseconds: d['time'] as int? ?? 0),
                            ))
                        .toList()
                    : null,
                existingImages: photos,
                existingSightingShots: existingSightingShots, // NEW
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
                eventCategory,
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
                    // EDIT BUTTON
                    InkWell(
                      onTap: () async {
                        final sessionService = SessionService();
                        final sessionData =
                            await sessionService.getSessionData(sessionId);

                        final missedShotsData =
                            sessionData?['missedShots'] as List<dynamic>?;
                        final missedShotsList = missedShotsData != null
                            ? missedShotsData
                                .map((d) => MissedShot(
                                      shotNumber: d['shotNumber'] as int,
                                      feedback:
                                          Set<String>.from(d['feedback'] ?? []),
                                      shotTime: Duration(
                                          milliseconds: d['time'] as int? ?? 0),
                                    ))
                                .toList()
                            : null;

                        if (sessionData != null && sessionData['hasShots'] == true) {
                          final allShots = List<Map<String, dynamic>>.from(
                              sessionData['shots'] ?? []);
                          
                          // NEW: Load sighting shots
                          final sightingShots =
                              sessionData['sightingShots'] as List<dynamic>?;
                          final existingSightingShots = sightingShots != null
                              ? List<Map<String, dynamic>>.from(sightingShots)
                              : null;

                          final List<ShotGroup> shotGroups = [];
                          for (int i = 0; i < allShots.length; i += 10) {
                            final endIndex = math.min(i + 10, allShots.length);
                            final groupShotMaps = allShots.sublist(i, endIndex);
                            final groupShots = groupShotMaps.map((shotData) {
                              return Shot(
                                position: Offset(
                                    shotData['x'] ?? 0.0, shotData['y'] ?? 0.0),
                                shotTime:
                                    Duration(milliseconds: shotData['time'] ?? 0),
                                isConfirmed: true,
                                feedback:
                                    Set<String>.from(shotData['feedback'] ?? []),
                                score: (shotData['score'] ?? 0.0).toDouble(),
                                ringNumber: shotData['ring'] ?? 0,
                              );
                            }).toList();

                            int? groupTimeMs;
                            if (sessionData['shotGroups'] != null) {
                              try {
                                final matchingGroup =
                                    (sessionData['shotGroups'] as List)
                                        .firstWhere(
                                          (g) =>
                                              g['groupNumber'] ==
                                              shotGroups.length + 1,
                                          orElse: () => null,
                                        );
                                groupTimeMs = matchingGroup != null
                                    ? matchingGroup['groupTime'] as int?
                                    : null;
                              } catch (e) {
                                groupTimeMs = null;
                              }
                            }

                            shotGroups.add(ShotGroup(
                              groupNumber: shotGroups.length + 1,
                              groupTime: Duration(
                                  milliseconds: groupTimeMs ??
                                      sessionData['totalTime'] ??
                                      0),
                              shots: groupShots,
                            ));
                          }

                          final List<PhotoData> photos =
                              await sessionService.getSessionImages(sessionId);

                          List<SessionNote>? notesList;
                          if (sessionData['notesList'] != null) {
                            notesList = (sessionData['notesList'] as List)
                                .map((n) =>
                                    SessionNote.fromJson(n as Map<String, dynamic>))
                                .toList();
                            notesList.sort(
                                (a, b) => a.timestamp.compareTo(b.timestamp));
                          }

                          if (eventName.toLowerCase().contains('rifle')) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RifleShootingScreen(
                                  sessionId: sessionId,
                                  sessionName: sessionName,
                                  shotsPerTarget: shotsPerTarget,
                                  existingShots: allShots,
                                  existingMissedShots: missedShotsList,
                                  studentName: widget.studentName,
                                  existingImages: photos,
                                  existingShotGroups: shotGroups,
                                  existingNotes: notesList,
                                  existingSightingShots: existingSightingShots, // NEW
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
                                  existingShots: allShots,
                                  existingMissedShots: missedShotsList,
                                  studentName: widget.studentName,
                                  existingImages: photos,
                                  existingShotGroups: shotGroups,
                                  existingNotes: notesList,
                                  existingSightingShots: existingSightingShots, // NEW
                                ),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No shots to edit yet'),
                              // style: TextStyle(color: Colors.white),
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
                            content: const Text(
                                'Are you sure you want to delete this session?',
                                style: TextStyle(color: Colors.white70)),
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

}
