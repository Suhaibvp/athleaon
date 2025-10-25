import 'package:flutter/material.dart';
import 'auth_screen.dart'; // Add this import

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Logo at top
              Text(
                'SHOTMATRIX',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD32F2F),
                  letterSpacing: 6,
                ),
              ),
              
              const SizedBox(height: 80),
              
              // "Login as" text
              Text(
                'Login as',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Role buttons grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildRoleCard(
                      context: context,
                      label: 'Student',
                      icon: Icons.school,
                      isEnabled: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(role: 'Student'),
                          ),
                        );
                      },
                    ),
                    _buildRoleCard(
                      context: context,
                      label: 'Instructor',
                      icon: Icons.person,
                      isEnabled: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(role: 'Instructor'),
                          ),
                        );
                      },
                    ),
                    _buildRoleCard(
                      context: context,
                      label: 'Guest',
                      icon: Icons.visibility,
                      isEnabled: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(role: 'Guest'),
                          ),
                        );
                      },
                    ),
                    _buildRoleCard(
                      context: context,
                      label: 'DTM Owner',
                      icon: Icons.admin_panel_settings,
                      isEnabled: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled 
              ? const Color(0xFF2A2A2A) 
              : const Color(0xFF2A2A2A).withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled 
                ? Colors.white.withOpacity(0.1) 
                : Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: isEnabled 
                  ? Colors.white.withOpacity(0.9) 
                  : Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isEnabled 
                    ? Colors.white.withOpacity(0.9) 
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
