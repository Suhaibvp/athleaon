import 'package:flutter/material.dart';
import 'dart:math' as math;

class RifleShootingScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;

  const RifleShootingScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.shotsPerTarget,
  });

  @override
  State<RifleShootingScreen> createState() => _RifleShootingScreenState();
}

class _RifleShootingScreenState extends State<RifleShootingScreen> {
  int _currentShotNumber = 1;

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          // Header with event type and buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Rifle badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Rifle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Begin/End button
                OutlinedButton(
                  onPressed: () {
                    // TODO: Toggle begin/end
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Begin/End'),
                ),
              ],
            ),
          ),

          // Timer
          const Text(
            '00:00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // Rifle Target (Numbered rings)
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD32F2F), width: 4),
            ),
            child: CustomPaint(
              painter: RifleTargetPainter(),
            ),
          ),

          const SizedBox(height: 30),

          // Score displays
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildScoreBox('10.00'),
                _buildScoreBox('10.00'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Control buttons (2 rows)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // First row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(Icons.refresh),
                    _buildControlButton(Icons.flash_on),
                    _buildControlButton(Icons.menu),
                    _buildControlButton(Icons.arrow_upward),
                    _buildControlButton(Icons.wb_sunny_outlined),
                  ],
                ),
                const SizedBox(height: 12),
                // Second row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(Icons.close),
                    _buildControlButton(Icons.info_outline),
                    _buildControlButton(Icons.call),
                    _buildControlButton(Icons.people_outline),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Navigation and controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  onPressed: () {
                    if (_currentShotNumber > 1) {
                      setState(() => _currentShotNumber--);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  onPressed: () {},
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_currentShotNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                  onPressed: () {
                    setState(() => _currentShotNumber++);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Reset
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFD32F2F)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '00:00',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Start timer
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Save session
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildScoreBox(String score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Text(
        score,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: () {
          // TODO: Handle button press
        },
      ),
    );
  }
}

// Custom painter for Rifle target (numbered rings 1-10)
class RifleTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 10 concentric circles with numbers
    for (int i = 10; i >= 1; i--) {
      final radius = (maxRadius / 10) * i;
      
      // Alternate colors: inner circles darker
      final paint = Paint()
        ..color = i <= 5 ? Colors.black : Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);

      // Draw ring outline
      final outlinePaint = Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      
      canvas.drawCircle(center, radius, outlinePaint);

      // Draw numbers at 4 positions (top, right, bottom, left)
      if (i > 1) {
        _drawNumber(canvas, center, radius, i, size);
      }
    }

    // Draw center dot
    canvas.drawCircle(
      center,
      3,
      Paint()..color = Colors.red,
    );
  }

  void _drawNumber(Canvas canvas, Offset center, double radius, int number, Size size) {
    final textColor = number <= 5 ? Colors.white : Colors.black;
    
    // Draw numbers at 4 cardinal directions
    for (int angle in [0, 90, 180, 270]) {
      final radians = angle * math.pi / 180;
      final x = center.dx + (radius - 15) * math.cos(radians);
      final y = center.dy + (radius - 15) * math.sin(radians);

      final textSpan = TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
