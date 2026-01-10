import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import '../models/photo_data.dart';
import 'dart:math' as math;

class SessionStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const int maxChunkSize = 10 * 1024;

  /// Upload shared session images
  Future<List<String>> uploadSharedSessionImages({
    required String sharedSessionId,
    required List<PhotoData> photos,
    Function(int current, int total)? onProgress,
  }) async {
    final allChunkIds = <String>[];
    
    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final imageFile = File(photo.localPath);
      
      if (!await imageFile.exists()) continue;
      
      final imageBytes = await imageFile.readAsBytes();
      print('📸 Image $i (${photo.shotGroup}): ${imageBytes.length} bytes');
      
      final chunkIds = await _uploadImageWithByteCheck(
        sharedSessionId: sharedSessionId,
        imageIndex: i,
        imageBytes: imageBytes,
        shotGroup: photo.shotGroup,
        note: photo.note,
      );
      
      allChunkIds.addAll(chunkIds);
      onProgress?.call(i + 1, photos.length);
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return allChunkIds;
  }

  Future<List<String>> _uploadImageWithByteCheck({
    required String sharedSessionId,
    required int imageIndex,
    required Uint8List imageBytes,
    required int shotGroup,
    required String note,
  }) async {
    final totalChunks = (imageBytes.length / maxChunkSize).ceil();
    final chunkIds = <String>[];
    
    print('  → ${totalChunks} chunks from ${imageBytes.length} bytes');
    
    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      final start = chunkIndex * maxChunkSize;
      final end = math.min(start + maxChunkSize, imageBytes.length);
      final chunkBytes = imageBytes.sublist(start, end);
      
      print('    Chunk $chunkIndex: ${chunkBytes.length} bytes');
      
      final chunkId = 'chunk_${sharedSessionId}_${imageIndex}_${chunkIndex}';
      
      final testDoc = {
        's': sharedSessionId,
        'i': imageIndex,
        'c': chunkIndex,
        't': totalChunks,
        'g': shotGroup,  // ✅ Added shotGroup
        'n': note,       // ✅ Added note
        'b': chunkBytes,
      };
      
      print('    Test doc size: ${estimateFirestoreSize(testDoc)} bytes');
      
      if (estimateFirestoreSize(testDoc) > 1000000) {
        print('    ⚠️ SKIPPING - too large!');
        continue;
      }
      
      await _firestore.collection('shared_image_chunks').doc(chunkId).set(testDoc);
      chunkIds.add(chunkId);
      
      print('    ✅ $chunkId uploaded');
      await Future.delayed(const Duration(milliseconds: 50));
    }
    
    return chunkIds;
  }

  int estimateFirestoreSize(Map<String, dynamic> data) {
    int size = 32;
    
    data.forEach((key, value) {
      size += key.length * 2 + 8;
      
      if (value is String) {
        size += value.length * 2 + 4;
      } else if (value is int) {
        size += 8;
      } else if (value is Uint8List) {
        size += value.length + 4;
      }
    });
    
    return size;
  }

  /// ✅ NEW: Check if images are already downloaded locally
Future<bool> hasLocalImages(String sessionId) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/shared_sessions/$sessionId');
    
    if (!await sessionDir.exists()) return false;
    
    final files = sessionDir.listSync();
    return files.where((f) => f.path.endsWith('.jpg')).isNotEmpty;
  } catch (e) {
    print('❌ Error checking local images: $e');
    return false;
  }
}


  /// ✅ NEW: Get local images without downloading
