import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Connect coach with student
  Future<void> connectWithStudent(String studentId) async {
    final coachId = _auth.currentUser!.uid;
    
    try {
      // Check if connection already exists
      final existingConnection = await _firestore
          .collection('connections')
          .where('coachId', isEqualTo: coachId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        throw 'Already connected with this student';
      }

      // Create new connection
      await _firestore.collection('connections').add({
        'coachId': coachId,
        'studentId': studentId,
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Disconnect coach from student
  Future<void> disconnectStudent(String studentId) async {
    final coachId = _auth.currentUser!.uid;
    
    try {
      final connection = await _firestore
          .collection('connections')
          .where('coachId', isEqualTo: coachId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (connection.docs.isNotEmpty) {
        await connection.docs.first.reference.delete();
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // Check if coach is connected to student
  Future<bool> isConnected(String studentId) async {
    final coachId = _auth.currentUser!.uid;
    
    try {
      final connection = await _firestore
          .collection('connections')
          .where('coachId', isEqualTo: coachId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      return connection.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get connected students for coach
  Stream<QuerySnapshot> getConnectedStudents(String coachId) {
    return _firestore
        .collection('connections')
        .where('coachId', isEqualTo: coachId)
        .where('status', isEqualTo: 'connected')
        .snapshots();
  }

  // Get student data from connection
  Future<Map<String, dynamic>?> getStudentData(String studentId) async {
    try {
      final doc = await _firestore.collection('users').doc(studentId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
