import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/connection_service.dart';
import 'student_session_list_screen.dart';
import 'create_student_dialog.dart';
import 'package:flutter/services.dart'; 
class HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToStudents;
  const HomeTab({super.key,
  this.onNavigateToStudents,});

  @override
  State<HomeTab> createState() => _HomeTabState();
}
class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ Show exit confirmation dialog
  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Exit App',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Would you like to exit from ShootMetrix?',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // ✅ No exit
            child: const Text(
              'No',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true); // ✅ Exit
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;

    // ✅ If user clicked Exit, close the app
    if (shouldExit) {
      await SystemNavigator.pop(); // Closes the entire app
    }

    return false; // ✅ Always return false to prevent default back behavior
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // ✅ Intercept back button
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          automaticallyImplyLeading: false, // ✅ Remove default back button
          title: const Text(
            'Home',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
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
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
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
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {},
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

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  tabs: const [
                    Tab(text: 'Created by user'),
                    Tab(text: 'Created by coach'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tab View Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudentList(createdBy: 'user'),
                  _buildStudentList(createdBy: 'coach'),
                ],
              ),
            ),

            // Bottom buttons section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => const CreateStudentDialog(),
                      );
                      
                      if (result == true && mounted) {
                        setState(() {});
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Create a student',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onNavigateToStudents,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Connect with Students',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


Widget _buildStudentList({required String createdBy}) {
  final currentCoachId = FirebaseAuth.instance.currentUser!.uid;

if (createdBy == 'coach') {
  // CREATED BY COACH TAB - Show coach-created students only
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('coach_students')
        .where('coachId', isEqualTo: currentCoachId)
        .snapshots(), // ✅ Removed .orderBy() to avoid index issue
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Text(
            'Error loading students: ${snapshot.error}',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No students created yet',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first student using the button below',
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

      // ✅ Sort documents in-memory by createdAt (newest first)
      final docs = snapshot.data!.docs.toList();
      docs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        
        final aTime = aData['createdAt'] as Timestamp?;
        final bTime = bData['createdAt'] as Timestamp?;
        
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final studentDoc = docs[index];
          final data = studentDoc.data() as Map<String, dynamic>;

          return _buildStudentCard(
            uid: studentDoc.id,
            name: data['fullName'] ?? 'No Name',
            email: data['preferredEvent'] ?? '',
            photoUrl: null,
            lastUpdated: _formatTimestamp(data['lastAccessed'] as Timestamp?), // ✅ Use lastAccessed
            isCoachCreated: true,
          );

        },
      );
    },
  );
}
 else {
    // CREATED BY USER TAB - Show connected students (real auth users)
    final connectionService = ConnectionService();
    
    return StreamBuilder<QuerySnapshot>(
      stream: connectionService.getConnectedStudents(currentCoachId),
      builder: (context, snapshot) {
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
                  Icons.people_outline,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No connected students',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onNavigateToStudents,
                  child: const Text(
                    'Connect with students',
                    style: TextStyle(color: Color(0xFFD32F2F)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final connection = snapshot.data!.docs[index];
            final studentId = connection['studentId'];

return FutureBuilder<Map<String, dynamic>?>(
  future: connectionService.getStudentData(studentId),
  builder: (context, studentSnapshot) {
    if (!studentSnapshot.hasData) {
      return const SizedBox();
    }

    final studentData = studentSnapshot.data!;
    final firstName = studentData['firstName'] ?? '';
    final lastName = studentData['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    // ✅ Get lastAccessed from connection document
    final connectionData = connection.data() as Map<String, dynamic>;
    final lastAccessed = connectionData['lastAccessed'] as Timestamp?;

    return _buildStudentCard(
      uid: studentId,
      name: fullName,
      email: studentData['email'] ?? '',
      photoUrl: studentData['photoUrl'],
      lastUpdated: _formatTimestamp(lastAccessed), // ✅ Use connection's lastAccessed
      isCoachCreated: false,
      connectionId: connection.id, // ✅ Pass connection document ID
    );
  },
);

          },
        );
      },
    );
  }
}