Future<List<PhotoData>> getLocalImages(String sessionId) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/shared_sessions/$sessionId');
    
    if (!await sessionDir.exists()) return [];
    
    final files = sessionDir
        .listSync()
        .where((f) => f.path.endsWith('.jpg'))
        .map((f) => f as File)
        .toList();
    
    files.sort((a, b) => a.path.compareTo(b.path));
    
    final photos = <PhotoData>[];
    for (final file in files) {
      // Parse shotGroup from filename
      // Format: img{index}_g{shotGroup}.jpg
      final match = RegExp(r'_g(\d+)\.jpg$').firstMatch(file.path);
      final shotGroup = match != null ? int.parse(match.group(1)!) : 1;
      
      photos.add(PhotoData(
        localPath: file.path,
        note: '',
        shotGroup: shotGroup,
      ));
    }
    
    print('✅ Loaded ${photos.length} local images from cache');
    return photos;
  } catch (e) {
    print('❌ Error loading local images: $e');
    return [];
  }
}
Future<List<PhotoData>> downloadCoachSessionImages(String masterSessionId) async {
  print('📥 [downloadCoachSessionImages] START for coach session: $masterSessionId');

  if (await hasLocalImages(masterSessionId)) {
    print('✅ Using cached local images');
    return await getLocalImages(masterSessionId);
  }

  print('📥 Downloading from Firestore...');

  try {
    // ✅ ONLY DIFFERENCE: coach_student_sessions_master
    final masterDoc = await _firestore
        .collection('coach_student_sessions_master')
        .doc(masterSessionId)
        .get();

    if (!masterDoc.exists) {
      throw Exception('Master session $masterSessionId not found');
    }

    final masterData = masterDoc.data() as Map<String, dynamic>;
    final chunksDeleted = masterData['chunksDeleted'] ?? false;
    if (chunksDeleted) {
      throw Exception('Images have been deleted from Firestore');
    }
    
    final List<dynamic>? chunkIdsDynamic = masterData['chunkIds'] as List<dynamic>?;
    if (chunkIdsDynamic == null || chunkIdsDynamic.isEmpty) {
      print('📥 No chunkIds stored');
      return [];
    }

    final List<String> chunkIds = chunkIdsDynamic.cast<String>();
    print('📥 Found ${chunkIds.length} chunkIds');

    // ✅ LOAD CHUNKS (NO DEBUG PRINT - that's crashing!)
    final List<DocumentSnapshot<Map<String, dynamic>>> chunkDocs = [];
    for (final id in chunkIds) {
      final doc = await _firestore.collection('shared_image_chunks').doc(id).get();
      if (doc.exists) {
        chunkDocs.add(doc);  // ✅ NO PRINT = NO CRASH
      }
    }

    print('📥 Loaded ${chunkDocs.length} chunk docs');

    if (chunkDocs.isEmpty) {
      print('📥 No chunk docs exist');
      return [];
    }

    // ✅ USE YOUR WORKING REASSEMBLY LOGIC (copy from downloadSharedSessionImages)
    final photos = await _reassembleImagesFromChunks(chunkDocs, masterSessionId);
    
    print('✅ [downloadCoachSessionImages] Completed: ${photos.length} images');
    return photos;
    
  } catch (e) {
    print('❌ [downloadCoachSessionImages] ERROR: $e');
    rethrow;
  }
}

