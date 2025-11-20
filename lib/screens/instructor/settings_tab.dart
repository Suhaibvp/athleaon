import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../widgets/shooting_feedback_icons.dart';
import '../role_selection_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: Text(
            'No user logged in',
            style: TextStyle(color: Colors.white),
          ),
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
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ShootingFeedbackIcons.buildAppIcon(),
            ),
          ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'User data not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Profile photo (no badge)
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[700],
                  backgroundImage: currentUser.photoURL != null
                      ? NetworkImage(currentUser.photoURL!)
                      : null,
                  child: currentUser.photoURL == null
                      ? const Icon(Icons.person, color: Colors.white, size: 60)
                      : null,
                ),

                const SizedBox(height: 32),

                // Profile fields from Firestore
                _buildProfileField('First Name', userData['firstName'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildProfileField('Last Name', userData['lastName'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildProfileField('Email', userData['email'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildProfileField('Date of Birth', userData['dateOfBirth'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildDropdownField('State', userData['state'] ?? 'N/A'),
                const SizedBox(height: 16),
                _buildDropdownField('Language', userData['language'] ?? 'N/A'),

                const SizedBox(height: 32),

                // Edit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Enable editing
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showLogoutDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Logout',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog
            
            // Sign out
            await AuthService().signOut();
            
            // ✅ Navigate to role selection page
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildProfileField(String label, String value) {
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value) {
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
