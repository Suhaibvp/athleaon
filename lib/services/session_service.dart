import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/photo_data.dart';
import '../models/attached_file.dart';
import 'session_sharing_service.dart';
class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new session
  Future<String> createSession({
    required String studentId,
    required String studentName,
    required String sessionName,
    required String eventName,
    required int shotsPerTarget,
  }) async {
    final coachId = _auth.currentUser!.uid;
    
    final coachDoc = await _firestore.collection('users').doc(coachId).get();
    final coachData = coachDoc.data()!;
    final coachName = '${coachData['firstName']} ${coachData['lastName']}';
    
    final sessionRef = _firestore.collection('training_sessions').doc();
    
    await sessionRef.set({
      'sessionId': sessionRef.id,
      'studentId': studentId,
      'studentName': studentName,
      'coachId': coachId,
      'coachName': coachName,
      'sessionName': sessionName,
      'eventName': eventName,
      'shotsPerTarget': shotsPerTarget,
      'totalShots': 0,
      'completedShots': 0,
      'totalScore': 0.0,
      'averageScore': 0.0,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': null,
      'shots': [],
      'hasShots': false,
    });
    
    return sessionRef.id;
  }

  // Save session shots to Firestore
Future<void> saveSessionShots({
  required String sessionId,
  required List<Map<String, dynamic>> shots,
  required double totalScore,
  required Duration totalTime,
  String? notes, // Keep for backwards compatibility
  List<Map<String, dynamic>>? notesList, // List of notes with timestamps
  List<Map<String, dynamic>>? shotGroups,
  List<Map<String, dynamic>>? missedShots,
  List<Map<String, dynamic>>? sightingShots, // NEW: Optional sighting shots
  double? sightingTotalScore, // NEW: Optional sighting score
}) async {
  try {
    final data = {
      'shots': shots,
      'totalScore': totalScore,
      'totalTime': totalTime.inMilliseconds,
      'notes': notes ?? '', // Latest note (backwards compatibility)
      'notesList': notesList ?? [], // All notes with timestamps
      'shotGroups': shotGroups ?? [],
      'missedShots': missedShots ?? [],
      'hasShots': true,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // NEW: Add sighting data only if present
    if (sightingShots != null && sightingShots.isNotEmpty) {
      data['sightingShots'] = sightingShots;
      data['hasSightingShots'] = true; // Flag to check if sighting data exists
    }
    
    if (sightingTotalScore != null) {
      data['sightingTotalScore'] = sightingTotalScore;
    }

    await FirebaseFirestore.instance
        .collection('training_sessions')
        .doc(sessionId)
        .set(data, SetOptions(merge: true));
    
    print('✅ Saved session with ${notesList?.length ?? 0} notes and ${sightingShots?.length ?? 0} sighting shots');
  } catch (e) {
    print('❌ Error saving shots: $e');
    rethrow;
  }
}


  // Check if session has shots
  Future<bool> hasShots(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('training_sessions')
          .doc(sessionId)
          .get();
      
      final data = doc.data();
      return data?['hasShots'] == true && 
             (data?['shots'] as List?)?.isNotEmpty == true;
    } catch (e) {
      print('Error checking shots: $e');
      return false;
    }
  }

  // Get session data
  Future<Map<String, dynamic>?> getSessionData(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('training_sessions')
          .doc(sessionId)
          .get();
      
      return doc.data();
    } catch (e) {
      print('Error getting session data: $e');
      return null;
    }
  }

  // Get sessions for a student
  Stream<QuerySnapshot> getStudentSessions(String studentId) {
    final currentCoachId = _auth.currentUser!.uid;
    
    return _firestore
        .collection('training_sessions')
        .where('studentId', isEqualTo: studentId)
        .where('coachId', isEqualTo: currentCoachId)
        .snapshots();
  }

  // Update session last updated time
  Future<void> updateSessionTime(String sessionId) async {
    await _firestore.collection('training_sessions').doc(sessionId).update({
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Delete session
  Future<void> deleteSession(String sessionId) async {
    await _firestore.collection('training_sessions').doc(sessionId).delete();
  }

  // ✅ UPDATED: Save session images as local paths (not byte arrays)
  Future<void> saveSessionImages({
    required String sessionId,
    required List<PhotoData> photos,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // Convert PhotoData to simple map with paths
      final photosData = photos.map((photo) => {
        'localPath': photo.localPath,
        'note': photo.note,
        'shotGroup': photo.shotGroup,
      }).toList();

      // Save all photos metadata in one go
      await _firestore
          .collection('training_sessions')
          .doc(sessionId)
          .update({
        'photos': photosData,
        'photoCount': photos.length,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Report progress
      if (onProgress != null) {
        onProgress(photos.length, photos.length);
      }
    } catch (e) {
      print('Error saving session images: $e');
      rethrow;
    }
  }

  // ✅ UPDATED: Get session images (returns paths, not bytes)
  Future<List<PhotoData>> getSessionImages(String sessionId) async {
    try {
      final doc = await _firestore
          .collection('training_sessions')
          .doc(sessionId)
          .get();

      final data = doc.data();
      if (data == null || !data.containsKey('photos')) {
        return [];
      }

      final photosData = data['photos'] as List<dynamic>;
      
      return photosData.map((photoMap) {
        return PhotoData(
          localPath: photoMap['localPath'] ?? '',
          note: photoMap['note'] ?? '',
          shotGroup: photoMap['shotGroup'] ?? 1,
        );
      }).toList();
    } catch (e) {
      print('Error getting session images: $e');
      return [];
    }
  }

  // In session_service.dart

// Save attached files to Firestore
Future<void> saveSessionFiles({
  required String sessionId,
  required List<AttachedFile> files,
}) async {
  try {
    final filesData = files.map((file) => file.toJson()).toList();
    
    await _firestore.collection('training_sessions').doc(sessionId).update({
      'attachedFiles': filesData,
    });
  } catch (e) {
    print('Error saving attached files: $e');
    throw Exception('Failed to save attached files: $e');
  }
}

// Get attached files from Firestore
Future<List<AttachedFile>> getSessionFiles(String sessionId) async {
  try {
    final doc = await _firestore.collection('training_sessions').doc(sessionId).get();
    
    if (!doc.exists) return [];
    
    final filesData = doc.data()?['attachedFiles'] as List<dynamic>?;
    if (filesData == null) return [];
    
    return filesData
        .map((fileJson) => AttachedFile.fromJson(fileJson as Map<String, dynamic>))
        .toList();
  } catch (e) {
    print('Error getting attached files: $e');
    return [];
  }
}
/// Auto-share with student after session completion
Future<void> autoShareWithStudent(String sessionId, String studentId) async {
  print('🔍 AUTO-SHARE START: sessionId=$sessionId, studentId=$studentId');
  
  try {
    final sessionData = await getSessionData(sessionId);
    print('🔍 Session data: ${sessionData != null ? 'EXISTS' : 'NULL'}');
    if (sessionData == null) {
      print('❌ Session data is NULL - cannot share');
      return;
    }
    
    print('🔍 hasShots check: ${sessionData['hasShots']}');
    if (sessionData['hasShots'] != true) {
      print('❌ hasShots is NOT true (${sessionData['hasShots']}) - skipping share');
      return;  // ← THIS IS LIKELY THE ISSUE
    }

    final photos = await getSessionImages(sessionId);
    print('🔍 Photos count: ${photos.length}');
    
    final coachId = FirebaseAuth.instance.currentUser!.uid;
    print('🔍 Coach ID: $coachId');

    print('🔄 Calling shareCoachSessionWithStudent...');
    await SessionSharingService().shareCoachSessionWithStudent(
      originalSessionId: sessionId,
      studentId: studentId,
      coachId: coachId,
      photos: photos,
    );

    print('✅ Auto-shared session with student');
  } catch (e) {
    print('❌ AUTO-SHARE FAILED: $e');
    print('❌ Stack trace: ${StackTrace.current}');
  }
}

/// Get all sessions for current user (including downloaded coach sessions)
Future<QuerySnapshot> getAllSessions() async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return await FirebaseFirestore.instance.collection('training_sessions').limit(0).get();
  
  return await FirebaseFirestore.instance
      .collection('training_sessions')
      .where('studentId', isEqualTo: currentUserId)
      .get();
}

/// Update session metadata (for coach sessions)
Future<void> updateSessionMetadata(String sessionId, Map<String, dynamic> metadata) async {
  await _firestore.collection('training_sessions').doc(sessionId).update(metadata);
}


}
