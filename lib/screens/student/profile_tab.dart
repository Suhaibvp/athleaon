import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../role_selection_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isLoading = true;
  
  // Controllers for editable fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dobController;
  late TextEditingController _stateController;
  late TextEditingController _languagesController;
  late TextEditingController _eventsController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _dobController = TextEditingController();
    _stateController = TextEditingController();
    _languagesController = TextEditingController();
    _eventsController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _stateController.dispose();
    _languagesController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final doc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _firstNameController.text = data['firstName'] ?? '';
            _lastNameController.text = data['lastName'] ?? '';
            _dobController.text = data['dateOfBirth'] ?? '';
            _stateController.text = data['state'] ?? '';
            _languagesController.text = data['languages'] ?? '';
            _eventsController.text = data['events'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showMessage('Error loading profile data');
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'dateOfBirth': _dobController.text.trim(),
          'state': _stateController.text.trim(),
          'languages': _languagesController.text.trim(),
          'events': _eventsController.text.trim(),
        });
        setState(() => _isEditing = false);
        _showMessage('Profile updated successfully');
      } catch (e) {
        _showMessage('Error updating profile');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        actions: [

        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile photo
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: currentUser?.photoURL != null
                        ? NetworkImage(currentUser!.photoURL!)
                        : null,
                    child: currentUser?.photoURL == null
                        ? const Icon(Icons.person, color: Colors.white, size: 60)
                        : null,
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                      ),
                      child: Text(
                        '0021',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Email display (not editable)
              _buildProfileField('Email', currentUser?.email ?? 'No email', enabled: false),
              const SizedBox(height: 16),

              // Editable fields
              _buildEditableField('First Name', _firstNameController),
              const SizedBox(height: 16),
              _buildEditableField('Last Name', _lastNameController),
              const SizedBox(height: 16),
              _buildEditableField('Date of birth', _dobController, hint: 'DD/MM/YYYY'),
              const SizedBox(height: 16),
              _buildEditableField('State', _stateController),
              const SizedBox(height: 16),
              _buildEditableField('Languages', _languagesController, hint: 'e.g., English, Hindi'),
              const SizedBox(height: 16),
              _buildEditableField('Events', _eventsController, hint: 'e.g., ISSF 10m air rifle'),

              const SizedBox(height: 32),

              // Edit/Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_isEditing) {
                      _saveUserData();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Save' : 'Edit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showLogoutDialog(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFD32F2F), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
                          if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (route) => false, // ✅ Clear all previous routes
              );
            }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: _isEditing,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD32F2F)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