Widget _buildStudentCard({
  required String uid,
  required String name,
  required String email,
  String? photoUrl,
  String? lastUpdated,
  bool isCoachCreated = false,
  String? connectionId,
}) {
  return GestureDetector(
    onTap: () async {
      // Update lastAccessed timestamp when opening
      if (isCoachCreated) {
        await FirebaseFirestore.instance
            .collection('coach_students')
            .doc(uid)
            .update({'lastAccessed': FieldValue.serverTimestamp()});
      } else {
        if (connectionId != null) {
          await FirebaseFirestore.instance
              .collection('connections')
              .doc(connectionId)
              .update({'lastAccessed': FieldValue.serverTimestamp()});
        }
      }
      
      // Navigate to session list
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentSessionListScreen(
              studentName: name,
              studentId: uid,
            ),
          ),
        );
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Student name on the left
          Expanded(
            flex: 2,
            child: Text(
              name.isNotEmpty ? name : 'No Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Last updated section in the center-right
          if (lastUpdated != null)
            Expanded(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // "Last updated" label in red
                  Text(
                    'Last updated',
                    style: TextStyle(
                      color: const Color(0xFFD32F2F),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Datetime
                  Text(
                    lastUpdated,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            const Expanded(flex: 3, child: SizedBox()),

          // Action icons on the right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit icon
              IconButton(
                onPressed: () async {
                  if (isCoachCreated) {
                    // Open edit dialog for coach-created students
                    final studentDoc = await FirebaseFirestore.instance
                        .collection('coach_students')
                        .doc(uid)
                        .get();
                    
                    if (studentDoc.exists && mounted) {
                      final data = studentDoc.data()!;
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => CreateStudentDialog(
                          studentId: uid,
                          initialData: data,
                        ),
                      );
                      
                      if (result == true && mounted) {
                        setState(() {});
                      }
                    }
                  } else {
                    // Update lastAccessed and navigate
                    if (connectionId != null) {
                      await FirebaseFirestore.instance
                          .collection('connections')
                          .doc(connectionId)
                          .update({'lastAccessed': FieldValue.serverTimestamp()});
                    }
                    
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentSessionListScreen(
                            studentName: name,
                            studentId: uid,
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: Icon(
                  Icons.edit_outlined,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),

              const SizedBox(width: 4),

              // Delete/Disconnect icon
              IconButton(
                onPressed: () {
                  if (isCoachCreated) {
                    _showDeleteConfirmation(uid, name);
                  } else {
                    _showDisconnectConfirmation(connectionId ?? '', name);
                  }
                },
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}



  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Delete coach-created student
void _showDeleteConfirmation(String uid, String name) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Delete Student',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Are you sure you want to delete "$name"?\nThis will permanently remove this student and all their data.',
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _deleteCoachStudent(uid);
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFD32F2F)),
          ),
        ),
      ],
    ),
  );
}

// Disconnect user-created student
void _showDisconnectConfirmation(String uid, String name) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text(
        'Disconnect Student',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Are you sure you want to disconnect from "$name"?\nYou can reconnect later if needed.',
        style: TextStyle(color: Colors.white.withOpacity(0.8)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _disconnectStudent(uid);
          },
          child: const Text(
            'Disconnect',
            style: TextStyle(color: Color(0xFFD32F2F)),
          ),
        ),
      ],
    ),
  );
}

Future<void> _deleteCoachStudent(String uid) async {
  try {
    // Delete the coach-created student document
    await FirebaseFirestore.instance
        .collection('coach_students')
        .doc(uid)
        .delete();
    
    _showMessage('Student deleted successfully');
  } catch (e) {
    _showMessage('Error deleting student: $e');
  }
}

Future<void> _disconnectStudent(String uid) async {
  try {
    final currentCoachId = FirebaseAuth.instance.currentUser!.uid;
    
    // Delete the connection between coach and student
    final connectionsQuery = await FirebaseFirestore.instance
        .collection('connections')
        .where('coachId', isEqualTo: currentCoachId)
        .where('studentId', isEqualTo: uid)
        .get();
    
    for (var doc in connectionsQuery.docs) {
      await doc.reference.delete();
    }
    
    _showMessage('Student disconnected successfully');
  } catch (e) {
    _showMessage('Error disconnecting student: $e');
  }
}

String? _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return null;
  
  final date = timestamp.toDate();
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year;
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  
  return '$day-$month-$year | $hour:$minute';
}

}
