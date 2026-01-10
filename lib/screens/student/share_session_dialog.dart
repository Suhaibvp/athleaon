import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';

class ShareSessionDialog extends StatefulWidget {
  final String originalSessionId;
  final List photos; // Not needed for sharing anymore, but keeping for compatibility
  
  const ShareSessionDialog({
    super.key,
    required this.originalSessionId,
    required this.photos,
  });
  
  @override
  State<ShareSessionDialog> createState() => _ShareSessionDialogState();
}

class _ShareSessionDialogState extends State<ShareSessionDialog> {
  final ConnectionService _connectionService = ConnectionService();
  final Map<String, bool> _sharingStatus = {}; // coachId -> isSharing
  Set<String> _alreadySharedCoaches = {};
  
  @override
  void initState() {
    super.initState();
    _loadSharedCoaches();
  }
  
Future<void> _loadSharedCoaches() async {
  try {
    print('🔍 Loading shared coaches for session: ${widget.originalSessionId}');
    
    final doc = await FirebaseFirestore.instance
        .collection('shared_sessions')
        .doc(widget.originalSessionId)
        .get();
    
    print('📄 Document exists: ${doc.exists}');
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      print('📄 Document data: $data');
      
      final sharedWith = List<String>.from(data['sharedWithCoaches'] ?? []);
      print('👥 Shared with coaches: $sharedWith');
      
      setState(() {
        _alreadySharedCoaches = sharedWith.toSet();
      });
    } else {
      print('⚠️ No shared_sessions document found for this session');
    }
  } catch (e, stackTrace) {
    print('❌ Error loading shared coaches: $e');
    print('📚 Stack trace: $stackTrace');
  }
}

  
Future<void> _shareWithCoach(String coachId, String coachName) async {
  setState(() {
    _sharingStatus[coachId] = true;
  });
  
  try {
    final currentUserId = _connectionService.currentUserId;
    
    print('🔍 Starting share process...');
    print('📍 Current User ID: $currentUserId');
    print('📍 Session ID: ${widget.originalSessionId}');
    print('📍 Coach ID: $coachId');
    
    // Get session data to extract student name and other info
    print('📥 Fetching session data...');
    final sessionDoc = await FirebaseFirestore.instance
        .collection('training_sessions')
        .doc(widget.originalSessionId)
        .get();
    
    if (!sessionDoc.exists) {
      print('❌ Session not found!');
      throw Exception('Session not found');
    }
    
    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    print('✅ Session data fetched: ${sessionData['sessionName']}');
    
    // Add to shared_sessions collection (track sharing)
    print('💾 Writing to shared_sessions collection...');
    await FirebaseFirestore.instance
        .collection('shared_sessions')
        .doc(widget.originalSessionId)
        .set({
      'sessionId': widget.originalSessionId,
      'studentId': currentUserId,
      'studentName': sessionData['studentName'] ?? 'Student',
      'sessionName': sessionData['sessionName'] ?? 'Unnamed Session',
      'eventName': sessionData['eventName'] ?? 'Unknown Event',
      'sharedWithCoaches': FieldValue.arrayUnion([coachId]),
      'createdAt': sessionData['createdAt'], // Add this for sorting
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('✅ Successfully wrote to Firebase!');
    
    // Verify the write
    final verifyDoc = await FirebaseFirestore.instance
        .collection('shared_sessions')
        .doc(widget.originalSessionId)
        .get();
    
    print('🔍 Verification: Document exists = ${verifyDoc.exists}');
    if (verifyDoc.exists) {
      print('📄 Document data: ${verifyDoc.data()}');
    }
    
    setState(() {
      _sharingStatus[coachId] = false;
      _alreadySharedCoaches.add(coachId);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Shared with $coachName successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e, stackTrace) {
    print('❌ Error sharing session: $e');
    print('📚 Stack trace: $stackTrace');
    
    setState(() {
      _sharingStatus[coachId] = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to share: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

  
  Future<void> _unshareWithCoach(String coachId, String coachName) async {
    try {
      await FirebaseFirestore.instance
          .collection('shared_sessions')
          .doc(widget.originalSessionId)
          .update({
        'sharedWithCoaches': FieldValue.arrayRemove([coachId]),
      });
      
      setState(() {
        _alreadySharedCoaches.remove(coachId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unshared with $coachName'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unshare: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select coaches to share with:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Connected coaches list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _connectionService.getConnectedInstructors(_connectionService.currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No connected coaches',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  
                  final connections = snapshot.data!.docs
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['status'] == 'connected';
                      })
                      .toList();
                  
                  if (connections.isEmpty) {
                    return Center(
                      child: Text(
                        'No connected coaches',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final connection = connections[index].data() as Map<String, dynamic>;
                      final coachId = connection['coachId'] ?? '';
                      
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _connectionService.getUserProfile(coachId),
                        builder: (context, coachSnapshot) {
                          final coachData = coachSnapshot.data;
                          final firstName = coachData?['firstName'] ?? 'Unknown';
                          final lastName = coachData?['lastName'] ?? '';
                          final fullName = '$firstName $lastName'.trim();
                          final photoUrl = coachData?['photoUrl'];
                          
                          final isSharing = _sharingStatus[coachId] ?? false;
                          final alreadyShared = _alreadySharedCoaches.contains(coachId);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: alreadyShared
                                  ? Border.all(color: Colors.green.withOpacity(0.5))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[700],
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (alreadyShared && !isSharing)
                                        Text(
                                          'Already shared',
                                          style: TextStyle(
                                            color: Colors.green.withOpacity(0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSharing)
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFD32F2F),
                                      ),
                                    ),
                                  )
                                else if (alreadyShared)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () => _unshareWithCoach(coachId, fullName),
                                      ),
                                    ],
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share,
                                      color: Color(0xFFD32F2F),
                                      size: 24,
                                    ),
                                    onPressed: () => _shareWithCoach(coachId, fullName),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
