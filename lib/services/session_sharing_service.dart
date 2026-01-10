import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/photo_data.dart';
import 'session_file_service.dart';
import 'session_service.dart';
import 'dart:io';
import 'image_compression_helper.dart';
import 'package:path_provider/path_provider.dart'; 
import 'dart:typed_data';

class SessionSharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionStorageService _storageService = SessionStorageService();

  /// Share session with coach (uses centralized master session)
  Future<void> shareSessionWithCoach({
    required String originalSessionId,
    required String coachId,
    required String studentId,
    required List<PhotoData> photos,
    Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('Loading session data...');

      // Get original session data
      final sessionService = SessionService();
      final sessionData = await sessionService.getSessionData(originalSessionId);

      if (sessionData == null) {
        throw Exception('Session not found');
      }

      // Check if master session already exists for this original session
      final masterSessionQuery = await _firestore
          .collection('shared_sessions_master')
          .where('originalSessionId', isEqualTo: originalSessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      String masterSessionId;

      if (masterSessionQuery.docs.isNotEmpty) {
        // Master session exists - just add coach to sharedCoaches list
        masterSessionId = masterSessionQuery.docs.first.id;
        onProgress?.call('Adding coach to existing shared session...');

        await _firestore
            .collection('shared_sessions_master')
            .doc(masterSessionId)
            .update({
          'sharedCoaches': FieldValue.arrayUnion([coachId]),
        });

        print('✅ Added coach to existing master session: $masterSessionId');
      } else {
        // Create new master session with images
        onProgress?.call('Creating shared session...');
        masterSessionId = 'shared_${DateTime.now().millisecondsSinceEpoch}_$studentId';

        List<String> chunkIds = [];
        if (photos.isNotEmpty) {
          onProgress?.call('Uploading images (${photos.length} photos)...');
          chunkIds = await _storageService.uploadSharedSessionImages(
            sharedSessionId: masterSessionId,
            photos: photos,
            onProgress: (current, total) {
              onProgress?.call('Uploading image $current of $total...');
            },
          );
        }

        // Create master session document
        await _firestore.collection('shared_sessions_master').doc(masterSessionId).set({
          'studentId': studentId,
          'originalSessionId': originalSessionId,
          'sessionName': sessionData['sessionName'] ?? 'Unnamed Session',
          'eventName': sessionData['eventName'] ?? '',
          'shots': sessionData['shots'] ?? [],
          'totalScore': sessionData['totalScore'] ?? 0.0,
          'totalTime': sessionData['totalTime'] ?? 0,
          'shotsPerTarget': sessionData['shotsPerTarget'] ?? 10,
          'notesList': sessionData['notesList'] ?? [],
          'notes': sessionData['notes'] ?? '',
          'shotGroups': sessionData['shotGroups'] ?? [],
          'hasImages': photos.isNotEmpty,
          'imageCount': photos.length,
          'chunkIds': chunkIds,
          'sharedAt': FieldValue.serverTimestamp(),
          'sharedCoaches': [coachId],
          'downloadedCoaches': [],
          'chunksDeleted': false,
        });

        print('✅ Created master session: $masterSessionId');
      }

      // Create individual coach tracking document
      await _firestore
          .collection('coach_shared_sessions')
          .doc('${coachId}_$masterSessionId')
          .set({
        'coachId': coachId,
        'masterSessionId': masterSessionId,
        'studentId': studentId,
        'sessionName': sessionData['sessionName'] ?? 'Unnamed Session',
        'eventName': sessionData['eventName'] ?? '',
        'sharedAt': FieldValue.serverTimestamp(),
        'isDownloaded': false,
        'isViewed': false,
        'hasImages': photos.isNotEmpty,
        'imageCount': photos.length,
        'shotsPerTarget': sessionData['shotsPerTarget'] ?? 10,
      });

      onProgress?.call('Shared successfully!');
    } catch (e) {
      print('❌ Error sharing session: $e');
      rethrow;
    }
  }

  /// Mark session as downloaded by coach
  Future<void> markAsDownloaded(String coachId, String masterSessionId) async {
    try {
      // Update coach tracking
      await _firestore
          .collection('coach_shared_sessions')
          .doc('${coachId}_$masterSessionId')
          .update({'isDownloaded': true});

      // Add coach to downloadedCoaches array
      await _firestore
          .collection('shared_sessions_master')
          .doc(masterSessionId)
          .update({
        'downloadedCoaches': FieldValue.arrayUnion([coachId]),
      });

      // Check if all coaches have downloaded
      await _checkAndCleanupChunks(masterSessionId);

      print('✅ Marked as downloaded for coach: $coachId');
    } catch (e) {
      print('❌ Error marking as downloaded: $e');
      rethrow;
    }
  }

  /// Check if all coaches downloaded, then delete Firestore chunks
  Future<void> _checkAndCleanupChunks(String masterSessionId) async {
    try {
      final masterDoc = await _firestore
          .collection('shared_sessions_master')
          .doc(masterSessionId)
          .get();

      if (!masterDoc.exists) return;

      final data = masterDoc.data()!;
      final sharedCoaches = List<String>.from(data['sharedCoaches'] ?? []);
      final downloadedCoaches = List<String>.from(data['downloadedCoaches'] ?? []);
      final chunksDeleted = data['chunksDeleted'] ?? false;

      // If all coaches downloaded and chunks not yet deleted
      if (!chunksDeleted && sharedCoaches.length == downloadedCoaches.length) {
        print('🗑️ All coaches downloaded - deleting Firestore chunks for $masterSessionId');

        // Delete chunks from Firestore
        final chunkIds = List<String>.from(data['chunkIds'] ?? []);
        WriteBatch batch = _firestore.batch();
        int count = 0;

        for (final chunkId in chunkIds) {
          batch.delete(_firestore.collection('shared_image_chunks').doc(chunkId));
          count++;
          if (count % 500 == 0) {
            await batch.commit();
            batch = _firestore.batch();
          }
        }

        if (count % 500 != 0) {
          await batch.commit();
        }

        // Mark as deleted
        await _firestore
            .collection('shared_sessions_master')
            .doc(masterSessionId)
            .update({
          'chunksDeleted': true,
          'chunkIds': [], // Clear chunk IDs
        });

        print('✅ Deleted ${chunkIds.length} Firestore chunks - storage freed!');
      }
    } catch (e) {
      print('❌ Error in cleanup: $e');
    }
  }

  /// Mark as viewed
  Future<void> markAsViewed(String coachId, String masterSessionId) async {
    try {
      await _firestore
          .collection('coach_shared_sessions')
          .doc('${coachId}_$masterSessionId')
          .update({'isViewed': true});
    } catch (e) {
      print('❌ Error marking as viewed: $e');
    }
  }

  /// Get shared sessions for coach
  Stream<QuerySnapshot> getSharedSessionsForCoach(String coachId) {
    return _firestore
        .collection('coach_shared_sessions')
        .where('coachId', isEqualTo: coachId)
        .snapshots();
  }
/// Download coach session images for student - ✅ CORRECT VERSION
// Future<List<PhotoData>> downloadCoachSessionImages(String masterSessionId) async {
//   try {
//     // ✅ Use YOUR existing SessionStorageService method (handles chunks correctly)
//     final rawPhotos = await _storageService.downloadCoachSessionImages(masterSessionId);  // ← NEW METHOD NEEDED IN SessionStorageService
    
//     print('📥 Downloaded ${rawPhotos.length} raw photos');
    
//     // Convert to PhotoData and save locally
//     final List<PhotoData> photoDataList = [];
//     final sessionDir = Directory('${(await getApplicationDocumentsDirectory()).path}/session_images/$masterSessionId');
//     await sessionDir.create(recursive: true);
    
//     for (int i = 0; i < rawPhotos.length; i++) {
//       final rawPhoto = rawPhotos[i] as Map<String, dynamic>;
//       final photoBytes = rawPhoto['bytes'] as Uint8List;
//       final shotGroup = rawPhoto['shotGroup'] as int? ?? 1;
//       final note = rawPhoto['note'] as String? ?? '';
      
//       final fileName = 'photo_$i.jpg';
//       final localPath = '${sessionDir.path}/$fileName';
//       final imageFile = File(localPath);
//       await imageFile.writeAsBytes(photoBytes);
      
//       photoDataList.add(PhotoData(
//         localPath: localPath,
//         shotGroup: shotGroup,
//         note: note,
//       ));
//     }
    
//     return photoDataList;
//   } catch (e) {
//     print('❌ Error downloading coach session images: $e');
//     return [];
//   }
// }

  /// Download shared session images
  Future<List<PhotoData>> downloadSharedSessionImages(
    String coachId,
    String masterSessionId,
  ) async {
    // Check local cache first
    if (await _storageService.hasLocalImages(masterSessionId)) {
      print('✅ Using cached local images');
      return await _storageService.getLocalImages(masterSessionId);
    }

    // Download from Firestore
    print('📥 Downloading from Firestore...');
    final photos = await _storageService.downloadSharedSessionImages(masterSessionId);

    // Mark as downloaded
    await markAsDownloaded(coachId, masterSessionId);

    return photos;
  }

  /// Delete coach's local session (not master session)
  Future<void> deleteCoachSession(String coachId, String masterSessionId) async {
    try {
      // Delete coach tracking document
      await _firestore
          .collection('coach_shared_sessions')
          .doc('${coachId}_$masterSessionId')
          .delete();

      // Remove coach from sharedCoaches array
      await _firestore
          .collection('shared_sessions_master')
          .doc(masterSessionId)
          .update({
        'sharedCoaches': FieldValue.arrayRemove([coachId]),
        'downloadedCoaches': FieldValue.arrayRemove([coachId]),
      });

      // Delete local images
      await _storageService.deleteLocalImages(masterSessionId);

      print('✅ Deleted coach session and local images');
    } catch (e) {
      print('❌ Error deleting coach session: $e');
      rethrow;
    }
  }

  /// Get coaches who already have this session shared
  Future<List<String>> getSharedCoaches(String originalSessionId, String studentId) async {
    try {
      final masterQuery = await _firestore
          .collection('shared_sessions_master')
          .where('originalSessionId', isEqualTo: originalSessionId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (masterQuery.docs.isEmpty) return [];

      final data = masterQuery.docs.first.data();
      return List<String>.from(data['sharedCoaches'] ?? []);
    } catch (e) {
      print('❌ Error getting shared coaches: $e');
      return [];
    }
  }

  /// Share coach-created session with student (auto-share)
Future<void> shareCoachSessionWithStudent({
  required String originalSessionId,
  required String studentId,
  required String coachId,
  required List<PhotoData> photos,
  Function(String)? onProgress,
}) async {
  try {
    onProgress?.call('Loading session data...');
  print('🔍 SHARE START: original=$originalSessionId, student=$studentId, coach=$coachId, photos=${photos.length}');
    // Get session data
    final sessionDoc = await _firestore
        .collection('training_sessions')
        .doc(originalSessionId)
        .get();
print('🔍 Session doc exists: ${sessionDoc.exists}');
    if (!sessionDoc.exists) {
      throw Exception('Session not found');
    }
print('🔍 Session data keys: ${sessionDoc.data()!.keys.toList()}');
    final sessionData = sessionDoc.data()!;

    // Check if already shared
    final existingQuery = await _firestore
        .collection('coach_student_sessions_master')
        .where('originalSessionId', isEqualTo: originalSessionId)
        .where('coachId', isEqualTo: coachId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
print('🔍 Existing shares: ${existingQuery.docs.length}');
    if (existingQuery.docs.isNotEmpty) {

      print('✅ Session already shared with student');
      return;
    }

    // Create master session ID
    final masterSessionId = 'coach_session_${DateTime.now().millisecondsSinceEpoch}_$coachId';
print('🔍 Master session ID: $masterSessionId');
    List<String> chunkIds = [];
    if (photos.isNotEmpty) {
      onProgress?.call('Compressing and uploading images...');
      
      // ✅ Compress images before upload
      final compressedPhotos = <PhotoData>[];
      for (final photo in photos) {
        final imageFile = File(photo.localPath);
        if (await imageFile.exists()) {
          final compressedBytes = await ImageCompressionHelper.compressImage(imageFile, quality: 85);
          
          // Save compressed to temp file
          final tempDir = await getTemporaryDirectory();
          final tempPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File(tempPath);
          await tempFile.writeAsBytes(compressedBytes);
          
          compressedPhotos.add(PhotoData(
            localPath: tempPath,
            shotGroup: photo.shotGroup,
            note: photo.note,
          ));
        }
      }
      
      chunkIds = await _storageService.uploadSharedSessionImages(
        sharedSessionId: masterSessionId,
        photos: compressedPhotos,
        onProgress: (current, total) {
          onProgress?.call('Uploading image $current of $total...');
        },
      );
      
      // Clean up temp files
      for (final photo in compressedPhotos) {
        final tempFile = File(photo.localPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    // Create master session document
    await _firestore
        .collection('coach_student_sessions_master')
        .doc(masterSessionId)
        .set({
      'coachId': coachId,
      'studentId': studentId,
      'originalSessionId': originalSessionId,
      'sessionName': sessionData['sessionName'] ?? 'Unnamed Session',
      'eventName': sessionData['eventName'] ?? '',
      'shots': sessionData['shots'] ?? [],
      'totalScore': sessionData['totalScore'] ?? 0.0,
      'totalTime': sessionData['totalTime'] ?? 0,
      'shotsPerTarget': sessionData['shotsPerTarget'] ?? 10,
      'notesList': sessionData['notesList'] ?? [],
      'notes': sessionData['notes'] ?? '',
      'shotGroups': sessionData['shotGroups'] ?? [],
      'hasImages': photos.isNotEmpty,
      'imageCount': photos.length,
      'chunkIds': chunkIds,
      'sharedAt': FieldValue.serverTimestamp(),
      'studentDownloaded': false,
      'chunksDeleted': false,
    });

    // Create student tracking document
    await _firestore
        .collection('student_coach_sessions')
        .doc('${studentId}_$masterSessionId')
        .set({
      'studentId': studentId,
      'masterSessionId': masterSessionId,
      'coachId': coachId,
      'sessionName': sessionData['sessionName'] ?? 'Unnamed Session',
      'eventName': sessionData['eventName'] ?? '',
      'sharedAt': FieldValue.serverTimestamp(),
      'isDownloaded': false,
      'isViewed': false,
      'hasImages': photos.isNotEmpty,
      'imageCount': photos.length,
      'shotsPerTarget': sessionData['shotsPerTarget'] ?? 10,
    });

    print('✅ Coach session shared with student: $masterSessionId');
    onProgress?.call('Shared successfully!');
  } catch (e) {
    print('❌ Error sharing coach session: $e');
    rethrow;
  }
}

/// Mark as downloaded by student and delete chunks
Future<void> markStudentDownloaded(String studentId, String masterSessionId) async {
  try {
    // Update student tracking
    await _firestore
        .collection('student_coach_sessions')
        .doc('${studentId}_$masterSessionId')
        .update({'isDownloaded': true});

    // Update master session
    await _firestore
        .collection('coach_student_sessions_master')
        .doc(masterSessionId)
        .update({'studentDownloaded': true});

    // Delete Firestore chunks immediately
    final masterDoc = await _firestore
        .collection('coach_student_sessions_master')
        .doc(masterSessionId)
        .get();

    if (masterDoc.exists) {
      final data = masterDoc.data()!;
      final chunkIds = List<String>.from(data['chunkIds'] ?? []);

      print('🗑️ Student downloaded - deleting Firestore chunks for $masterSessionId');

      WriteBatch batch = _firestore.batch();
      int count = 0;

      for (final chunkId in chunkIds) {
        batch.delete(_firestore.collection('shared_image_chunks').doc(chunkId));
        count++;
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }

      if (count % 500 != 0) {
        await batch.commit();
      }

      // Mark as deleted
      await _firestore
          .collection('coach_student_sessions_master')
          .doc(masterSessionId)
          .update({
        'chunksDeleted': true,
        'chunkIds': [],
      });

      print('✅ Deleted ${chunkIds.length} Firestore chunks - storage freed!');
    }
  } catch (e) {
    print('❌ Error in student download: $e');
    rethrow;
  }
}

/// Get coach sessions for student
Stream<QuerySnapshot> getCoachSessionsForStudent(String studentId) {
  return _firestore
      .collection('student_coach_sessions')
      .where('studentId', isEqualTo: studentId)
      .snapshots();
}

/// Download coach session images (for student)
// Future<List<PhotoData>> downloadCoachSessionImages(
//   String studentId,
//   String masterSessionId,
// ) async {
//   // Check local cache first
//   if (await _storageService.hasLocalImages(masterSessionId)) {
//     print('✅ Using cached local images');
//     return await _storageService.getLocalImages(masterSessionId);
//   }

//   // Download from Firestore
//   print('📥 Downloading coach session from Firestore...');
//   final photos = await _storageService.downloadSharedSessionImages(masterSessionId);

//   // Mark as downloaded and delete chunks
//   await markStudentDownloaded(studentId, masterSessionId);

//   return photos;
// }

/// Delete student's coach session
Future<void> deleteStudentCoachSession(String studentId, String masterSessionId) async {
  try {
    // Delete student tracking document
    await _firestore
        .collection('student_coach_sessions')
        .doc('${studentId}_$masterSessionId')
        .delete();

    // Delete local images
    await _storageService.deleteLocalImages(masterSessionId);

    print('✅ Deleted student coach session');
  } catch (e) {
    print('❌ Error deleting student coach session: $e');
    rethrow;
  }
}







/// Check if student has downloaded a coach session
Future<bool> isCoachSessionDownloaded(String studentId, String masterSessionId) async {
  try {
    final doc = await _firestore
        .collection('student_coach_sessions')
        .doc('${studentId}_$masterSessionId')
        .get();
    
    if (doc.exists) {
      return doc.data()?['isDownloaded'] ?? false;
    }
    return false;
  } catch (e) {
    print('❌ Error checking download status: $e');
    return false;
  }
}

/// Mark coach session as downloaded and delete from Firebase
Future<void> downloadCoachSessionAndDelete(
  String studentId, 
  String masterSessionId, 
  List<PhotoData> photos,
  List<Map<String, dynamic>> shots,
  Map<String, dynamic> sessionData
) async {
  try {
    final sessionService = SessionService();
    final localSessionId = 'local_coach_${DateTime.now().millisecondsSinceEpoch}_$studentId';
    
    print('🔍 Saving session with ${shots.length} shots');
    
    // ✅ FIXED: Proper type conversion
    await sessionService.saveSessionShots(
      sessionId: localSessionId,
      shots: shots,
      totalScore: (sessionData['totalScore'] ?? 0.0).toDouble(),
      totalTime: Duration(milliseconds: (sessionData['totalTime'] ?? 0) as int),
      notes: sessionData['notes']?.toString() ?? '',
      notesList: _convertToNotesList(sessionData['notesList']),  // ✅ Fixed
      shotGroups: _convertToShotGroups(sessionData['shotGroups']),  // ✅ Fixed
      missedShots: _convertToMissedShots(sessionData['missedShots']),  // ✅ Fixed
    );

    // Save images
    if (photos.isNotEmpty) {
      await sessionService.saveSessionImages(
        sessionId: localSessionId,
        photos: photos,
      );
    }

    // Update metadata
    await sessionService.updateSessionMetadata(localSessionId, {
      'originalSessionName': sessionData['sessionName']?.toString() ?? 'Coach Session',
      'eventName': sessionData['eventName']?.toString() ?? 'Pistol',
      'createdBy': 'coach',
      'coachSessionId': masterSessionId,
      'studentId': studentId,
      'shotsPerTarget': sessionData['shotsPerTarget'] ?? 10,
      'hasShots': shots.isNotEmpty,
    });

    // Mark as downloaded and delete from Firebase
    await markStudentDownloaded(studentId, masterSessionId);
    
    print('✅ Coach session downloaded locally: $localSessionId');
  } catch (e) {
    print('❌ Error downloading coach session: $e');
    rethrow;
  }
}

// ✅ Add these helper methods to SessionSharingService
List<Map<String, dynamic>> _convertToNotesList(dynamic notesList) {
  if (notesList == null) return [];
  if (notesList is List) {
    return notesList.map((item) {
      if (item is Map<String, dynamic>) return item;
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).toList();
  }
  return [];
}

List<Map<String, dynamic>> _convertToShotGroups(dynamic shotGroups) {
  if (shotGroups == null) return [];
  if (shotGroups is List) {
    return shotGroups.map((item) {
      if (item is Map<String, dynamic>) return item;
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).toList();
  }
  return [];
}

List<Map<String, dynamic>> _convertToMissedShots(dynamic missedShots) {
  if (missedShots == null) return [];
  if (missedShots is List) {
    return missedShots.map((item) {
      if (item is Map<String, dynamic>) return item;
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{};
    }).toList();
  }
  return [];
}

/// Get full coach session data for download
Future<Map<String, dynamic>> getCoachSessionData(String masterSessionId) async {
  try {
    final masterDoc = await _firestore
        .collection('coach_student_sessions_master')
        .doc(masterSessionId)
        .get();
    
    if (!masterDoc.exists) {
      throw Exception('Coach session not found');
    }
    
    return masterDoc.data()!;
  } catch (e) {
    print('❌ Error getting coach session data: $e');
    rethrow;
  }
}

/// Download coach session images for student
Future<List<PhotoData>> downloadCoachSessionImages(String masterSessionId) async {
  try {
    // ✅ Now returns List<PhotoData> directly (no conversion needed!)
    final photos = await _storageService.downloadCoachSessionImages(masterSessionId);
    
    print('📥 Downloaded ${photos.length} PhotoData objects');
    return photos;  // ✅ Return directly!
    
  } catch (e) {
    print('❌ Error downloading coach session images: $e');
    return <PhotoData>[];  // ✅ Typed empty list
  }
}



}
