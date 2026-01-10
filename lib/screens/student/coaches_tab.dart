import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';

class CoachesTab extends StatefulWidget {
  const CoachesTab({super.key});

  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectionService _connectionService = ConnectionService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _connectingInstructors = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

void _showMessage(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: const Color(0xFF2A2A2A), // Dark background
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: const Color(0xFFD32F2F).withOpacity(0.5),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}


  Future<void> _requestConnection(String coachId, String coachName) async {
    if (_connectingInstructors.contains(coachId)) return;
    setState(() => _connectingInstructors.add(coachId));
    try {
      await _connectionService.requestInstructorConnection(coachId);
      _showMessage('Request sent to $coachName');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      setState(() => _connectingInstructors.remove(coachId));
    }
  }

  Future<void> _cancelRequest(String coachId, String coachName) async {
    setState(() => _connectingInstructors.add(coachId));
    try {
      await _connectionService.cancelInstructorRequest(coachId);
      _showMessage('Request cancelled for $coachName');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      setState(() => _connectingInstructors.remove(coachId));
    }
  }

  Future<void> _disconnect(String coachId, String coachName) async {
    if (_connectingInstructors.contains(coachId)) return;
    setState(() => _connectingInstructors.add(coachId));
    try {
      await _connectionService.getConnectedStudents(coachId);
      _showMessage('Disconnected from $coachName');
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      setState(() => _connectingInstructors.remove(coachId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Coaches',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [

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
                setState(() => _searchQuery = value.toLowerCase());
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
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

          // Instructor list from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'Instructor')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading instructors',
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
                        Icon(Icons.people_outline, size: 64, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No instructors found',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Filter instructors based on search query
                final allInstructors = snapshot.data!.docs;
                final filteredInstructors = allInstructors.where((doc) {
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

                if (filteredInstructors.isEmpty) {
                  return Center(
                    child: Text(
                      'No instructors match your search',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredInstructors.length,
                  itemBuilder: (context, index) {
                    final instructorData =
                        filteredInstructors[index].data() as Map<String, dynamic>;
                    return _buildCoachCard(
                      id: instructorData['uid'] ?? '',
                      name: '${instructorData['firstName'] ?? 'Unknown'} ${instructorData['lastName'] ?? ''}'.trim(),
                      email: instructorData['email'] ?? '',
                      photoUrl: instructorData['photoUrl'],
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

  Widget _buildCoachCard({
    required String id,
    required String name,
    required String email,
    String? photoUrl,
  }) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join()
        : '';
    final isConnecting = _connectingInstructors.contains(id);

    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            // Name / email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Shield Icon

            const SizedBox(width: 8),
            // Request/Status Button
            FutureBuilder<String?>(
              future: _connectionService.requestStatusWithInstructor(id),
              builder: (context, snapshot) {
                final status = snapshot.data;
                if (status == 'connected') {
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
                } else if (status == 'pending') {
                  return OutlinedButton(
                    onPressed: () => _cancelRequest(id, name),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      side: BorderSide.none,
                    ),
                    child: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Requested',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  );
                } else {
                  return OutlinedButton(
                    onPressed: () => _requestConnection(id, name),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      side: BorderSide.none,
                    ),
                    child: isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Request',
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
