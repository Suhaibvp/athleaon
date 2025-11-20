import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' as math;

/// Service for drawing custom graphics in PDF reports
class PdfDrawingService {
  /// Draw Pistol Target with rings and pellet marks
/// Draw Pistol Target with rings, numbers, and pellet marks
static void drawPistolTarget({
  required PdfGraphics canvas,
  required PdfPoint size,
  required List<Map<String, dynamic>> shots,
}) {
  final center = PdfPoint(size.x / 2, size.y / 2);
  final targetSize = 280.0;
  final visualScale = 1.2;
  final scale = (targetSize / 170.0) * visualScale;

  // ISSF 10m Air Pistol ring radii (in mm, scaled)
  final Map<int, double> ringRadii = {
    1: 155.5 / 2 * scale,
    2: 139.5 / 2 * scale,
    3: 123.5 / 2 * scale,
    4: 107.5 / 2 * scale,
    5: 91.5 / 2 * scale,
    6: 75.5 / 2 * scale,
    7: 59.5 / 2 * scale,
    8: 43.5 / 2 * scale,
    9: 27.5 / 2 * scale,
    10: 11.5 / 2 * scale,
  };

  // Draw rings from outside to inside
  for (int ringNum = 1; ringNum <= 10; ringNum++) {
    final radius = ringRadii[ringNum]!;
    final isBlackRing = ringNum >= 7;

    // Fill color
    canvas.setFillColor(isBlackRing ? PdfColors.black : PdfColors.white);
    canvas.drawEllipse(center.x, center.y, radius, radius);
    canvas.fillPath();

    // Border
    canvas.setStrokeColor(isBlackRing ? PdfColors.white : PdfColors.black);
    canvas.setLineWidth(0.15 * scale);
    canvas.drawEllipse(center.x, center.y, radius, radius);
    canvas.strokePath();
  }

  // Draw inner ten (black center dot)
  final innerTenRadius = 5.0 / 2 * scale;
  canvas.setFillColor(PdfColors.black);
  canvas.drawEllipse(center.x, center.y, innerTenRadius, innerTenRadius);
  canvas.fillPath();

  canvas.setStrokeColor(PdfColors.white);
  canvas.setLineWidth(0.2 * scale);
  canvas.drawEllipse(center.x, center.y, innerTenRadius, innerTenRadius);
  canvas.strokePath();

  // ✅ Draw ring numbers (1-10) positioned around target
  _drawRingNumbers(canvas, center, ringRadii, scale);

  // Draw pellet marks (red dots with white borders)
  final pelletRadius = 4.5 / 2 * scale;

  for (var shot in shots) {
    final shotX = (shot['x'] as double?) ?? center.x;
    final shotY = (shot['y'] as double?) ?? center.y;

    // Red fill
    canvas.setFillColor(PdfColors.red);
    canvas.drawEllipse(shotX, shotY, pelletRadius, pelletRadius);
    canvas.fillPath();

    // White border
    canvas.setStrokeColor(PdfColors.white);
    canvas.setLineWidth(0.2 * scale);
    canvas.drawEllipse(shotX, shotY, pelletRadius, pelletRadius);
    canvas.strokePath();
  }
}

/// Draw Rifle Target with rings, numbers, and pellet marks
static void drawRifleTarget({
  required PdfGraphics canvas,
  required PdfPoint size,
  required List<Map<String, dynamic>> shots,
}) {
  final center = PdfPoint(size.x / 2, size.y / 2);
  final targetSize = 280.0;
  final visualScale = 1.4;
  final scale = (targetSize / 60.0) * visualScale;

  // ISSF 10m Air Rifle ring radii (in mm, scaled)
  final Map<int, double> ringRadii = {
    1: 45.5 / 2 * scale,
    2: 40.5 / 2 * scale,
    3: 35.5 / 2 * scale,
    4: 30.5 / 2 * scale,
    5: 25.5 / 2 * scale,
    6: 20.5 / 2 * scale,
    7: 15.5 / 2 * scale,
    8: 10.5 / 2 * scale,
    9: 5.5 / 2 * scale,
    10: 0.5 / 2 * scale,
  };

  // Draw rings from outside to inside
  for (int ringNum = 1; ringNum <= 10; ringNum++) {
    final radius = ringRadii[ringNum]!;
    final isBlackRing = ringNum >= 4;

    // Fill color
    canvas.setFillColor(isBlackRing ? PdfColors.black : PdfColors.white);
    canvas.drawEllipse(center.x, center.y, radius, radius);
    canvas.fillPath();

    // Border
    canvas.setStrokeColor(isBlackRing ? PdfColors.white : PdfColors.black);
    canvas.setLineWidth(0.15 * scale);
    canvas.drawEllipse(center.x, center.y, radius, radius);
    canvas.strokePath();
  }

  // Draw center dot (white)
  final centerDotRadius = (0.5 / 2 * scale).clamp(1.5, double.infinity);
  canvas.setFillColor(PdfColors.white);
  canvas.drawEllipse(center.x, center.y, centerDotRadius, centerDotRadius);
  canvas.fillPath();

  // ✅ Draw ring numbers (1-10) positioned around target
  _drawRingNumbers(canvas, center, ringRadii, scale);

  // Draw pellet marks (red dots with white borders)
  final pelletRadius = 4.5 / 2 * scale;

  for (var shot in shots) {
    final shotX = (shot['x'] as double?) ?? center.x;
    final shotY = (shot['y'] as double?) ?? center.y;

    // Red fill
    canvas.setFillColor(PdfColors.red);
    canvas.drawEllipse(shotX, shotY, pelletRadius, pelletRadius);
    canvas.fillPath();

    // White border
    canvas.setStrokeColor(PdfColors.white);
    canvas.setLineWidth(0.3 * scale);
    canvas.drawEllipse(shotX, shotY, pelletRadius, pelletRadius);
    canvas.strokePath();
  }
}

// ✅ NEW HELPER: Draw ring numbers around target
// ✅ FIXED: Draw ring numbers around target
static void _drawRingNumbers(
  PdfGraphics canvas,
  PdfPoint center,
  Map<int, double> ringRadii,
  double scale,
) {
  // Position numbers around target at specific angles
  final positions = [
    (1, 0.0),      // Top
    (2, 45.0),
    (3, 90.0),     // Right
    (4, 135.0),
    (5, 180.0),    // Bottom
    (6, 225.0),
    (7, 270.0),    // Left
    (8, 315.0),
    (9, 22.5),
    (10, 67.5),
  ];

  for (var (ringNum, angle) in positions) {
    final radius = ringRadii[ringNum]! * 0.65; // Position at 65% of ring radius
    final radians = (angle * math.pi / 180.0);  // ✅ Use math.pi
    final x = center.x + radius * math.cos(radians);  // ✅ Use math.cos
    final y = center.y + radius * math.sin(radians);  // ✅ Use math.sin

    // White background rectangle for numbers on black rings
    final isBlackRing = ringNum >= 7; // Pistol has 7+ as black
    if (isBlackRing) {
      canvas.setFillColor(PdfColors.white);
      canvas.drawRect(x - 2.5, y - 2.5, 5.0, 5.0);
      canvas.fillPath();
      canvas.setFillColor(PdfColors.black);
    } else {
      canvas.setFillColor(PdfColors.black);
    }
  }
}



