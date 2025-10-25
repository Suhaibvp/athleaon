import 'package:flutter/material.dart';
import 'dart:math' as math;

class PistolShootingScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final int shotsPerTarget;

  const PistolShootingScreen({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.shotsPerTarget,
  });

  @override
  State<PistolShootingScreen> createState() => _PistolShootingScreenState();
}

class _PistolShootingScreenState extends State<PistolShootingScreen> {
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
        // No actions (shield removed)
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Header with Pistol badge, Begin/End, and green shield icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pistol badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Pistol',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Begin/End button (CENTER)
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Toggle begin/end
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      minimumSize: const Size(0, 0),
                    ),
                    child: const Text('Begin/End', style: TextStyle(fontSize: 12)),
                  ),

                  // Shield icon (green, right side) - moved from appbar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield, color: Colors.white, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Timer
              const Text(
                '00:00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Pistol Target (Perfect circle, correct numbering)
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD32F2F), width: 3),
                  ),
                  child: CustomPaint(
                    painter: PistolTargetPainter(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Score displays (almost full width)
              Row(
                children: [
                  Expanded(child: _buildScoreBox('10.00')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScoreBox('10.00')),
                ],
              ),

              const SizedBox(height: 16),

              // Control buttons inside red curved square
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                ),
                child: Column(
                  children: [
                    // First row - 5 buttons
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
                    const SizedBox(height: 8),
                    // Second row - 4 buttons
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

              const SizedBox(height: 16),

              // Navigation controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    onPressed: () {
                      if (_currentShotNumber > 1) {
                        setState(() => _currentShotNumber--);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_currentShotNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() => _currentShotNumber++);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom buttons
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '00:00',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Start timer
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Save session
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBox(String score) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white30, width: 0.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: () {
          // TODO: Handle button press
        },
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// Custom painter for Pistol target
// 10 rings + center = 11 circles
// Numbering: 10 (center), 9, 8, 7, 6, 5, 4, 3, 2, 1 (outer)
// Colors: Rings 1-6 white (including 6), rings 7-10 black, center black
// Only show numbers 1-8 (no 9, 10 displayed)
// Custom painter for Pistol target
// Correct layout: Numbers only on vertical and horizontal center lines (forming a cross)
// Custom painter for Pistol target - CORRECTED
// Custom painter for Pistol target - FINAL CORRECT VERSION
// 10 rings + center dot
// Rings 1-6: White with black separators
// Rings 7-10: Black with white separators
// Custom painter for Pistol target - FINAL VERSION WITH CORRECT CENTER DOT
// 10 rings + center dot (black with white border)
class PistolTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final ringWidth = maxRadius / 10;

    // Draw all 10 rings from outside to inside
    for (int ringNum = 1; ringNum <= 10; ringNum++) {
      final radius = maxRadius - (ringWidth * (ringNum - 1));
      
      // Rings 1-6: White, Rings 7-10: Black
      final isBlackRing = ringNum >= 7;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;
      
      // Draw filled ring
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = fillColor..style = PaintingStyle.fill,
      );
      
      // Draw border
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Draw numbers 1-8 only (not 9 and 10)
    for (int ringNum = 1; ringNum <= 8; ringNum++) {
      final outerRadius = maxRadius - (ringWidth * (ringNum - 1));
      final innerRadius = maxRadius - (ringWidth * ringNum);
      final midRadius = (outerRadius + innerRadius) / 2;

      // Text color: white rings (1-6) = black text, black rings (7-8) = white text
      final textColor = ringNum <= 6 ? Colors.black : Colors.white;

      // Draw at 4 positions: top, right, bottom, left
      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }

    // Center dot: Black with white border (larger radius)
    final centerDotRadius = 6.0; // Increased from 3 to 6
    
    // Draw black center
    canvas.drawCircle(
      center,
      centerDotRadius,
      Paint()..color = Colors.black..style = PaintingStyle.fill,
    );
    
    // Draw white border
    canvas.drawCircle(
      center,
      centerDotRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
