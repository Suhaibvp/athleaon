import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/session_service.dart';
import 'create_session_dialog.dart';
import 'pistol_shooting_screen.dart';
import 'rifle_shooting_screen.dart';


class StudentSessionListScreen extends StatelessWidget {
  final String studentName;
  final String studentId;

  const StudentSessionListScreen({
    super.key,
    required this.studentName,
    required this.studentId,
  });

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('dd-MM-yyyy / HH:mm').format(date);
  }

  String _getLatestUpdate(QuerySnapshot snapshot) {
    if (snapshot.docs.isEmpty) return '';
    
    Timestamp? latestTime;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lastUpdated = data['lastUpdated'] as Timestamp?;
      if (lastUpdated != null) {
        if (latestTime == null || lastUpdated.compareTo(latestTime) > 0) {
          latestTime = lastUpdated;
        }
      }
    }
    
    return latestTime != null ? _formatDateTime(latestTime) : '';
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
        title: StreamBuilder<QuerySnapshot>(
          stream: sessionService.getStudentSessions(studentId),
          builder: (context, snapshot) {
            final latestUpdate = snapshot.hasData ? _getLatestUpdate(snapshot.data!) : '';
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (latestUpdate.isNotEmpty)
                  Text(
                    latestUpdate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
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
              ),
            ),
          ),

          // Sessions list
// Sessions list
Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: sessionService.getStudentSessions(studentId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        // Show the actual error for debugging
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Retry
                  //setState(() {});
                },
                child: const Text('Retry'),
              ),
            ],
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
              const Text(
                'Create a new session using the + button',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      // Sort sessions by createdAt in the app (newest first)
      final sessions = snapshot.data!.docs.toList();
      sessions.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime); // Newest first
      });

return ListView.builder(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  itemCount: sessions.length,
  itemBuilder: (context, index) {
    final session = sessions[index].data() as Map<String, dynamic>;
    return _buildSessionCard(
      context,
      sessionId: session['sessionId'],
      sessionName: session['sessionName'] ?? 'Unnamed Session', // NEW
      eventName: session['eventName'],
      createdAt: session['createdAt'] as Timestamp?,
      shotsPerTarget: session['shotsPerTarget'],
    );
  },
);

    },
  ),
),

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => CreateSessionDialog(
              studentId: studentId,
              studentName: studentName,
            ),
          );

          if (result == true && context.mounted) {
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
    onTap: () {
      // Navigate to appropriate shooting screen based on event type
      if (eventName == 'Rifle 10m') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RifleShootingScreen(
              sessionId: sessionId,
              sessionName: sessionName,
              shotsPerTarget: shotsPerTarget,
            ),
          ),
        );
      } else if (eventName == 'Pistol 10m') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PistolShootingScreen(
              sessionId: sessionId,
              sessionName: sessionName,
              shotsPerTarget: shotsPerTarget,
            ),
          ),
        );
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Event badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              eventName == 'Rifle 10m' ? 'Rifle' : 'Pistol',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Session info
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

          // Action icons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                onPressed: () {
                  // TODO: Edit session
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                onPressed: () async {
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
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                onPressed: () {
                  // TODO: Share session
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}




}
