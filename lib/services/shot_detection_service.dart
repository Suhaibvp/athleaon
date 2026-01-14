// lib/services/shot_detection_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class ShotPosition {
  final double x;
  final double y;
  final double radius;
  
  ShotPosition({
    required this.x,
    required this.y,
    required this.radius,
  });
  
  @override
  String toString() => 'pos(${x.toStringAsFixed(0)},${y.toStringAsFixed(0)}) r:${radius.toStringAsFixed(1)}';
}

class DetectionResult {
  final List<ShotPosition> shots;
  final Uint8List visualizedImage;
  final Uint8List processedImage;
  
  DetectionResult({
    required this.shots,
    required this.visualizedImage,
    required this.processedImage,
  });
}

class ShotDetectionService {
  
  /// Simple approach - heavy erosion to separate blobs
  Future<DetectionResult> detectShotsWithVisualization(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      cv.Mat img = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
      cv.Mat outputImg = img.clone();
      cv.Mat grayImg = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
      
      print('\n========== SHOT DETECTION (EROSION) ==========');
      
      // Threshold
      cv.Mat shotMask = cv.threshold(grayImg, 50.0, 255, cv.THRESH_BINARY).$2;
      
      // HEAVY EROSION to separate touching blobs (shots on lines)
      cv.Mat kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (5, 5));
      cv.Mat eroded = cv.erode(shotMask, kernel, iterations: 3);
      
      // Green overlay on ORIGINAL mask (before erosion)
      cv.Mat greenOverlay = cv.Mat.zeros(img.rows, img.cols, cv.MatType.CV_8UC3);
      greenOverlay.setTo(cv.Scalar(0, 255, 0, 0), mask: shotMask);
      cv.addWeighted(outputImg, 0.6, greenOverlay, 0.4, 0, dst: outputImg);
      
      // Find contours on ERODED mask (separated blobs)
      final contoursResult = cv.findContours(
        eroded,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );
      final contours = contoursResult.$1;
      
      List<ShotPosition> shots = [];
      
      print('Found ${contours.length} separated blobs');
      
      for (int i = 0; i < contours.length; i++) {
        final contour = contours[i];
        final area = cv.contourArea(contour);
        
        // Accept any reasonable size
        if (area > 10) {
          final (center, radius) = cv.minEnclosingCircle(contour);
          final cx = center.x.round();
          final cy = center.y.round();
          
          shots.add(ShotPosition(
            x: cx.toDouble(),
            y: cy.toDouble(),
            radius: radius,
          ));
          
          print('  Shot ${shots.length}: pos=($cx,$cy) area=${area.toInt()}');
          
          // RED DOT
          cv.circle(
            outputImg,
            cv.Point(cx, cy),
            8,
            cv.Scalar(0, 0, 255, 0),
            thickness: -1,
          );
          
          // Number
          cv.putText(
            outputImg,
            '${shots.length}',
            cv.Point(cx + 20, cy + 10),
            cv.FONT_HERSHEY_SIMPLEX,
            1.5,
            cv.Scalar(0, 0, 0, 0),
            thickness: 8,
          );
          cv.putText(
            outputImg,
            '${shots.length}',
            cv.Point(cx + 20, cy + 10),
            cv.FONT_HERSHEY_SIMPLEX,
            1.5,
            cv.Scalar(255, 255, 255, 0),
            thickness: 4,
          );
        }
      }
      
      print('\n✅ Total shots: ${shots.length}');
      print('==========================================\n');
      
      // Encode
      final visualResult = cv.imencode('.jpg', outputImg);
      final visualizedBytes = visualResult.$2;
      
      // Show eroded mask to see what algorithm uses
      cv.Mat maskViz = cv.cvtColor(eroded, cv.COLOR_GRAY2BGR);
      final maskResult = cv.imencode('.jpg', maskViz);
      final processedBytes = maskResult.$2;
      
      // Cleanup
      img.dispose();
      outputImg.dispose();
      grayImg.dispose();
      shotMask.dispose();
      kernel.dispose();
      eroded.dispose();
      greenOverlay.dispose();
      maskViz.dispose();
      
      return DetectionResult(
        shots: shots,
        visualizedImage: visualizedBytes,
        processedImage: processedBytes,
      );
      
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('$stackTrace');
      final bytes = await imageFile.readAsBytes();
      return DetectionResult(
        shots: [],
        visualizedImage: bytes,
        processedImage: bytes,
      );
    }
  }
}
