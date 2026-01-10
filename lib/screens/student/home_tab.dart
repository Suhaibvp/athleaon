import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';
import 'dart:math' as math;

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ConnectionService _connectionService = ConnectionService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firstName = currentUser?.displayName?.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Welcome $firstName',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown('Event', Icons.arrow_drop_down),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown('Timeframe', Icons.arrow_drop_down),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Chart 1: Line Chart - Highest shots per day (placeholder)
            _buildLineChartCard(
              title: 'Your Highest\nshots per day',
              value: '400',
              data: [30, 50, 40, 80, 120, 90, 150, 200],
              color: const Color(0xFFD32F2F),
            ),

            const SizedBox(height: 16),

            // Chart 2: Bar Chart - Highest score (placeholder)
            _buildBarChartCard(
              title: 'Your Highest\nscore',
              value: '1200',
              data: [200, 400, 600, 800, 900, 700, 850, 1000],
              color: const Color(0xFFD32F2F),
            ),

            const SizedBox(height: 24),

            // Connected Coaches Section - Real data from Firestore
            _buildConnectedCoaches(),

            // const SizedBox(height: 24),

            // // Start Session Button - Navigate to Sessions tab
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     onPressed: () {
            //       // Navigate to Sessions tab (index 1 in bottom nav)
            //       DefaultTabController.of(context).animateTo(1);
            //     },
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: const Color(0xFFD32F2F),
            //       padding: const EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //     ),
            //     child: const Text(
            //       'Start a Session',
            //       style: TextStyle(
            //         fontSize: 16,
            //         fontWeight: FontWeight.w600,
            //         color: Colors.white,
            //       ),
            //     ),
            //   ),
            // ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          Icon(icon, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildLineChartCard({
    required String title,
    required String value,
    required List<double> data,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Line Chart
          SizedBox(
            height: 120,
            child: LineChart(
              data: data,
              color: color,
            ),
          ),

          const SizedBox(height: 12),

          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Sun']
                .map((day) => Text(
                      day,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard({
    required String title,
    required String value,
    required List<double> data,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Simple bar chart visualization
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((value) {
                final maxValue = data.reduce((a, b) => a > b ? a : b);
                final height = (value / maxValue) * 120;
                return Container(
                  width: 30,
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Sun']
                .map((day) => Text(
                      day,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedCoaches() {
    final currentUserId = _connectionService.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Connected Coaches',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                // Navigate to Coaches tab (index 2 in bottom nav)
                DefaultTabController.of(context).animateTo(2);
              },
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Real coaches list from Firestore
        StreamBuilder<QuerySnapshot>(
          stream: _connectionService.getConnectedInstructors(currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No connected coaches yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            final connections = snapshot.data!.docs;

            return Column(
              children: connections.map((doc) {
                final connection = doc.data() as Map<String, dynamic>;
                final coachId = connection['coachId'] ?? '';

                return FutureBuilder<Map<String, dynamic>?>(
                  future: _connectionService.getUserProfile(coachId),
                  builder: (context, coachSnapshot) {
                    final coachData = coachSnapshot.data;
                    final firstName = coachData?['firstName'] ?? 'Unknown';
                    final lastName = coachData?['lastName'] ?? '';
                    final fullName = '$firstName $lastName'.trim();
                    final photoUrl = coachData?['photoUrl'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey[700],
                            backgroundImage:
                                photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  coachData?['email'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shield,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// Custom Line Chart Widget (keep as-is)
class LineChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const LineChart({
    super.key,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LineChartPainter(
        data: data,
        color: color,
      ),
      child: Container(),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  LineChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final y = size.height - (data[i] / maxValue * size.height);
      points.add(Offset(x, y));
    }

    final gradientPath = Path();
    gradientPath.moveTo(points.first.dx, size.height);
    for (final point in points) {
      gradientPath.lineTo(point.dx, point.dy);
    }
    gradientPath.lineTo(points.last.dx, size.height);
    gradientPath.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(gradientPath, gradientPaint);

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final controlPoint1 = Offset(
        p0.dx + (p1.dx - p0.dx) / 3,
        p0.dy,
      );
      final controlPoint2 = Offset(
        p0.dx + 2 * (p1.dx - p0.dx) / 3,
        p1.dy,
      );

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        point,
        2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
