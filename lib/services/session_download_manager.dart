// lib/services/session_download_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';  // ✅ ADD THIS
import 'package:path_provider/path_provider.dart';  //

class SessionDownloadManager {
  static const String _downloadedSessionsKey = 'downloaded_sessions';
  
  /// Check if session is downloaded locally
  Future<bool> isDownloaded(String sharedSessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_downloadedSessionsKey) ?? [];
    return downloaded.contains(sharedSessionId);
  }
  
  /// Mark session as downloaded
  Future<void> markAsDownloaded(String sharedSessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_downloadedSessionsKey) ?? [];
    if (!downloaded.contains(sharedSessionId)) {
      downloaded.add(sharedSessionId);
      await prefs.setStringList(_downloadedSessionsKey, downloaded);
    }
  }
  
  /// Remove download mark (if user deletes local data)
  Future<void> removeDownload(String sharedSessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getStringList(_downloadedSessionsKey) ?? [];
    downloaded.remove(sharedSessionId);
    await prefs.setStringList(_downloadedSessionsKey, downloaded);
  }
  
  /// Clear all downloads
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadedSessionsKey);
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
  Future<void> clearLocalCache(String sessionId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sessionDir = Directory('${appDir.path}/shared_sessions/$sessionId');
      
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
        print('✅ Cleared local cache for $sessionId');
      }
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

}
