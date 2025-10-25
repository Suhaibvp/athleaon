import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new session
// Create a new session
Future<String> createSession({
  required String studentId,
  required String studentName,
  required String sessionName, // NEW PARAMETER
  required String eventName,
  required int shotsPerTarget,
}) async {
  final coachId = _auth.currentUser!.uid;
  
  // Get coach data
  final coachDoc = await _firestore.collection('users').doc(coachId).get();
  final coachData = coachDoc.data()!;
  final coachName = '${coachData['firstName']} ${coachData['lastName']}';
  
  // Create session document
  final sessionRef = _firestore.collection('training_sessions').doc();
  
  await sessionRef.set({
    'sessionId': sessionRef.id,
    'studentId': studentId,
    'studentName': studentName,
    'coachId': coachId,
    'coachName': coachName,
    'sessionName': sessionName, // NEW FIELD
    'eventName': eventName,
    'shotsPerTarget': shotsPerTarget,
    'totalShots': 0,
    'completedShots': 0,
    'totalScore': 0.0,
    'averageScore': 0.0,
    'status': 'draft', // draft, in_progress, completed
    'createdAt': FieldValue.serverTimestamp(),
    'lastUpdated': null, // Will be set when session is opened/modified
    'shots': [],
  });
  
  return sessionRef.id;
}


  // Get sessions for a student
// Get sessions for a student (without orderBy to avoid index requirement)
Stream<QuerySnapshot> getStudentSessions(String studentId) {
  return _firestore
      .collection('training_sessions')
      .where('studentId', isEqualTo: studentId)
      // Remove .orderBy for now - we'll sort in the app
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
}
