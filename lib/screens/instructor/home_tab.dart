import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/connection_service.dart';
import 'student_session_list_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    // Refresh handled by StreamBuilder
                  },
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
// Tab Bar - Fixed to match design
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Container(
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A), // Background container
      borderRadius: BorderRadius.circular(8),
    ),
    child: TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        color: const Color(0xFFD32F2F), // Solid red for selected
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
                // Created by user tab
                _buildStudentList(createdBy: 'user'),
                // Created by coach tab
                _buildStudentList(createdBy: 'coach'),
              ],
            ),
          ),

          // Bottom buttons section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Create a student button
                OutlinedButton(
                  onPressed: () {
                    // TODO: Create student
                    _showMessage('Create student feature coming soon');
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

                // Connect with Students button
// Connect with Students button
// Connect with Students button
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
    );
  }

  Widget _buildStudentList({required String createdBy}) {
    final currentCoachId = FirebaseAuth.instance.currentUser!.uid;
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

        // Build list of connected students
        // TODO: Filter by createdBy when you add that field to connections
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

                return _buildStudentCard(
                  uid: studentId,
                  name: fullName,
                  email: studentData['email'] ?? '',
                  photoUrl: studentData['photoUrl'],
                  lastUpdated: index == 0 ? '12-08-2025 / 00:23' : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStudentCard({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
    String? lastUpdated,
  }) {
    return GestureDetector(
      onTap: () {
        // Navigate to session list screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentSessionListScreen(
              studentName: name,
              studentId: uid,
            ),
          ),
        );
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
            // Student name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'No Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lastUpdated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Last updated\n$lastUpdated',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Edit icon
// Edit icon
IconButton(
  onPressed: () {
    // TODO: Edit student
  },
  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
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
}