/// ✅ EXTRACT YOUR WORKING LOGIC as private method
Future<List<PhotoData>> _reassembleImagesFromChunks(
  List<DocumentSnapshot<Map<String, dynamic>>> chunkDocs, 
  String masterSessionId
) async {
  final Map<int, List<DocumentSnapshot<Map<String, dynamic>>>> imageChunks = {};

  for (final doc in chunkDocs) {
    final data = doc.data()!;
    if (!data.containsKey('i') || !data.containsKey('c')) continue;
    final imageIndex = data['i'] as int;
    imageChunks.putIfAbsent(imageIndex, () => []).add(doc);
  }

  print('📥 Grouped into ${imageChunks.length} images');

  final List<PhotoData> photos = [];
  final appDir = await getApplicationDocumentsDirectory();
  final sessionDir = Directory('${appDir.path}/shared_sessions/$masterSessionId');
  await sessionDir.create(recursive: true);

  // ✅ YOUR EXACT WORKING RECONSTRUCTION LOGIC
  for (final entry in imageChunks.entries) {
    final imageIndex = entry.key;
    final chunks = entry.value;

    print('  🔧 Reassembling image $imageIndex with ${chunks.length} chunks');

    chunks.sort((a, b) {
      final aData = a.data()!;
      final bData = b.data()!;
      final aIdx = aData['c'] as int? ?? 0;
      final bIdx = bData['c'] as int? ?? 0;
      return aIdx.compareTo(bIdx);
    });

    final firstData = chunks.first.data()!;
    final shotGroup = (firstData['g'] as int?) ?? 1;
    final note = (firstData['n'] as String?) ?? '';

    final List<int> allBytes = [];
    for (final doc in chunks) {
      final data = doc.data()!;
      final raw = data['b'];

      Uint8List bytes;
      if (raw is Uint8List) {
        bytes = raw;
      } else if (raw is List<int>) {
        bytes = Uint8List.fromList(raw);
      } else if (raw is List<dynamic>) {
        bytes = Uint8List.fromList(raw.cast<int>());
      } else {
        print('   ⚠️ Unexpected bytes type: ${raw.runtimeType}');
        continue;
      }

      allBytes.addAll(bytes);
    }

    if (allBytes.isEmpty) continue;

    final path = '${sessionDir.path}/img${imageIndex}_g$shotGroup.jpg';
    final file = File(path);
    await file.writeAsBytes(allBytes);

    photos.add(PhotoData(localPath: path, note: note, shotGroup: shotGroup));
  }

  return photos;
}



