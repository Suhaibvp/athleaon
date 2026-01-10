import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'session_tab.dart';
import 'coaches_tab.dart';
import 'profile_tab.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const SessionTab(),
    const CoachesTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: const Color(0xFFD32F2F),
        unselectedItemColor: Colors.white.withOpacity(0.5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icons/feedback/random_shoot.png',
        width: 24,
        height: 24,
        color: Colors.white.withOpacity(0.5),
      ),
      activeIcon: Image.asset(
        'assets/icons/feedback/random_shoot.png',
        width: 24,
        height: 24,
        color: const Color(0xFFD32F2F),
      ),
      label: 'Sessions',
    ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Coaches',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
