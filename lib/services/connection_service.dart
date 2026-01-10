import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  // Add this getter!
  String get currentUserId => _auth.currentUser?.uid ?? '';
  /// COACH initiates connection to student (instant connect)
  Future<void> connectWithStudent(String studentId) async {
    final coachId = _auth.currentUser!.uid;

    final existingConnection = await _firestore
      .collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('studentId', isEqualTo: studentId)
      .where('initiatedBy', isEqualTo: 'coach')
      .limit(1).get();

    if (existingConnection.docs.isNotEmpty) {
      throw 'Already connected with this student';
    }

    await _firestore.collection('connections').add({
      'coachId': coachId,
      'studentId': studentId,
      'status': 'connected',
      'initiatedBy': 'coach',
      'connectedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// COACH disconnects from student (removes only their own connection)
  Future<void> disconnectStudent(String studentId) async {
    final coachId = _auth.currentUser!.uid;
    final conn = await _firestore.collection('connections')
        .where('coachId', isEqualTo: coachId)
        .where('studentId', isEqualTo: studentId)
        .where('initiatedBy', isEqualTo: 'coach')
        .limit(1)
        .get();

    if (conn.docs.isNotEmpty) {
      await conn.docs.first.reference.delete();
    }
  }

  /// COACH checks if connected to student (instant connections only)
  Future<bool> isConnectedWithStudent(String studentId) async {
    final coachId = _auth.currentUser!.uid;
    final conn = await _firestore.collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('studentId', isEqualTo: studentId)
      .where('initiatedBy', isEqualTo: 'coach')
      .where('status', isEqualTo: 'connected')
      .limit(1).get();
    return conn.docs.isNotEmpty;
  }

  /// STUDENT requests connection to instructor (status = pending)
  Future<void> requestInstructorConnection(String coachId) async {
    final studentId = _auth.currentUser!.uid;
    final existingRequest = await _firestore
      .collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('studentId', isEqualTo: studentId)
      .where('initiatedBy', isEqualTo: 'student')
      .limit(1).get();

    if (existingRequest.docs.isNotEmpty) {
      throw 'Already requested connection with this instructor';
    }

    await _firestore.collection('connections').add({
      'coachId': coachId,
      'studentId': studentId,
      'status': 'pending',
      'initiatedBy': 'student',
      'requestedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// STUDENT cancels request to instructor
  Future<void> cancelInstructorRequest(String coachId) async {
    final studentId = _auth.currentUser!.uid;
    final request = await _firestore.collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('studentId', isEqualTo: studentId)
      .where('initiatedBy', isEqualTo: 'student')
      .where('status', isEqualTo: 'pending')
      .limit(1).get();

    if (request.docs.isNotEmpty) {
      await request.docs.first.reference.delete();
    }
  }

  /// COACH gets all pending requests from students
  Stream<QuerySnapshot> getPendingRequestsForCoach(String coachId) {
    return _firestore.collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'pending')
      .where('initiatedBy', isEqualTo: 'student')
      .snapshots();
  }

  /// COACH accepts a student's connection request (status: pending → connected)
  Future<void> acceptStudentRequest(String connectionDocId) async {
    await _firestore.collection('connections').doc(connectionDocId).update({
      'status': 'connected',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// COACH denies (deletes) a student's connection request
  Future<void> denyStudentRequest(String connectionDocId) async {
    await _firestore.collection('connections').doc(connectionDocId).delete();
  }

  /// STUDENT checks if (pending or connected) request with instructor exists
  Future<String?> requestStatusWithInstructor(String coachId) async {
    final studentId = _auth.currentUser!.uid;
    final conn = await _firestore.collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('studentId', isEqualTo: studentId)
      .where('initiatedBy', isEqualTo: 'student')
      .limit(1).get();
    if (conn.docs.isNotEmpty) {
      return (conn.docs.first.data() as Map<String, dynamic>)['status'] as String?;
    } else {
      return null; // no request found
    }
  }

  /// STUDENT gets all their connected instructors
  Stream<QuerySnapshot> getConnectedInstructors(String studentId) {
    return _firestore
      .collection('connections')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'connected')
      .snapshots();
  }

  /// COACH gets all their connected students
  Stream<QuerySnapshot> getConnectedStudents(String coachId) {
    return _firestore
      .collection('connections')
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'connected')
      .snapshots();
  }

  // Optional: generic get student/coach user profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }
}