/// ✅ UPDATED: Download with local caching from shared_sessions_master
Future<List<PhotoData>> downloadSharedSessionImages(String masterSessionId) async {
  print('📥 [downloadSharedSessionImages] START for masterSessionId=$masterSessionId');

  // ✅ CHECK LOCAL CACHE FIRST
  if (await hasLocalImages(masterSessionId)) {
    print('✅ Using cached local images');
    return await getLocalImages(masterSessionId);
  }

  print('📥 Downloading from Firestore...');

  try {
    // ✅ CHANGED: Look in shared_sessions_master collection
    final masterDoc = await _firestore
        .collection('shared_sessions_master')
        .doc(masterSessionId)
        .get();

    if (!masterDoc.exists) {
      throw Exception('Master session $masterSessionId not found');
    }

    final masterData = masterDoc.data() as Map<String, dynamic>;
    
    // ✅ Check if chunks were already deleted
    final chunksDeleted = masterData['chunksDeleted'] ?? false;
    if (chunksDeleted) {
      throw Exception('Images have been deleted from Firestore. All coaches have already downloaded.');
    }
    
    final List<dynamic>? chunkIdsDynamic = masterData['chunkIds'] as List<dynamic>?;
    
    if (chunkIdsDynamic == null || chunkIdsDynamic.isEmpty) {
      throw Exception('No chunkIds stored for $masterSessionId');
    }

    final List<String> chunkIds = chunkIdsDynamic.cast<String>();
    print('📥 chunkIds from shared_sessions_master: ${chunkIds.length} ids');

    final List<DocumentSnapshot<Map<String, dynamic>>> chunkDocs = [];
    for (final id in chunkIds) {
      final doc = await _firestore
          .collection('shared_image_chunks')
          .doc(id)
          .get();

      if (!doc.exists) {
        print('⚠️ Missing chunk doc: $id');
        continue;
      }
      chunkDocs.add(doc);
    }

    print('📥 Loaded ${chunkDocs.length} existing chunk docs');

    if (chunkDocs.isEmpty) {
      throw Exception('No chunk docs exist for $masterSessionId');
    }

    final Map<int, List<DocumentSnapshot<Map<String, dynamic>>>> imageChunks = {};

    for (final doc in chunkDocs) {
      final data = doc.data()!;
      
      // ✅ Use short field names
      if (!data.containsKey('i') || !data.containsKey('c')) {
        print('! Skipping ${doc.id} – missing i/c fields');
        continue;
      }
      
      final imageIndex = data['i'] as int;
      imageChunks.putIfAbsent(imageIndex, () => []).add(doc);
    }

    print('📥 Grouped into ${imageChunks.length} images');

    final List<PhotoData> photos = [];

    // ✅ Create permanent storage directory
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/shared_sessions/$masterSessionId');
    if (!await sessionDir.exists()) {
      await sessionDir.create(recursive: true);
    }

    for (final entry in imageChunks.entries) {
      final int imageIndex = entry.key;
      final List<DocumentSnapshot<Map<String, dynamic>>> chunks = entry.value;

      print('  🔧 Reassembling image $imageIndex with ${chunks.length} chunks');

      // ✅ Sort by chunk index
      chunks.sort((a, b) {
        final aData = a.data()!;
        final bData = b.data()!;
        final aIdx = aData['c'] as int? ?? 0;
        final bIdx = bData['c'] as int? ?? 0;
        return aIdx.compareTo(bIdx);
      });

      final firstData = chunks.first.data()!;
      final int shotGroup = (firstData['g'] as int?) ?? 1;
      final String note = (firstData['n'] as String?) ?? '';

      final List<int> allBytes = [];
      int totalSize = 0;

      for (final doc in chunks) {
        final data = doc.data()!;
        final raw = data['b'];

        Uint8List bytes;
        if (raw is Uint8List) {
          bytes = raw;
        } else if (raw is List<int>) {
          bytes = Uint8List.fromList(raw);
        } else if (raw is List<dynamic>) {
          bytes = Uint8List.fromList(raw.cast<int>());
        } else {
          print('   ⚠️ Unexpected bytes type in ${doc.id}: ${raw.runtimeType}');
          continue;
        }

        allBytes.addAll(bytes);
        totalSize += bytes.length;
      }

      if (allBytes.isEmpty) {
        print('  ⚠️ No bytes for image $imageIndex, skipping');
        continue;
      }

      print('  ✅ Image $imageIndex total ${(totalSize / 1024).toStringAsFixed(1)}KB');

      // ✅ Save to PERMANENT storage
      final path = '${sessionDir.path}/img${imageIndex}_g$shotGroup.jpg';
      final file = File(path);
      await file.writeAsBytes(allBytes);

      photos.add(PhotoData(
        localPath: file.path,
        note: note,
        shotGroup: shotGroup,
      ));
    }

    print('✅ [downloadSharedSessionImages] Completed: ${photos.length} images saved locally');
    return photos;
  } catch (e, st) {
    print('❌ [downloadSharedSessionImages] ERROR: $e');
    print(st);
    rethrow;
  }
}


  /// Delete shared session images (both local and Firestore)
  Future<void> deleteSharedSessionImages(String sharedSessionId) async {
    try {
      print('🗑️ Deleting images for session: $sharedSessionId');
      
      // Delete local files
      final appDir = await getApplicationDocumentsDirectory();
      final sessionDir = Directory('${appDir.path}/shared_sessions/$sharedSessionId');
      
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
        print('✅ Deleted local images');
      }
      
      // Delete Firestore chunks
      final chunkDocs = await _firestore
          .collection('shared_image_chunks')
          .where('s', isEqualTo: sharedSessionId)
          .get();
      
      if (chunkDocs.docs.isEmpty) {
        print('No Firestore chunks to delete');
        return;
      }
      
      WriteBatch batch = _firestore.batch();
      int count = 0;
      
      for (final doc in chunkDocs.docs) {
        batch.delete(doc.reference);
        count++;
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
      
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Deleted ${chunkDocs.docs.length} Firestore chunks');
    } catch (e) {
      print('❌ Error deleting shared images: $e');
      rethrow;
    }
  }

  /// Delete only local images (not Firestore)
Future<void> deleteLocalImages(String sessionId) async {
  try {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionDir = Directory('${appDir.path}/shared_sessions/$sessionId');
    
    if (await sessionDir.exists()) {
      await sessionDir.delete(recursive: true);
      print('✅ Deleted local images for $sessionId');
    }
  } catch (e) {
    print('❌ Error deleting local images: $e');
    rethrow;
  }
}

}