  /// Helper: Draw target based on event type
  static void drawTarget({
    required PdfGraphics canvas,
    required PdfPoint size,
    required List<Map<String, dynamic>> shots,
    required String eventType,
  }) {
    if (eventType.toLowerCase() == 'rifle') {
      drawRifleTarget(canvas: canvas, size: size, shots: shots);
    } else {
      drawPistolTarget(canvas: canvas, size: size, shots: shots);
    }
  }



  // ✅ Add this method to PdfDrawingService class

/// Draw Score Line Graph with dynamic min/max Y values
static void drawScoreGraph({
  required PdfGraphics canvas,
  required PdfPoint size,
  required List<Map<String, dynamic>> shots,
  required double minY,
  required double maxY,
}) {

    if (size.x.isNaN || size.x.isInfinite || size.y.isNaN || size.y.isInfinite) {
    return; // Skip drawing if size is invalid
  }

  if (shots.isEmpty) {
    return; // Skip drawing if no shots
  }
  // Graph dimensions and margins
  final graphWidth = size.x - 40.0; // ✅ Convert to double
  final graphHeight = size.y - 40.0; // ✅ Convert to double
  final marginLeft = 20.0;
  final marginBottom = 20.0;
  final originX = marginLeft;
  final originY = marginBottom;

  // Colors
  const axisColor = PdfColors.black;
  const gridColor = PdfColors.grey300;
  const lineColor = PdfColors.red;
  const dotColor = PdfColors.red;

  // ✅ Draw background
  canvas.setFillColor(PdfColors.white);
  canvas.drawRect(originX, originY, graphWidth, graphHeight);
  canvas.fillPath();

  // ✅ Draw border
  canvas.setStrokeColor(axisColor);
  canvas.setLineWidth(1.0);
  canvas.drawRect(originX, originY, graphWidth, graphHeight);
  canvas.strokePath();

  // ✅ Calculate scale factors
  final xScale = graphWidth / (shots.length > 1 ? shots.length - 1 : 1);
  final yRange = maxY - minY;
  final yScale = yRange > 0 ? graphHeight / yRange : graphHeight;

  // ✅ Draw horizontal grid lines
  final gridInterval = _calculateGridInterval(yRange);
  var currentY = (((minY / gridInterval).ceil()) * gridInterval);
  
  while (currentY <= maxY) {
    final normalizedY = currentY - minY;
    final pixelY = originY + (normalizedY * yScale);

    // Grid line
    canvas.setStrokeColor(gridColor);
    canvas.setLineWidth(0.5);
    canvas.moveTo(originX, pixelY);
    canvas.lineTo(originX + graphWidth, pixelY);
    canvas.strokePath();

    currentY += gridInterval;
  }

  // ✅ Draw vertical grid lines
  for (int i = 0; i < shots.length; i++) {
    final pixelX = originX + (i * xScale);
    canvas.setStrokeColor(gridColor);
    canvas.setLineWidth(0.3);
    canvas.moveTo(pixelX, originY);
    canvas.lineTo(pixelX, originY + graphHeight);
    canvas.strokePath();
  }

  // ✅ Draw X and Y axes
  canvas.setStrokeColor(axisColor);
  canvas.setLineWidth(1.5);
  
  // X-axis
  canvas.moveTo(originX, originY);
  canvas.lineTo(originX + graphWidth, originY);
  canvas.strokePath();

  // Y-axis
  canvas.moveTo(originX, originY);
  canvas.lineTo(originX, originY + graphHeight);
  canvas.strokePath();

  // ✅ Draw data points and connecting line
  final List<PdfPoint> points = [];

  for (int i = 0; i < shots.length; i++) {
    final score = (shots[i]['score'] as double?) ?? 0.0;
    final normalizedScore = score - minY;
    
    final pixelX = originX + (i * xScale);
    final pixelY = originY + (normalizedScore * yScale);
    
    points.add(PdfPoint(pixelX, pixelY));
  }

  // Draw line connecting points
  if (points.isNotEmpty) {
    canvas.setStrokeColor(lineColor);
    canvas.setLineWidth(2.0);
    
    for (int i = 0; i < points.length - 1; i++) {
      canvas.moveTo(points[i].x, points[i].y);
      canvas.lineTo(points[i + 1].x, points[i + 1].y);
      canvas.strokePath();
    }
  }

  // ✅ Draw fill area under curve (simplified - draw rectangles)
  if (points.isNotEmpty) {
    canvas.setFillColor(PdfColor.fromInt(0xFFEF5350)); // Light red with opacity effect
    
    for (int i = 0; i < points.length - 1; i++) {
      final x1 = points[i].x;
      final y1 = points[i].y;
      final x2 = points[i + 1].x;
      final y2 = points[i + 1].y;

      // Draw trapezoid under each segment
      canvas.moveTo(x1, originY);
      canvas.lineTo(x1, y1);
      canvas.lineTo(x2, y2);
      canvas.lineTo(x2, originY);
      canvas.closePath();
      canvas.fillPath();
    }
  }

  // Draw data point dots
  final dotRadius = 3.0;
  for (var point in points) {
    canvas.setFillColor(dotColor);
    canvas.drawEllipse(point.x, point.y, dotRadius, dotRadius);
    canvas.fillPath();

    // White border
    canvas.setStrokeColor(PdfColors.white);
    canvas.setLineWidth(1.0);
    canvas.drawEllipse(point.x, point.y, dotRadius, dotRadius);
    canvas.strokePath();
  }
}
static double _calculateGridInterval(double range) {
  if (range <= 0) return 1.0;
  
  final exponent = (math.log(range) / math.ln10).floor();
  final mantissa = range / math.pow(10, exponent);
  
  return math.pow(10, exponent).toDouble() *
      (mantissa < 2 ? 0.5 : mantissa < 5 ? 1 : 2);
}

}
