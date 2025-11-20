import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_selection_screen.dart';
import 'student/student_dashboard.dart';
import 'instructor/instructor_dashboard.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup fade animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    _animationController.forward();
    
    // Check auth state after 2 seconds
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // User is logged in, get their role
      final role = await AuthService().getUserRole(currentUser.uid);
      
      if (!mounted) return;
      
      if (role == 'Student') {
        // Navigate to Student Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const StudentDashboard(),
          ),
        );
      } else if (role == 'Instructor') {
        // Navigate to Instructor Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const InstructorDashboard(),
          ),
        );
      } else {
        // Role not found, go to role selection
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RoleSelectionScreen(),
          ),
        );
      }
    } else {
      // User not logged in, go to role selection
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const RoleSelectionScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2C), // Dark background like your design
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Image
              Image.asset(
                'assets/images/logo.png', // Adjust path if needed
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image not found
                  return Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 80,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // SHOT METRIX Text
              const Text(
                'SHOT METRIX',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F),
                  letterSpacing: 3.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
