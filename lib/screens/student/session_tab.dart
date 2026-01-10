import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../services/session_service.dart';
import '../../models/missed_shoot.dart';
import '../../models/photo_data.dart';
import '../../models/session_notes.dart';
import '../instructor/pistol_shooting_screen.dart';
import '../instructor/rifle_shooting_screen.dart';
import '../instructor/session_report_screen.dart';
import '../instructor/create_session_dialog.dart';
import 'share_session_dialog.dart';

class SessionTab extends StatefulWidget {
  const SessionTab({super.key});

  @override
  State<SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<SessionTab> {
  int _selectedTab = 0;
  String? _currentUserId;
  String? _currentUserName;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _coachKeys = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
        _currentUserName = user.displayName ?? 'Student';
      });
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd-MM-yyyy | HH:mm').format(date);
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return DateFormat('dd-MM-yyyy | HH:mm').format(now);
  }

  void _scrollToCoach(String coachName) {
    final key = _coachKeys[coachName];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = SessionService();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentUserName ?? 'Student',
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Created by me',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: _selectedTab == 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Created by Coach',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: _selectedTab == 1
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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

          Expanded(
            child: _selectedTab == 0
                ? _buildMySessionsList(sessionService)
                : _buildCoachSessionsList(),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: () async {
                if (_currentUserId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please log in to create a session'),
                      backgroundColor: Color(0xFF2A2A2A),
                    ),
                  );
                  return;
                }

                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => CreateSessionDialog(
                    studentId: _currentUserId!,
                    studentName: _currentUserName ?? 'Student',
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
            )
          : null,
    );
  }

  Widget _buildMySessionsList(SessionService sessionService) {
    if (_currentUserId == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: sessionService.getStudentSessions(_currentUserId!),
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

// ✅ COMPLETE FIX: Compact sidebar with better spacing
Widget _buildCoachSessionsList() {
  if (_currentUserId == null) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
    );
  }

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('training_sessions')
        .where('studentId', isEqualTo: _currentUserId)
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
                'No coach sessions yet',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sessions created by your coach will appear here',
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

      final allSessions = snapshot.data!.docs;
      final coachSessions = allSessions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final coachId = data['coachId'] as String?;
        return coachId != null && coachId != _currentUserId;
      }).toList();

      if (coachSessions.isEmpty) {
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
                'No coach sessions yet',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sessions created by your coach will appear here',
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

      // ✅ FIXED: Sort sessions by coach name alphabetically, then by date within each coach
      coachSessions.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        
        final aCoachName = (aData['coachName'] as String? ?? 'Unknown Coach').toLowerCase();
        final bCoachName = (bData['coachName'] as String? ?? 'Unknown Coach').toLowerCase();
        
        // First sort by coach name alphabetically
        final nameComparison = aCoachName.compareTo(bCoachName);
        if (nameComparison != 0) {
          return nameComparison;
        }
        
        // If same coach, sort by date (newest first)
        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      // ✅ Build map: coach initial -> first session index with that initial
      final Map<String, int> initialToFirstIndex = {};
      final List<GlobalKey> sessionKeys = [];
      
      for (int i = 0; i < coachSessions.length; i++) {
        sessionKeys.add(GlobalKey());
        
        final data = coachSessions[i].data() as Map<String, dynamic>;
        final coachName = data['coachName'] as String? ?? 'Unknown Coach';
        
        if (coachName.isNotEmpty) {
          final initial = coachName[0].toUpperCase();
          if (!initialToFirstIndex.containsKey(initial)) {
            initialToFirstIndex[initial] = i;
          }
        }
      }

      final sortedInitials = initialToFirstIndex.keys.toList()..sort();

      return Stack(
        children: [
          // ✅ Sessions list (now sorted alphabetically by coach name)
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            itemCount: coachSessions.length,
            itemBuilder: (context, index) {
              final sessionDoc = coachSessions[index];
              final session = sessionDoc.data() as Map<String, dynamic>;
              final sessionId = session['sessionId'] as String?;
              final sessionName = session['sessionName'] as String?;
              final eventName = session['eventName'] as String?;
              final createdAt = session['createdAt'] as Timestamp?;
              final shotsPerTarget = session['shotsPerTarget'] as int?;
              final coachName = session['coachName'] as String? ?? 'Unknown Coach';

              if (sessionId == null || eventName == null) {
                return const SizedBox.shrink();
              }

              // ✅ Show coach name header when coach changes
              final isFirstOfCoach = index == 0 || 
                (coachSessions[index - 1].data() as Map<String, dynamic>)['coachName'] != coachName;

              return Column(
                key: sessionKeys[index],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFirstOfCoach)
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
                                  coachName,
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
                            '${coachSessions.where((s) => (s.data() as Map<String, dynamic>)['coachName'] == coachName).length} sessions',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  _buildCoachSessionCard(
                    context,
                    sessionId: sessionId,
                    sessionName: sessionName ?? 'Unnamed Session',
                    eventName: eventName,
                    createdAt: createdAt,
                    shotsPerTarget: shotsPerTarget ?? 10,
                  ),
                ],
              );
            },
          ),

          // ✅ A-Z overlay (now matches sorted order)
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
                  final firstIndex = initialToFirstIndex[initial]!;
                  return GestureDetector(
                    onTap: () {
                      final key = sessionKeys[firstIndex];
                      if (key.currentContext != null) {
                        Scrollable.ensureVisible(
                          key.currentContext!,
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


Widget _buildCoachSessionCard(
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
      final sessionData = await sessionService.getSessionData(sessionId);

      if (sessionData != null && sessionData['hasShots'] == true) {
        //final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);
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
          studentName: _currentUserName ?? 'Student',
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
              photos: [],
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
      width: double.infinity, // ✅ FIXED: Force full width
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
                eventName.toLowerCase().contains('rifle') ? 'Rifle' : 'Pistol',
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
            child: SizedBox( // ✅ FIXED: Wrap in SizedBox with full width
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


  // [Rest of the _buildSessionCard method remains the same - keeping all edit/delete/share functionality]
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
              notesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            }

            final reportData = SessionReportData(
              sessionName: sessionName,
              studentName: _currentUserName ?? 'Student',
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
          }
        } else {
          final sessionData = await sessionService.getSessionData(sessionId);
          final List<PhotoData> photos = await sessionService.getSessionImages(sessionId);

          if (eventName.toLowerCase().contains('rifle')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RifleShootingScreen(
                  sessionId: sessionId,
                  sessionName: sessionName,
                  shotsPerTarget: shotsPerTarget,
                  studentName: _currentUserName ?? 'Student',
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
          } else if (eventName.toLowerCase().contains('pistol')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PistolShootingScreen(
                  sessionId: sessionId,
                  sessionName: sessionName,
                  shotsPerTarget: shotsPerTarget,
                  studentName: _currentUserName ?? 'Student',
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
                      InkWell(
                        onTap: () async {
                          final sessionService = SessionService();
                          final sessionData = await sessionService.getSessionData(sessionId);

                          final missedShotsData = sessionData?['missedShots'] as List<dynamic>?;
                          final missedShotsList = missedShotsData != null
                              ? missedShotsData
                                  .map((d) => MissedShot(
                                        shotNumber: d['shotNumber'] as int,
                                        feedback: Set<String>.from(d['feedback'] ?? []),
                                        shotTime: Duration(milliseconds: d['time'] as int? ?? 0),
                                      ))
                                  .toList()
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
                                    studentName: _currentUserName ?? 'Student',
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
                                    existingShots: allShots,
                                    existingMissedShots: missedShotsList,
                                    studentName: _currentUserName ?? 'Student',
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
                      const SizedBox(width: 4),
                      InkWell(
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
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () async {
                          final photos = await SessionService().getSessionImages(sessionId);

                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => ShareSessionDialog(
                                originalSessionId: sessionId,
                                photos: photos,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
