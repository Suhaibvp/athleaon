import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';
import 'student_description_screen.dart';
import '../../widgets/shooting_feedback_icons.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionService _connectionService = ConnectionService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Handle accepting a student's request (coach side)
  Future<void> _acceptRequest(String connectionDocId, String studentName) async {
    try {
      await _connectionService.acceptStudentRequest(connectionDocId);
      _showMessage('Connected with $studentName');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  // Handle denying a student's request (coach side)
  Future<void> _denyRequest(String connectionDocId, String studentName) async {
    try {
      await _connectionService.denyStudentRequest(connectionDocId);
      _showMessage('Request denied for $studentName');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

void _showMessage(String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,  // ✅ White text for readability
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isError 
          ? Colors.red.shade700      // ✅ Red for errors
          : Colors.green.shade700,   // ✅ Green for success
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final currentCoachId = _connectionService.currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Students',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShootingFeedbackIcons.buildAppIcon(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.5),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Pending Student Requests Section (coach can approve/deny)
          StreamBuilder<QuerySnapshot>(
            stream: _connectionService.getPendingRequestsForCoach(currentCoachId),
            builder: (context, reqSnapshot) {
              if (!reqSnapshot.hasData || reqSnapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              final requests = reqSnapshot.data!.docs;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: Colors.yellow[700]!.withOpacity(0.13),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    leading: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Icon(Icons.person_add_alt, color: Colors.orange[800]),
                        if (requests.length > 0)
                          CircleAvatar(
                            backgroundColor: Colors.orange,
                            radius: 8,
                            child: Text(
                              requests.length.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    title: const Text('Pending Requests', style: TextStyle(color: Colors.white)),
                    children: requests.map((doc) {
                      final request = doc.data() as Map<String, dynamic>;
                      final studentId = request['studentId'] ?? '';
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _connectionService.getUserProfile(studentId),
                        builder: (context, userSnapshot) {
                          final userData = userSnapshot.data;
                          final firstName = userData?['firstName'] ?? 'Unknown';
                          final lastName = userData?['lastName'] ?? '';
                          final fullName = ('$firstName $lastName').trim();
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(fullName, style: const TextStyle(color: Colors.white)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      _acceptRequest(doc.id, fullName),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green),
                                  child: const Text('Accept'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () =>
                                      _denyRequest(doc.id, fullName),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: const Text('Deny'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // List students and show Connect/Connected button as coach
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'Student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading students',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD32F2F),
                    ),
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
                          'No students found',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter students based on search query
                final allStudents = snapshot.data!.docs;
                final filteredStudents = allStudents.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final firstName = (data['firstName'] ?? '').toString().toLowerCase();
                  final lastName = (data['lastName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final fullName = '$firstName $lastName';
                  return fullName.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      firstName.contains(_searchQuery) ||
                      lastName.contains(_searchQuery);
                }).toList();

                if (filteredStudents.isEmpty) {
                  return Center(
                    child: Text(
                      'No students match your search',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final studentData =
                        filteredStudents[index].data() as Map<String, dynamic>;
                    return _buildStudentCard(
                      uid: studentData['uid'] ?? '',
                      firstName: studentData['firstName'] ?? 'Unknown',
                      lastName: studentData['lastName'] ?? '',
                      email: studentData['email'] ?? '',
                      photoUrl: studentData['photoUrl'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String? photoUrl,
  }) {
    final fullName = '$firstName $lastName'.trim();
    final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDescriptionScreen(
              studentId: uid,
              studentName: fullName,
              studentEmail: email,
              photoUrl: photoUrl,
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
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[700],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Student info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : 'No Name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0012', // TODO: Get actual student ID
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Shield icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            // Connect/Connected button (instant, coach->student)
            FutureBuilder<bool>(
              future: _connectionService.isConnectedWithStudent(uid),
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? false;
                if (isConnected) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                } else {
                  return OutlinedButton(
                    onPressed: () async {
                      try {
                        await _connectionService.connectWithStudent(uid);
                        _showMessage('Connected with $fullName');
                        setState(() {});
                      } catch (e) {
                        _showMessage(e.toString());
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      side: BorderSide.none,
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
