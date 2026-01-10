import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';

class StudentDescriptionScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String? photoUrl;

  const StudentDescriptionScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.photoUrl,
  });

  @override
  State<StudentDescriptionScreen> createState() =>
      _StudentDescriptionScreenState();
}

class _StudentDescriptionScreenState extends State<StudentDescriptionScreen> {
  final ConnectionService _connectionService = ConnectionService();
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await _connectionService.isConnectedWithStudent(widget.studentId);
    setState(() {
      _isConnected = connected;
      _isLoading = false;
    });
  }

  Future<void> _handleConnect() async {
    setState(() => _isConnecting = true);

    try {
      if (_isConnected) {
        await _connectionService.disconnectStudent(widget.studentId);
        _showMessage('Disconnected from ${widget.studentName}');
        setState(() => _isConnected = false);
      } else {
        await _connectionService.connectWithStudent(widget.studentId);
        _showMessage('Connected with ${widget.studentName}');
        setState(() => _isConnected = true);
      }
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.studentName
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0] : '')
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Student avatar and info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[700],
                          backgroundImage: widget.photoUrl != null
                              ? NetworkImage(widget.photoUrl!)
                              : null,
                          child: widget.photoUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),

                        const SizedBox(width: 16),

                        // Name and ID
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.studentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '0012', // TODO: Get actual ID from database
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Shield icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Connect button
                        ElevatedButton(
                          onPressed: _isConnecting ? null : _handleConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isConnected
                                ? Colors.grey[700]
                                : const Color(0xFFD32F2F),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isConnected ? 'Disconnect' : 'Connect',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Student Description section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Email
                        _buildInfoRow('Email', widget.studentEmail),
                        
                        const SizedBox(height: 12),
                        
                        // Additional info can be added here
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.studentId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox();
                            }

                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            if (data == null) return const SizedBox();

                            return Column(
                              children: [
                                if (data['dateOfBirth'] != null) ...[
                                  _buildInfoRow('Date of Birth', data['dateOfBirth']),
                                  const SizedBox(height: 12),
                                ],
                                if (data['state'] != null) ...[
                                  _buildInfoRow('State', data['state']),
                                  const SizedBox(height: 12),
                                ],
                                if (data['language'] != null)
                                  _buildInfoRow('Language', data['language']),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2A2A2A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
