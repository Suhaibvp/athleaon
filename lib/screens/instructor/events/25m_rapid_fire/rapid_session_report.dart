import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../../widgets/shooting_feedback_icons.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../services/pdf_drawing_service.dart';
import 'dart:math' show max;
// ✅ Add this import
import 'package:flutter/services.dart';
import '../../../../models/missed_shoot.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../services/pdf_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../../models/attach_image.dart';
import '../../../../models/photo_data.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../services/session_service.dart';
import '../../../../models/attached_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';
import '../../../../models/session_notes.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../models/precision_shot_group.dart';


class RapidSessionReportScreen extends StatefulWidget {
  final PrecisionSessionReportData reportData;
  final String sessionId;
  final int shotsPerTarget;
  final List<PhotoData> photos; // Add photos list

  const RapidSessionReportScreen({
    Key? key,
    required this.reportData,
    required this.sessionId,
    required this.shotsPerTarget,
    this.photos = const [], // default empty list
  }) : super(key: key);

  @override
  State<RapidSessionReportScreen> createState() => _RapidSessionReportScreen();
  
}

class _RapidSessionReportScreen extends State<RapidSessionReportScreen> {
  // ✅ Global keys for each group
  late List<GlobalKey> _groupKeys;
  late GlobalKey _scoreGraphKey;
  late GlobalKey _cumulativeTargetKey;
  late GlobalKey _shotsTableKey;
  List<AttachedImage> _attachedImages = []; // ✅ Store attached images
// In SessionReportScreen State
  List<AttachedFile> attachedFiles = [];
  bool _isGeneratingPdf = false;


  @override
  void initState() {
    super.initState();
    // Initialize keys for each group
    final groupCount = widget.reportData.shotGroups?.length ?? 0;
    _groupKeys = List.generate(groupCount, (index) => GlobalKey());
    _scoreGraphKey = GlobalKey();
      _cumulativeTargetKey = GlobalKey();  // ✅ NEW
  _shotsTableKey = GlobalKey();  
  _loadExistingFiles();
  }

  Future<void> _loadExistingFiles() async {
  try {
    final files = await SessionService().getSessionFiles(widget.sessionId);
    setState(() {
      attachedFiles = files;
    });
  } catch (e) {
    print('Error loading attached files: $e');
  }
}
// ✅ NEW METHOD: Build invisible cumulative target
// Update buildInvisibleCumulativeTarget
Widget buildInvisibleCumulativeTarget() {
  // FIXED: Filter shots - exclude malfunction placeholders, include retry shots
  final displayShots = <Map<String, dynamic>>[];
  
  final groups = widget.reportData.shotGroups ?? [];
  
  for (int groupIndex = 0; groupIndex < 6; groupIndex++) {
    // Check if retry exists for this group
    final retryGroup = groups.firstWhere(
      (g) => g.groupNumber == groupIndex + 1 && g.isRetry == true,
      orElse: () => PrecisionShotGroup(
        groupNumber: 0,
        groupTime: Duration.zero,
        shots: [],
      ),
    );
    
    if (retryGroup.groupNumber > 0 && retryGroup.shots.isNotEmpty) {
      // Use retry shots
      displayShots.addAll(retryGroup.shots.map((shot) => {
        'x': shot.position.dx,
        'y': shot.position.dy,
        'score': shot.score,
        'time': shot.shotTime.inMilliseconds,
        'feedback': shot.feedback.toList(),
        'ring': shot.ringNumber,
      }));
    } else {
      // Use original shots from shotGroups (which already filters malfunction placeholders)
      final originalGroup = groups.firstWhere(
        (g) => g.groupNumber == groupIndex + 1 && g.isRetry != true,
        orElse: () => PrecisionShotGroup(
          groupNumber: 0,
          groupTime: Duration.zero,
          shots: [],
        ),
      );
      
      if (originalGroup.groupNumber > 0) {
        displayShots.addAll(originalGroup.shots.map((shot) => {
          'x': shot.position.dx,
          'y': shot.position.dy,
          'score': shot.score,
          'time': shot.shotTime.inMilliseconds,
          'feedback': shot.feedback.toList(),
          'ring': shot.ringNumber,
        }));
      }
    }
  }

  return RepaintBoundary(
    key: _cumulativeTargetKey,
    child: Material(
      color: Colors.white,
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Colors.black,
        ),
        child: Container(
          color: const Color.fromARGB(255, 255, 255, 255),
          width: 600,
          height: 450,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: CustomPaint(
                        painter: _getTargetPainter(displayShots),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All Shots',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


// UPDATED: Build invisible shots table with sighting shots
Widget buildInvisibleShotsTable() {
  return RepaintBoundary(
    key: _shotsTableKey,
    child: Material(
      color: const Color(0xFF1A1A1A),
      child: DefaultTextStyle(
        style: const TextStyle(
          decoration: TextDecoration.none,
          color: Colors.white,
        ),
        child: Container(
          color: const Color(0xFF1A1A1A),
          width: 1400,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'Complete Shots Table',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // NEW: Sighting Shots Section (if exists)
              if (widget.reportData.sightingShots != null &&
                  widget.reportData.sightingShots!.isNotEmpty) ...[
                // Sighting header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SIGHTING SHOTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Shot #',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Score',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Time',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Feedback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Sighting shots rows
                ...widget.reportData.sightingShots!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final shot = entry.value;
                  return buildPdfShotRow(shot, index + 1, isSighting: true);
                }).toList(),

                const SizedBox(height: 16),

                // Divider
                Container(
                  height: 2,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 16),

                // Actual session header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTUAL SESSION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Shot #',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Score',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Feedback',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ROWS - Now includes missed shots
              ..._buildTableRowsForPDF(),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _addImage() async {
  final ImagePicker picker = ImagePicker();
  
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image != null) {
    final bytes = await image.readAsBytes();
    
    if (!mounted) return;
    
    // ✅ Show dialog to add title and notes
    showDialog(
      context: context,
      builder: (ctx) => _buildImageAnnotationDialog(bytes),
    );
  }
}

Widget _buildImageAnnotationDialog(Uint8List imageData) {
  final notesController = TextEditingController();

  return AlertDialog(
    backgroundColor: const Color(0xFF2A2A2A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: const Text(
      'Add Image Notes',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Image Preview
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD32F2F)),
            ),
            child: Image.memory(
              imageData,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          
          // ✅ SINGLE input field - Notes with heading inside
          TextField(
            controller: notesController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add notes or heading\n(e.g., "Target Photo" or "Good grouping achieved")',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD32F2F)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFD32F2F),
                  width: 2,
                ),
              ),
            ),
            cursorColor: const Color(0xFFD32F2F),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(
          'Cancel',
          style: TextStyle(color: Colors.white70),
        ),
      ),
      ElevatedButton(
        onPressed: () {
          setState(() {
            _attachedImages.add(AttachedImage(
              imageId: DateTime.now().millisecondsSinceEpoch.toString(),
              imageData: imageData,
              title: 'Image ${_attachedImages.length + 1}', // ✅ Auto-generated title
              notes: notesController.text.isEmpty 
                  ? 'No notes' 
                  : notesController.text,
            ));
          });
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
        ),
        child: const Text(
          'Add Image',
          style: TextStyle(color: Colors.white),
        ),
      ),
    ],
  );
}

// ✅ UPDATED METHOD: Build invisible shots table (FULL BLACK BACKGROUND)
// NEW: Build sighting shots table
List<Widget> buildSightingShotsTable() {
  if (widget.reportData.sightingShots == null ||
      widget.reportData.sightingShots!.isEmpty) return [];

  final rows = <Widget>[];
  for (int i = 0; i < widget.reportData.sightingShots!.length; i++) {
    final shot = widget.reportData.sightingShots![i];
    final score = (shot['score'] ?? 0.0) as double;
    final shotTimeMs = (shot['time'] as int?) ?? 0;
    final shotTime = Duration(milliseconds: shotTimeMs);
    final feedbackList = (shot['feedback'] as List?)?.cast<String>() ?? [];
    
    // ✅ Extract environmental data
    final light = shot['light'] as String?;
    final wind = shot['wind'] as String?;
    final climate = shot['climate'] as String?;

    rows.add(
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Shot number
            Expanded(
              flex: 1,
              child: Text(
                'S${i + 1}', // S for Sighting
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Score
            Expanded(
              flex: 1,
              child: Text(
                score.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            // Time
            Expanded(
              flex: 1,
              child: Text(
                _formatDurationWithMillis(shotTime),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            // ✅ Light
            Expanded(
              flex: 1,
              child: Text(
                _getLightIcon(light),
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // ✅ Wind
            Expanded(
              flex: 1,
              child: Text(
                _getWindIcon(wind),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // ✅ Climate
            Expanded(
              flex: 1,
              child: Text(
                _getClimateIcon(climate),
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Feedback
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: feedbackList.isEmpty
                    ? const Text('-',
                        style: TextStyle(color: Colors.white, fontSize: 12))
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: feedbackList.map((feedbackId) {
                    return ShootingFeedbackIcons.buildDisplayIcon(
                      iconId: feedbackId,
                      size: 16,
                      isSelected: false, // Don't highlight in reports
                    );
                  }).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return rows;
}


List<Widget> _buildTableRowsForPDF() {
  final rows = <Widget>[];
  
  // Get all missed shots
  final List<MissedShot> allMissedShots = widget.reportData.missedShots ?? [];
  
  // Create a map of shot number -> list of missed shots
  final Map<int, List<MissedShot>> missedShotMap = {};
  for (var missed in allMissedShots) {
    if (!missedShotMap.containsKey(missed.shotNumber)) {
      missedShotMap[missed.shotNumber] = [];
    }
    missedShotMap[missed.shotNumber]!.add(missed);
  }
  
  int currentShotNumber = 1;
  
  for (int i = 0; i < widget.reportData.shots.length; i++) {
    final shot = widget.reportData.shots[i];
    
    // ✅ First, display all missed shots for THIS shot number
    if (missedShotMap.containsKey(currentShotNumber)) {
      for (var missed in missedShotMap[currentShotNumber]!) {
        rows.add(_buildPdfMissedShotRow(
          missed.shotNumber,
          List<String>.from(missed.feedback),
          missed.shotTime,
        ));
      }
    }
    
    // ✅ Then display the normal shot
    rows.add(buildPdfShotRow(shot, currentShotNumber));
    
    // Increment shot number for next iteration
    currentShotNumber++;
  }
  
  return rows;
}

// ✅ Build PDF shot row (normal shot)
// Build PDF shot row (normal shot or sighting shot)
Widget buildPdfShotRow(
  Map<String, dynamic> shot,
  int shotNumber, {
  bool isSighting = false, // NEW parameter
}) {
  final score = (shot['score'] ?? 0.0) as double;
  final shotTimeMs = (shot['time'] as int?) ?? 0;
  final shotTime = Duration(milliseconds: shotTimeMs);
  final feedbackList = (shot['feedback'] as List?)?.cast<String>() ?? [];

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isSighting ? const Color(0xFF1A1A1A) : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: isSighting
            ? Border.all(color: Colors.orange.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          // Shot number
          Expanded(
            flex: 1,
            child: Text(
              isSighting ? 'S$shotNumber' : '$shotNumber',
              style: TextStyle(
                color: isSighting ? Colors.orange : Colors.white,
                fontSize: 12,
                fontWeight: isSighting ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Score
          Expanded(
            flex: 1,
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          // Time
          Expanded(
            flex: 1,
            child: Text(
              _formatDurationWithMillis(shotTime),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          // Feedback
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: feedbackList.isEmpty
                  ? const Text('-',
                      style: TextStyle(color: Colors.white, fontSize: 12))
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: feedbackList.map((feedbackId) {
                    return ShootingFeedbackIcons.buildDisplayIcon(
                      iconId: feedbackId,
                      size: 16,
                      isSelected: false, // Don't highlight in reports
                    );
                  }).toList(),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}


// ✅ Build PDF missed shot row
Widget _buildPdfMissedShotRow(int shotNumber, List<String> feedback, Duration shotTime) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.red[900]?.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[400]!, width: 1),
      ),
      child: Row(
        children: [
          // Shot number with "×" prefix
          Expanded(
            flex: 1,
            child: const Text(
              '×',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Score (-)
          Expanded(
            flex: 1,
            child: const Text(
              '-',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          // Time
          Expanded(
            flex: 1,
            child: Text(
              _formatDurationWithMillis(shotTime),
              style: const TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          // Feedback
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: feedback.isEmpty
                  ? const Text('-', style: TextStyle(color: Colors.white, fontSize: 12))
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: feedback.map((feedbackId) {
                    return ShootingFeedbackIcons.buildDisplayIcon(
                      iconId: feedbackId,
                      size: 16,
                      isSelected: false, // Don't highlight in reports
                    );
                  }).toList(),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
  // ✅ NEW METHOD: Build invisible score graph for PDF capture
Widget _buildInvisibleScoreGraph() {
  final scores = widget.reportData.shots
      .map((shot) => (shot['score'] ?? 0.0) as double)
      .toList();
  final minScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a < b ? a : b);
  final maxScore = scores.isEmpty ? 10.0 : scores.reduce((a, b) => a > b ? a : b);

  return RepaintBoundary(
    key: _scoreGraphKey,
    child: Container(
      color: Colors.white,
      width: 1000,
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value >= 1 && value <= widget.reportData.shots.length) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: Colors.black54, fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.black54, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          minX: 1,
          maxX: widget.reportData.shots.length.toDouble(),
          minY: minScore - 0.5,
          maxY: maxScore + 0.5,
          lineBarsData: [
            LineChartBarData(
              spots: widget.reportData.shots.asMap().entries.map((entry) {
                return FlSpot(
                  (entry.key + 1).toDouble(),
                  (entry.value['score'] ?? 0.0).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: const Color(0xFFD32F2F),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: const Color(0xFFD32F2F),
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFD32F2F).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

List<Widget> _buildInvisibleGroupsForCapture() {
  final groups = widget.reportData.shotGroups ?? [];
  if (groups.isEmpty) return [];

  return groups
      .where((group) => group.groupNumber <= 6) // Only show groups 1-6
      .toList() // FIXED: Convert to list first
      .asMap()
      .entries
      .map((entry) {
        final groupIndex = entry.key;
        final group = entry.value;
        
        return RepaintBoundary(
          key: _groupKeys[groupIndex],
          child: Material(
            color: const Color(0xFF1A1A1A),
            child: DefaultTextStyle(
              style: const TextStyle(
                decoration: TextDecoration.none,
                color: Colors.white,
              ),
              child: Container(
                color: const Color(0xFF1A1A1A),
                width: 1200,
                child: buildGroupCard(group, groupIndex),
              ),
            ),
          ),
        );
      })
      .toList();
}


  // ✅ FORMAT DURATION
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatDurationWithMillis(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final millis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

Future<void> _generatePdf() async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF...')),
    );

    await Future.delayed(const Duration(milliseconds: 1000));

    // ✅ Get coach name from Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    String coachName = 'Coach Name';  // Default
    
    if (currentUser != null) {
      try {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userData.exists) {
          final firstName = userData.get('firstName') ?? '';
          final lastName = userData.get('lastName') ?? '';
          coachName = '$firstName $lastName'.trim();
          if (coachName.isEmpty) coachName = 'Coach Name';
        }
      } catch (e) {
        print('Error fetching coach name: $e');
      }
    }

    // Capture images...
    Uint8List? scoreGraphImage;
    Uint8List? cumulativeTargetImage;
    Uint8List? shotsTableImage;

    try {
      if (_scoreGraphKey.currentContext != null) {
        scoreGraphImage = await _captureWidget(_scoreGraphKey);
      }
      if (_cumulativeTargetKey.currentContext != null) {
        cumulativeTargetImage = await _captureWidget(_cumulativeTargetKey);
      }
      if (_shotsTableKey.currentContext != null) {
        shotsTableImage = await _captureWidget(_shotsTableKey);
      }
    } catch (e) {
      print('Error capturing widgets: $e');
    }

    final summaryData = {
      'totalShots': widget.reportData.shots.length,
      'shots': widget.reportData.shots,
      'scoreGraphImage': scoreGraphImage,
      'cumulativeTargetImage': cumulativeTargetImage,
      'shotsTableImage': shotsTableImage,
    };
  final totalScoreWithoutDecimal = widget.reportData.shots.fold<int>(
    0, 
    (sum, shot) => sum + ((shot['score'] as double? ?? 0.0).floor())
  );
    await PdfService.generateAndSharePdf(
      sessionName: widget.reportData.sessionName,
      studentName: widget.reportData.studentName,
      coachName: coachName,  // ✅ Pass it
      eventType: widget.reportData.eventType,
      totalScore: widget.reportData.totalScore,
      totalTime: widget.reportData.totalTime,
      notes: widget.reportData.notes ?? '',
      groupKeys: _groupKeys,
      summaryData: summaryData,
      attachedImages: widget.photos, 
      totalScoreWithoutDecimal: totalScoreWithoutDecimal,
      notesList:widget.reportData.notesList
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF generated successfully!')),
    );
  } catch (e) {
    print('PDF Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}


// ✅ Add this helper method to the screen class
Future<Uint8List> _captureWidget(GlobalKey key) async {
  try {
    RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;

    ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  } catch (e) {
    print('Error capturing widget: $e');
    rethrow;
  }
}


IconData _getFileIcon(String fileType) {
  switch (fileType.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'txt':
      return Icons.text_snippet;
    case 'jpg':
    case 'jpeg':
    case 'png':
      return Icons.image;
    default:
      return Icons.insert_drive_file;
  }
}
// Delete file confirmation dialog
Future<void> _confirmDeleteFile(int fileIndex) async {
  final file = attachedFiles[fileIndex];
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Remove File',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to remove this file from the report?',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(file.fileType),
                  color: const Color(0xFFD32F2F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text(
            'Remove',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    setState(() {
      attachedFiles.removeAt(fileIndex);
    });
    
    // ✅ Update Firestore after deletion
    await SessionService().saveSessionFiles(
      sessionId: widget.sessionId,
      files: attachedFiles,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File removed: ${file.fileName}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    }
  }
}

// Helper method to get shots for display (filters malfunction, includes retry)
List<Map<String, dynamic>> _getDisplayShots() {
  final displayShots = <Map<String, dynamic>>[];
  final groups = widget.reportData.shotGroups ?? [];
  
  for (int groupIndex = 0; groupIndex < 6; groupIndex++) {
    final retryGroup = groups.firstWhere(
      (g) => g.groupNumber == groupIndex + 1 && g.isRetry == true,
      orElse: () => PrecisionShotGroup(groupNumber: 0, groupTime: Duration.zero, shots: []),
    );
    
    if (retryGroup.groupNumber > 0 && retryGroup.shots.isNotEmpty) {
      displayShots.addAll(retryGroup.shots.map((shot) => shot.toMap()));
    } else {
      final originalGroup = groups.firstWhere(
        (g) => g.groupNumber == groupIndex + 1 && g.isRetry != true,
        orElse: () => PrecisionShotGroup(groupNumber: 0, groupTime: Duration.zero, shots: []),
      );
      
      if (originalGroup.groupNumber > 0) {
        displayShots.addAll(originalGroup.shots.map((shot) => shot.toMap()));
      }
    }
  }
  
  return displayShots;
}

@override
Widget build(BuildContext context) {
  final scores = widget.reportData.shots
      .map((shot) => (shot['score'] ?? 0.0) as double)
      .toList();

  final minScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a < b ? a : b);
  final maxScore = scores.isEmpty ? 10.0 : scores.reduce((a, b) => a > b ? a : b);

  final totalScore = widget.reportData.shots.fold<double>(
      0, (sum, shot) => sum + ((shot['score'] as double?) ?? 0));

  final totalScoreWithoutDecimal = widget.reportData.shots.fold<int>(
      0, (sum, shot) => sum + ((shot['score'] as double?) ?? 0.0).floor());

  return Stack(
    children: [
      // MAIN UI (visible)
      PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Scoreboard',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ShootingFeedbackIcons.buildAppIcon(),
              ),
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NOTES SECTION - Display all notes in reverse chronological order
                    if (widget.reportData.notesList != null &&
                        widget.reportData.notesList!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.note_alt_outlined,
                                  color: Color(0xFFD32F2F),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Session Notes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD32F2F).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${widget.reportData.notesList!.length} ${widget.reportData.notesList!.length == 1 ? "note" : "notes"}',
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Notes list - Latest first (reversed)
                            ...widget.reportData.notesList!.reversed.map((note) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Timestamp
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('dd MMM yyyy, HH:mm')
                                              .format(note.timestamp),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Note text
                                    Text(
                                      note.note,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      )
                    // Fallback: Show old single note if notesList is empty but notes field exists
                    else if (widget.reportData.notes != null &&
                        widget.reportData.notes!.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                color: Color(0xFFD32F2F), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Instructor Notes',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.reportData.notes!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Summary Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '${widget.reportData.shots.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Shots',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    '$totalScoreWithoutDecimal/${totalScore.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Score',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    _formatDurationWithMillis(
                                        widget.reportData.totalTime),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      //textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._buildScoreBreakdownColumns(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // NEW: SIGHTING SHOTS SECTION
                    if (widget.reportData.sightingShots != null &&
                        widget.reportData.sightingShots!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sighting Header with badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Sighting Shots',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${widget.reportData.sightingShots!.length} shots',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Sighting Stats Container
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange, width: 1),
                            ),
                            child: Column(
                              children: [
                                // Stats Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          '${widget.reportData.sightingShots!.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Shots',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          (widget.reportData.sightingTotalScore ?? 0.0)
                                              .toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Score',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          (widget.reportData.sightingTotalScore != null &&
                                                  widget.reportData.sightingShots!.isNotEmpty
                                              ? (widget.reportData.sightingTotalScore! /
                                                      widget.reportData.sightingShots!.length)
                                                  .toStringAsFixed(1)
                                              : '0.0'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Avg',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Sighting Target
                          // Sighting Target
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 280,
                                  height: 280,
                                  child: CustomPaint(
                                    painter: _getTargetPainter(widget.reportData.sightingShots!), // ✅ NEW METHOD
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Sighting Shots',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                                const SizedBox(height: 16),

                                // Sighting Shots Table
                                _buildTableHeader(),
                                const SizedBox(height: 8),
                                ...buildSightingShotsTable(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Divider with label
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD32F2F),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Actual Session',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),

                    // Score Graph
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.white.withOpacity(0.1),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value >= 1 &&
                                      value <= widget.reportData.shots.length) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: widget.reportData.shots.length.toDouble(),
                          minY: minScore - 0.5,
                          maxY: maxScore + 0.5,
                          lineBarsData: [
                            LineChartBarData(
                              spots: widget.reportData.shots.asMap().entries.map((entry) {
                                return FlSpot(
                                  (entry.key + 1).toDouble(),
                                  (entry.value['score'] ?? 0.0).toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: const Color(0xFFD32F2F),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color(0xFFD32F2F),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFFD32F2F).withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // GROUPS HEADING
                    const Text(
                      'Groups',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // VISIBLE GROUP CARDS (no RepaintBoundary)
              ..._buildVisibleGroupCards(),

              // CUMULATIVE TARGET SECTION
// CUMULATIVE TARGET SECTION
Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Cumulative',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
// In the main build method, update the cumulative target section
Center(
  child: Column(
    children: [
      Container(
        width: 280,
        height: 280,

        child: CustomPaint(
          painter: _getTargetPainter(_getDisplayShots()), // Use filtered shots
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'All Shots',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
),

    ],
  ),
),


              const SizedBox(height: 16),

              // DISPLAY ATTACHED IMAGES
              if (widget.photos.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Attached Images',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.photos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final image = entry.value;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD32F2F)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<File>(
                                future: Future.value(File(image.localPath)),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data!.existsSync()) {
                                    return Image.file(
                                      snapshot.data!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    );
                                  } else if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image,
                                                color: Colors.white54, size: 48),
                                            SizedBox(height: 8),
                                            Text(
                                              'Image not found',
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Notes
                            Text(
                              image.note ?? '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Remove button
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),

              const SizedBox(height: 24),

              // ATTACHED FILES SECTION
              if (attachedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD32F2F), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attached Files',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${attachedFiles.length} files',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...attachedFiles.asMap().entries.map((entry) {
                        final index = entry.key;
                        final file = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(file.fileType),
                                color: const Color(0xFFD32F2F),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.fileName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${(file.fileSize / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.red, size: 20),
                                onPressed: () => _confirmDeleteFile(index),
                                tooltip: 'Remove file',
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ATTACH FILES BUTTON
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: pickFiles,
                  icon: const Icon(Icons.attach_file, color: Color(0xFFD32F2F)),
                  label: const Text(
                    'Attach Files (PDF, TXT, Images)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // SHARE REPORT BUTTON
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: attachedFiles.isEmpty
                      ? _generatePdf
                      : showShareOptionsDialog,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.share, color: Colors.white),
                  label: Text(
                    _isGeneratingPdf
                        ? 'Generating...'
                        : attachedFiles.isEmpty
                            ? 'Share Report'
                            : 'Share Report (${attachedFiles.length} files attached)',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      // INVISIBLE STACK (off-screen, for PDF capture)
      Positioned(
        left: -9999,
        top: -9999,
        child: Column(
          children: [
            ..._buildInvisibleGroupsForCapture(),
            _buildInvisibleScoreGraph(),
            buildInvisibleCumulativeTarget(),
            buildInvisibleShotsTable(),
          ],
        ),
      ),
    ],
  );
}



// ✅ NEW METHOD: Build visible groups (regular display)
// In buildVisibleGroupCards method - filter out the temporary retry group
// FIXED: Correct method name and convert to list first
List<Widget> _buildVisibleGroupCards() {
  final groups = widget.reportData.shotGroups ?? [];
  if (groups.isEmpty) return [];

  return groups
      .where((group) => group.groupNumber <= 6) // Only show groups 1-6
      .toList() // FIXED: Convert to list first
      .asMap()
      .entries
      .map((entry) {
        final groupIndex = entry.key;
        final group = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: buildGroupCard(group, groupIndex),
        );
      })
      .toList();
}



Widget buildGroupCardWithPhotos(PrecisionShotGroup group, int groupIndex) {
  final groupPhotos = widget.photos.where((photo) => photo.shotGroup == group.groupNumber).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Group card
      buildGroupCard(group, groupIndex),

      // Photos section
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with camera button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_a_photo,
                    color: Color(0xFFD32F2F),
                    size: 20,
                  ),
                  onPressed: () => pickImageForGroup(group.groupNumber),
                  tooltip: 'Add photo',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Display existing photos with delete button
            if (groupPhotos.isNotEmpty)
              ...groupPhotos.asMap().entries.map((entry) {
                final photoIndex = entry.key;
                final photo = entry.value;
                final globalPhotoIndex = widget.photos.indexOf(photo); // ✅ Get global index
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                  ),
                  child: Stack( // ✅ Use Stack for delete button overlay
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            child: FutureBuilder<File>(
                              future: Future.value(File(photo.localPath)),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.existsSync()) {
                                  return Image.file(
                                    snapshot.data!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  );
                                } else if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                          SizedBox(height: 8),
                                          Text(
                                            'Image not found',
                                            style: TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          // Note
                          if (photo.note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                photo.note,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // ✅ Delete button overlay
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _confirmDeletePhoto(globalPhotoIndex, group.groupNumber),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Center(
                  child: Text(
                    'No photos yet. Tap the camera icon to add.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}


// Delete photo confirmation dialog
Future<void> _confirmDeletePhoto(int photoIndex, int groupNumber) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Delete Photo',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Are you sure you want to delete this photo from Group $groupNumber?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _deletePhoto(photoIndex);
  }
}

// Delete photo method
Future<void> _deletePhoto(int photoIndex) async {
  try {
    // Delete file from storage
    final photo = widget.photos[photoIndex];
    final file = File(photo.localPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from list
    setState(() {
      widget.photos.removeAt(photoIndex);
    });

    // Update Firestore
    await SessionService().saveSessionImages(
      sessionId: widget.sessionId,
      photos: widget.photos,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo deleted successfully',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting photo: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    }
  }
}


Widget buildGroupCard(PrecisionShotGroup group, int groupIndex) {
  print('building group cards for rapid..');
  
  // Get actual group shots
  final groupShots = group.shots.map((shot) {
    return {
      'x': shot.position.dx,
      'y': shot.position.dy,
      'score': shot.score,
      'time': shot.shotTime.inMilliseconds,
      'feedback': shot.feedback.toList(),
      'ring': shot.ringNumber,
      'light': shot.light,
      'wind': shot.wind,
      'climate': shot.climate,
    };
  }).toList();

  final totalGroupScore = groupShots.fold<double>(0, (sum, shot) => sum + (shot['score'] as double? ?? 0));
  final totalGroupScoreWithoutDecimal = groupShots.fold<int>(0, (sum, shot) => sum + ((shot['score'] as double? ?? 0.0).floor()));

  // Calculate correct shot numbers (groups of 5)
  final startShotNumber = (group.groupNumber - 1) * 5 + 1;
  final endShotNumber = startShotNumber + groupShots.length - 1;

  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: group.isMalfunction 
            ? (group.isRetry ? Colors.green : Colors.orange) 
            : const Color(0xFFD32F2F),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: group.isMalfunction 
                ? (group.isRetry ? Colors.green : Colors.orange) 
                : const Color(0xFFD32F2F),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Group name with status badge
              Row(
                children: [
                  Text(
                    group.groupName ?? 'Group ${group.groupNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (group.isMalfunction) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        group.isRetry ? 'RETRY' : 'MALFUNCTION',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Shot range
              Text(
                groupShots.isEmpty 
                    ? 'No shots' 
                    : 'Shots $startShotNumber-$endShotNumber',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Group Stats
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('${groupShots.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 4),
                      const Text('Shots',
                          style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('$totalGroupScoreWithoutDecimal/${totalGroupScore.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 4),
                      const Text('Score',
                          style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        _formatDurationWithMillis(_calculateIndividualGroupTime(groupIndex)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Time',
                          style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Show message if malfunction without retry
              if (group.isMalfunction && !group.isRetry) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${5 - groupShots.length} shot${5 - groupShots.length > 1 ? 's' : ''} skipped due to malfunction',
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Target
              if (groupShots.isNotEmpty) ...[
                Center(
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Container(
                      child: CustomPaint(
                        painter: _getTargetPainter(groupShots),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Table
                _buildTableHeader(),
                const SizedBox(height: 8),
                ..._buildTableRows(groupShots, (group.groupNumber - 1) * 5),
              ] else ...[
                // No shots (fully malfunctioned group with no retry)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: Text(
                      'Group skipped due to malfunction',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ✅ NEW METHOD: Get the correct target painter based on event type
CustomPainter _getTargetPainter(List<Map<String, dynamic>> shots) {
  final eventType = widget.reportData.eventType;
  
  print("=== DEBUG: eventType = '$eventType'");
  
  if (eventType.contains('25m Sports Pistol Precision') || 
      eventType.contains('Sports Pistol Precision')) {
    print("✅ 25m Precision Pistol matched");
    return ReportPrecisionPistolTargetPainter(shots: shots);
  } else if (eventType.contains('25m Rapid Fire') || 
             eventType.contains('Rapid')) {
    print("✅ 25m Rapid Fire matched");
    return ReportRapidFireTargetPainter(shots: shots);
  } else if (eventType.contains('50m Rifle') || 
             eventType.contains('Rifle 3P')) {
    print("✅ 50m Rifle 3P matched");
    return ReportRifle3PTargetPainter(shots: shots);
  } else if (eventType.contains('Pistol')) {
    print("✅ Default Pistol matched");
    return ReportPistolTargetPainter(shots: shots);
  } else {
    print("❌ Default Rifle matched");
    return ReportRifleTargetPainter(shots: shots);
  }
}


// Add these methods to your SessionReportScreen State:

Future<void> pickImageForGroup(int groupNumber) async {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              captureImageForGroup(groupNumber);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              pickImageFromGalleryForGroup(groupNumber);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> captureImageForGroup(int groupNumber) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,  // ✅ Limit image size
      maxHeight: 1920,
      imageQuality: 85, // ✅ Reasonable quality
    );
    
    if (picked != null) {
      Uint8List bytes = await picked.readAsBytes();
      
      // ✅ Check file size (warn if > 5MB)
      if (bytes.length > 5 * 1024 * 1024) {
        print('Warning: Large image file (${bytes.length ~/ (1024 * 1024)}MB)');
      }
      
      showImageNoteDialog(bytes, groupNumber);
    }
  } catch (e) {
    print('Error capturing image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
    }
  }
}

Future<void> pickImageFromGalleryForGroup(int groupNumber) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,  // ✅ Limit image size
      maxHeight: 1920,
      imageQuality: 85, // ✅ Reasonable quality
    );
    
    if (picked != null) {
      Uint8List bytes = await picked.readAsBytes();
      
      // ✅ Check file size
      if (bytes.length > 5 * 1024 * 1024) {
        print('Warning: Large image file (${bytes.length ~/ (1024 * 1024)}MB)');
      }
      
      showImageNoteDialog(bytes, groupNumber);
    }
  } catch (e) {
    print('Error picking image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}


void showImageNoteDialog(Uint8List imageBytes, int groupNumber) {
  final noteController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('Add Note', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(imageBytes, height: 120),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Note',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD32F2F)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
          onPressed: () async {
            final note = noteController.text;
            await saveImageForGroup(imageBytes, note, groupNumber);
            Navigator.of(context).pop();
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> saveImageForGroup(Uint8List imageBytes, String note, int groupNumber) async {
  try {
    // Save to local storage
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${directory.path}/session_${widget.sessionId}_group_${groupNumber}_$timestamp.jpg';
    
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);

    // Add to photos list
    setState(() {
      widget.photos.add(PhotoData(
        localPath: filePath,
        note: note,
        shotGroup: groupNumber,
      ));
    });

    // Save to Firestore
    await SessionService().saveSessionImages(
      sessionId: widget.sessionId,
      photos: widget.photos,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo added successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving photo: $e')),
    );
  }
}



// Add these methods to your SessionReportScreen State:

Future<void> pickFiles() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );

    if (result != null) {
      for (var file in result.files) {
        if (file.path != null) {
          final fileInfo = AttachedFile(
            filePath: file.path!,
            fileName: file.name,
            fileType: file.extension ?? '',
            fileSize: file.size,
          );
          
          setState(() {
            attachedFiles.add(fileInfo);
          });
        }
      }
      
      // ✅ Save to Firestore after adding files
      await SessionService().saveSessionFiles(
        sessionId: widget.sessionId,
        files: attachedFiles,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.files.length} file(s) attached',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2A2A2A),
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error picking files: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    }
  }
}


void removeAttachedFile(int index) {
  setState(() {
    attachedFiles.removeAt(index);
  });
}

// Show share options dialog
Future<void> showShareOptionsDialog() async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      title: const Text('Share Report', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
            title: const Text('PDF Only', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Share report as PDF', style: TextStyle(color: Colors.white70, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _generatePdf();  // ✅ Changed from _generatePDF() to generatePdf()
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.folder_zip, color: Color(0xFFD32F2F)),
            title: const Text('Bundle (ZIP)', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'PDF + ${attachedFiles.length} file(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            onTap: () {
              Navigator.pop(context);
              _generateAndShareBundle();  // ✅ Also removed underscore if it's named without it
            },
          ),
        ],
      ),
    ),
  );
}

// Generate PDF and share as bundle with attached files
Future<void> _generateAndShareBundle() async {
  try {
    setState(() => _isGeneratingPdf = true);

    // Wait for widgets to render
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate PDF first
    final summaryData = await _captureSummaryData();
    
    // Save PDF to temp file
    final directory = await getTemporaryDirectory();
    final pdfPath = '${directory.path}/${widget.reportData.sessionName}_Report.pdf';
    
    final pdf = await _createPdfDocument(summaryData);
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    // Create ZIP file
    final zipPath = '${directory.path}/${widget.reportData.sessionName}_Bundle.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    
    // Add PDF to zip
    encoder.addFile(pdfFile);
    
    // Add all attached files
    for (var attachedFile in attachedFiles) {
      final file = File(attachedFile.filePath);
      if (await file.exists()) {
        encoder.addFile(file);
      }
    }
    
    encoder.close();

    // Share the ZIP file
    await Share.shareXFiles(
      [XFile(zipPath)],
      subject: '${widget.reportData.sessionName} - Training Report Bundle',
    );

    setState(() => _isGeneratingPdf = false);
  } catch (e) {
    setState(() => _isGeneratingPdf = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error creating bundle: $e')),
    );
  }
}

Future<pw.Document> _createPdfDocument(Map<String, dynamic> summaryData) async {
  // Get coach name
  final currentUser = FirebaseAuth.instance.currentUser;
  String coachName = 'Coach Name';
  
  if (currentUser != null) {
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (userData.exists) {
        final firstName = userData.get('firstName') ?? '';
        final lastName = userData.get('lastName') ?? '';
        coachName = '$firstName $lastName'.trim();
        if (coachName.isEmpty) coachName = 'Coach Name';
      }
    } catch (e) {
      print('Error fetching coach name: $e');
    }
  }

  // Create PDF using your existing PdfService
  // But we need to modify PdfService to return the document instead of sharing it
  final pdf = pw.Document();
    final totalScore = widget.reportData.shots.fold<double>(0, (sum, shot) => sum + (shot['score'] as double? ?? 0));
  final totalScoreWithoutDecimal = widget.reportData.shots.fold<int>(
    0, 
    (sum, shot) => sum + ((shot['score'] as double? ?? 0.0).floor())
  );
  // Call PdfService methods directly to build the PDF
  await PdfService.buildPdfDocument(
    pdf: pdf,
    sessionName: widget.reportData.sessionName,
    studentName: widget.reportData.studentName,
    coachName: coachName,
    eventType: widget.reportData.eventType,
    totalScore: widget.reportData.totalScore,
    totalScoreWithoutDecimal: totalScoreWithoutDecimal,
    totalTime: widget.reportData.totalTime,
    notes: widget.reportData.notes ?? '',
    groupKeys: _groupKeys,
    summaryData: summaryData,
    attachedImages: widget.photos,
    notesList:widget.reportData.notesList,
  );
  
  return pdf;
}

Future<Map<String, dynamic>> _captureSummaryData() async {
  Uint8List? scoreGraphImage;
  Uint8List? cumulativeTargetImage;
  Uint8List? shotsTableImage;

  try {
    if (_scoreGraphKey.currentContext != null) {
      scoreGraphImage = await _captureWidget(_scoreGraphKey);
    }
    if (_cumulativeTargetKey.currentContext != null) {
      cumulativeTargetImage = await _captureWidget(_cumulativeTargetKey);
    }
    if (_shotsTableKey.currentContext != null) {
      shotsTableImage = await _captureWidget(_shotsTableKey);
    }
  } catch (e) {
    print('Error capturing widgets: $e');
  }

  return {
    'totalShots': widget.reportData.shots.length,
    'shots': widget.reportData.shots,
    'scoreGraphImage': scoreGraphImage,
    'cumulativeTargetImage': cumulativeTargetImage,
    'shotsTableImage': shotsTableImage,
  };
}

  // ✅ CALCULATE INDIVIDUAL GROUP TIME
  Duration _calculateIndividualGroupTime(int groupIndex) {
    final groups = widget.reportData.shotGroups;
    if (groups == null || groups.isEmpty || groupIndex >= groups.length) {
      return Duration.zero;
    }

    final currentGroupTime = groups[groupIndex].groupTime;

    if (groupIndex == 0) {
      return currentGroupTime;
    }

    final previousGroupTime = groups[groupIndex - 1].groupTime;
    return currentGroupTime - previousGroupTime;
  }

  // ✅ BUILD TABLE HEADER
Widget _buildTableHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Expanded(
          flex: 1,
          child: Text(
            'Shot#',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          flex: 1,
          child: Text(
            'Score',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          flex: 1,
          child: Text(
            'Time',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // ✅ NEW: Environmental conditions
        const Expanded(
          flex: 1,
          child: Text(
            'L', // Light
            style: TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          flex: 1,
          child: Text(
            'W', // Wind
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          flex: 1,
          child: Text(
            'C', // Climate
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Expanded(
          flex: 2,
          child: Text(
            'Feedback',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}


// Update buildTableRows to handle groups of 5:
List<Widget> _buildTableRows(List<Map<String, dynamic>> shots, int startIndex) {
  final rows = <Widget>[];
  
  // Get all missed shots
  final List<MissedShot> allMissedShots = widget.reportData.missedShots ?? [];
  
  // Create a map of shot number -> list of missed shots
  final Map<int, List<MissedShot>> missedShotMap = {};
  for (var missed in allMissedShots) {
    if (!missedShotMap.containsKey(missed.shotNumber)) {
      missedShotMap[missed.shotNumber] = [];
    }
    missedShotMap[missed.shotNumber]!.add(missed);
  }
  
  int currentShotNumber = startIndex + 1;
  
  for (int i = 0; i < shots.length; i++) {
    final shot = shots[i];
    
    // First, display all missed shots for THIS shot number
    if (missedShotMap.containsKey(currentShotNumber)) {
      for (var missed in missedShotMap[currentShotNumber]!) {
        rows.add(_buildPdfMissedShotRow(
          missed.shotNumber,
          List<String>.from(missed.feedback),
          missed.shotTime,
        ));
      }
    }
    
    // Then display the normal shot
    rows.add(_buildShotRow(shot, currentShotNumber));
    
    // Increment shot number for next iteration
    currentShotNumber++;
  }
  
  return rows;
}


  // ✅ BUILD SHOT ROW
Widget _buildShotRow(Map<String, dynamic> shot, int shotNumber) {
  final shotTime = Duration(milliseconds: shot['time'] ?? 0);
  final feedbackList = (shot['feedback'] as List?)?.cast<String>() ?? [];
  
  // ✅ Extract environmental data
  final light = shot['light'] as String?;
  final wind = shot['wind'] as String?;
  final climate = shot['climate'] as String?;

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        // Shot number
        Expanded(
          flex: 1,
          child: Text(
            '$shotNumber',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        // Score
        Expanded(
          flex: 1,
          child: Text(
            (shot['score'] ?? 0.0).toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        // Time
        Expanded(
          flex: 1,
          child: Text(
            _formatDurationWithMillis(shotTime),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        // ✅ Light
        Expanded(
          flex: 1,
          child: Text(
            _getLightIcon(light),
            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        // ✅ Wind Direction (arrow)
        Expanded(
          flex: 1,
          child: Text(
            _getWindIcon(wind),
            style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        // ✅ Climate
        Expanded(
          flex: 1,
          child: Text(
            _getClimateIcon(climate),
            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        // Feedback
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: feedbackList.isEmpty
                ? const Text(
                    '-',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: feedbackList.map((feedbackId) {
                    return ShootingFeedbackIcons.buildDisplayIcon(
                      iconId: feedbackId,
                      size: 16,
                      isSelected: false, // Don't highlight in reports
                    );
                  }).toList(),
                  ),
          ),
        ),
      ],
    ),
  );
}

// ✅ Helper functions for environmental icons
String _getLightIcon(String? light) {
  if (light == null) return '-';
  switch (light) {
    case 'Bright':
      return 'B';
    case 'Medium':
      return 'M';
    case 'Low':
      return 'L';
    default:
      return '-';
  }
}

String _getWindIcon(String? wind) {
  if (wind == null) return '-';
  switch (wind) {
    case 'N':
      return '↑';
    case 'NE':
      return '↗';
    case 'E':
      return '→';
    case 'SE':
      return '↘';
    case 'S':
      return '↓';
    case 'SW':
      return '↙';
    case 'W':
      return '←';
    case 'NW':
      return '↖';
    case 'NONE':
      return '○';
    default:
      return '-';
  }
}

String _getClimateIcon(String? climate) {
  if (climate == null) return '-';
  switch (climate) {
    case 'Sunny':
      return 'S';
    case 'Cloudy':
      return 'C';
    case 'Rainy':
      return 'R';
    case 'Foggy':
      return 'F';
    default:
      return '-';
  }
}

// ✅ BUILD MISSED SHOT ROW WITH TIME
Widget _buildMissedShotRow(int shotNumber, List<String> feedback, Duration shotTime) {
  return Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.red[900]?.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.red[400]!, width: 1),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            '❌',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 1,
          child: const Text(
            '-',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            _formatDurationWithMillis(shotTime), // ✅ NEW: Display time
            style: const TextStyle(color: Colors.orange, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: feedback.isEmpty
              ? const Text('-', style: TextStyle(color: Colors.white, fontSize: 12))
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: feedback.map((feedbackId) {
                    return ShootingFeedbackIcons.buildDisplayIcon(
                      iconId: feedbackId,
                      size: 16,
                      isSelected: false, // Don't highlight in reports
                    );
                  }).toList(),
                ),
          ),
        ),

      ],
    ),
  );
}


  // ✅ BUILD SCORE BREAKDOWN COLUMNS
  List<Widget> _buildScoreBreakdownColumns() {
    final scoreMap = <int, int>{};

    for (var shot in widget.reportData.shots) {
      final score = shot['score'] ?? 0.0;
      final ring = score.toInt();
      scoreMap[ring] = (scoreMap[ring] ?? 0) + 1;
    }

    final sortedScores = scoreMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final itemsPerColumn = (sortedScores.length / 3).ceil();
    final col1 = sortedScores.take(itemsPerColumn).toList();
    final col2 = sortedScores.skip(itemsPerColumn).take(itemsPerColumn).toList();
    final col3 = sortedScores.skip(itemsPerColumn * 2).toList();

    return [
      Expanded(
        child: Column(
          children: col1.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key} × ${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: Column(
          children: col2.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key} × ${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: Column(
          children: col3.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${entry.key} × ${entry.value}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            );
          }).toList(),
        ),
      ),
    ];
  }
}


// Keep painter classes...
// (Same as before - ReportPistolTargetPainter, ReportRifleTargetPainter, SessionReportData, etc.)

// Data model
class PrecisionSessionReportData {
  final String sessionName;
  final String studentName;
  final List<Map<String, dynamic>> shots;
  final double totalScore;
  final Duration totalTime;
  final String eventType;
  final String? notes; // Keep for backwards compatibility
  final List<SessionNote>? notesList; // ✅ NEW: List of notes with timestamps
  final List<PrecisionShotGroup>? shotGroups;
  final List<MissedShot>? missedShots;
    final List<Map<String, dynamic>>? sightingShots; // Separate list for sighting shots
  final double? sightingTotalScore; // Total score from sighting shots

  

  PrecisionSessionReportData({
    required this.sessionName,
    required this.studentName,
    required this.shots,
    required this.totalScore,
    required this.totalTime,
    required this.eventType,
    this.notes,
    this.notesList, // ✅ NEW
    this.shotGroups,
    this.missedShots,
    this.sightingShots,
    this.sightingTotalScore,
  });
}

// Keep your existing painter classes here

class ReportPrecisionPistolTargetPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;

  ReportPrecisionPistolTargetPainter({required this.shots});
  final double targetSize = 280.0;
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    // Calculate minimum ring from shots
    int minRing = 10;
    if (shots.isNotEmpty) {
      for (var shot in shots) {
        final score = (shot['score'] ?? 10.0) as double;
        final ring = score.floor();
        if (ring > 0 && ring < minRing) {
          minRing = ring;
        }
      }
    }
    
    // ✅ Show TWO extra rings: one for pellet edge, one for safety margin
    final startRing = (minRing - 2).clamp(1, 10);
    
    // ✅ 25m Precision Pistol Target - Ring DIAMETERS in mm
    final Map<int, double> ringDiameters = {
      1: 500.0, 2: 450.0, 3: 400.0, 4: 350.0, 5: 300.0,
      6: 250.0, 7: 200.0, 8: 150.0, 9: 100.0, 10: 50.0,
    };
    
    final outerDiameter = ringDiameters[startRing]!;
    
    // Calculate both scales
    final originalScale = targetSize / 500.0; // Original full target scale
    final scale = targetSize / outerDiameter; // Zoomed scale
    final scaleRatio = scale / originalScale;
    
    // Convert diameters to radii in pixels
    final Map<int, double> ringRadii = {};
    ringDiameters.forEach((ring, diameter) {
      ringRadii[ring] = (diameter / 2) * scale;
    });
    
    final double innerTenRadius = (25.0 / 2.0) * scale;// Inner 10 (25mm radius)

    // Draw rings from startRing to 10
    for (int ringNum = startRing; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 7; // Rings 7-10 are black
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;
      
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = fillColor..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale,
      );
    }

    // Draw numbers
    for (int ringNum = startRing; ringNum <= 9; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;
      
      final textColor = ringNum <= 6 ? Colors.black : Colors.white;

      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
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

    // Draw inner ten
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()..color = Colors.black..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );


    // Draw shots with re-scaled positions
    final pelletRadius = 5.6 / 2 * scale; // 5.6mm for .22 LR
    final totalShots = shots.length;
    
    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];
      
      final originalX = (shot['x'] ?? targetSize / 2) as double;
      final originalY = (shot['y'] ?? targetSize / 2) as double;
      
      final originalCenter = targetSize / 2;
      final offsetX = originalX - originalCenter;
      final offsetY = originalY - originalCenter;
      
      // Apply zoom scale
      final scaledOffsetX = offsetX * scaleRatio;
      final scaledOffsetY = offsetY * scaleRatio;
      
      final position = Offset(
        center.dx + scaledOffsetX,
        center.dy + scaledOffsetY,
      );
      
      // Opacity gradient for shot visibility
      final opacity = totalShots > 1 
          ? 0.65 + (i / (totalShots - 1)) * 0.35 
          : 1.0;
      
      canvas.drawCircle(
        position, 
        pelletRadius, 
        Paint()..color = Colors.red.withOpacity(opacity)..style = PaintingStyle.fill
      );
      
      canvas.drawCircle(
        position, 
        pelletRadius,
        Paint()
          ..color = Colors.black.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReportPistolTargetPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;

  ReportPistolTargetPainter({required this.shots});
  final double targetSize = 280.0;
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    // Calculate minimum ring from shots
    int minRing = 10;
    if (shots.isNotEmpty) {
      for (var shot in shots) {
        final score = (shot['score'] ?? 10.0) as double;
        final ring = score.floor();
        if (ring > 0 && ring < minRing) {
          minRing = ring;
        }
      }
    }
    
    // ✅ Show TWO extra rings: one for pellet edge, one for safety margin
    final startRing = (minRing - 2).clamp(1, 10);
    
    // Define ring diameters
    final Map<int, double> ringDiameters = {
      1: 155.5, 2: 139.5, 3: 123.5, 4: 107.5, 5: 91.5,
      6: 75.5, 7: 59.5, 8: 43.5, 9: 27.5, 10: 11.5,
    };
    
    final outerDiameter = ringDiameters[startRing]!;
    
    // Calculate both scales
    final originalScale = targetSize / 170.0;
    final scale = targetSize / outerDiameter;
    final scaleRatio = scale / originalScale;
    
    final Map<int, double> ringRadii = {
      1: 155.5 / 2 * scale, 2: 139.5 / 2 * scale, 3: 123.5 / 2 * scale,
      4: 107.5 / 2 * scale, 5: 91.5 / 2 * scale, 6: 75.5 / 2 * scale,
      7: 59.5 / 2 * scale, 8: 43.5 / 2 * scale, 9: 27.5 / 2 * scale,
      10: 11.5 / 2 * scale,
    };
    
    final innerTenRadius = 5.0 / 2 * scale;

    // Draw rings
    for (int ringNum = startRing; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 7;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;
      
      canvas.drawCircle(center, radius, Paint()..color = fillColor..style = PaintingStyle.fill);
      canvas.drawCircle(center, radius, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 0.3 * scale);
    }

    // Draw numbers
    for (int ringNum = startRing; ringNum <= 9; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;
      
      final textColor = ringNum >= 7 ? Colors.white : Colors.black;

      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
      }
    }

    // Draw inner ten
    canvas.drawCircle(center, innerTenRadius, Paint()..color = Colors.black..style = PaintingStyle.fill);
    canvas.drawCircle(center, innerTenRadius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.3 * scale);

    // Draw shots with re-scaled positions
    final pelletRadius = 4.5 / 2 * scale;
    final totalShots = shots.length;
    
    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];
      
      final originalX = (shot['x'] ?? targetSize / 2) as double;
      final originalY = (shot['y'] ?? targetSize / 2) as double;
      
      final originalCenter = targetSize / 2;
      final offsetX = originalX - originalCenter;
      final offsetY = originalY - originalCenter;
      
      final scaledOffsetX = offsetX * scaleRatio;
      final scaledOffsetY = offsetY * scaleRatio;
      
      final position = Offset(
        center.dx + scaledOffsetX,
        center.dy + scaledOffsetY,
      );
      
      final opacity = totalShots > 1 
          ? 0.65 + (i / (totalShots - 1)) * 0.35 
          : 1.0;
      
      canvas.drawCircle(
        position, 
        pelletRadius, 
        Paint()..color = Colors.red.withOpacity(opacity)..style = PaintingStyle.fill
      );
      
      canvas.drawCircle(
        position, 
        pelletRadius,
        Paint()
          ..color = Colors.black.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class ReportRifleTargetPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;

  ReportRifleTargetPainter({required this.shots});
  final double targetSize = 280.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);

    // ✅ REMOVED: minRing calculation and startRing logic
    // ✅ Always draw full target from ring 1 to 10
    
    final Map<int, double> ringDiameters = {
      1: 45.5, 2: 40.5, 3: 35.5, 4: 30.5, 5: 25.5,
      6: 20.5, 7: 15.5, 8: 10.5, 9: 5.5, 10: 0.5,
    };

    // ✅ Always use full target scale (no zoom)
    final scale = targetSize / 45.5; // Full target, always

    final Map<int, double> ringRadii = {
      1: 45.5 / 2 * scale, 2: 40.5 / 2 * scale, 3: 35.5 / 2 * scale,
      4: 30.5 / 2 * scale, 5: 25.5 / 2 * scale, 6: 20.5 / 2 * scale,
      7: 15.5 / 2 * scale, 8: 10.5 / 2 * scale, 9: 5.5 / 2 * scale,
      10: 0.5 / 2 * scale,
    };

    // ✅ Draw ALL rings from 1 to 10 (no startRing)
    for (int ringNum = 1; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      final isBlackRing = ringNum >= 4;
      final fillColor = isBlackRing ? Colors.black : Colors.white;
      final borderColor = isBlackRing ? Colors.white : Colors.black;

      canvas.drawCircle(center, radius, Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill);

      canvas.drawCircle(center, radius, Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * scale);
    }

    // ✅ Draw ALL ring numbers from 1 to 9
    for (int ringNum = 1; ringNum <= 9; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;

      final textColor = ringNum >= 4 ? Colors.white : Colors.black;

      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 3 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
      }
    }

    // Center dot
    final centerDotRadius = (0.5 / 2 * scale).clamp(1.5, double.infinity);
    canvas.drawCircle(center, centerDotRadius, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill);

    // ✅ Draw shots - NO SCALING NEEDED (already at correct scale)
    final pelletRadius = 4.5 / 2 * scale;
    final totalShots = shots.length;

    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];

      // ✅ Just use the position directly (no re-scaling)
      final position = Offset(
        shot['x'] ?? targetSize / 2,
        shot['y'] ?? targetSize / 2,
      );

      final opacity = totalShots > 1 
          ? 0.65 + (i / (totalShots - 1)) * 0.35 
          : 1.0;

      canvas.drawCircle(
        position,
        pelletRadius,
        Paint()
          ..color = Colors.red.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        position,
        pelletRadius,
        Paint()
          ..color = Colors.black.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class ReportRifle3PTargetPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;

  ReportRifle3PTargetPainter({required this.shots});
  final double targetSize = 280.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);

    // Find minimum ring from shots (1–10)
    int minRing = 10;
    if (shots.isNotEmpty) {
      for (var shot in shots) {
        final score = (shot['score'] ?? 10.0) as double;
        final ring = score.floor();
        if (ring > 0 && ring < minRing) {
          minRing = ring;
        }
      }
    }

    // Show two extra rings, but never below ring 1
    final startRing = (minRing - 2).clamp(1, 10);

    // 50m Rifle 3P ring diameters (mm)
    final Map<int, double> ringDiameters = {
      10: 10.4,
      9: 26.4,
      8: 42.4,
      7: 58.4,
      6: 74.4,
      5: 90.4,
      4: 106.4,
      3: 122.4,
      2: 138.4,
      1: 154.4,
    };

    final outerDiameter = ringDiameters[startRing]!;

    // Full target vs zoom scale
    final originalScale = targetSize / 154.4; // full 1-ring
    final scale = targetSize / outerDiameter; // zoomed to startRing
    final scaleRatio = scale / originalScale;

    // Radii in pixels
    final Map<int, double> ringRadii = {};
    ringDiameters.forEach((ring, diameter) {
      ringRadii[ring] = (diameter / 2) * scale;
    });

    // ✅ NEW: Black area radius (112.4mm diameter - part of ring 3 to ring 10)
    final blackAreaRadius = (112.4 / 2) * scale;

    // ✅ Draw rings 1–3 FIRST (white with black borders) if in view
    for (int ringNum = startRing; ringNum <= 3 && ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }

    // ✅ Draw BLACK AREA (112.4mm - covers part of ring 3 to ring 10)
    if (blackAreaRadius <= ringRadii[startRing]!) { // Only if black area visible
      canvas.drawCircle(
        center,
        blackAreaRadius,
        Paint()..color = Colors.black..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        blackAreaRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }

    // ✅ Draw rings 4–10 with WHITE borders (on black)
    for (int ringNum = math.max(startRing, 4); ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }

    // ✅ Draw numbers 1–8 with SMART color (black on white, white on black)
    for (int ringNum = startRing; ringNum <= 8; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;
      
      // ✅ Text color based on black area position
      final textColor = (midRadius > blackAreaRadius) ? Colors.black : Colors.white;

      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 6 * scale,
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

    // ✅ Center dot (INNER 10-ring: 5mm diameter white)
    final centerDotRadius = (2.5 * scale).clamp(1.5, double.infinity);
    canvas.drawCircle(
      center,
      centerDotRadius,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      centerDotRadius,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 * scale,
    );

    // Draw shots (re-scaled positions)
    final pelletRadius = 5.6 / 2 * scale; // .22 LR
    final totalShots = shots.length;

    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];

      final originalX = (shot['x'] ?? targetSize / 2) as double;
      final originalY = (shot['y'] ?? targetSize / 2) as double;

      final originalCenter = targetSize / 2;
      final offsetX = originalX - originalCenter;
      final offsetY = originalY - originalCenter;

      final scaledOffsetX = offsetX * scaleRatio;
      final scaledOffsetY = offsetY * scaleRatio;

      final position = Offset(
        center.dx + scaledOffsetX,
        center.dy + scaledOffsetY,
      );

      final opacity = totalShots > 1
          ? 0.65 + (i / (totalShots - 1)) * 0.35
          : 1.0;

      canvas.drawCircle(
        position,
        pelletRadius,
        Paint()
          ..color = Colors.red.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        position,
        pelletRadius,
        Paint()
          ..color = Colors.black.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // ✅ Changed for dynamic shots
}


class ReportRapidFireTargetPainter extends CustomPainter {
  final List<Map<String, dynamic>> shots;

  ReportRapidFireTargetPainter({required this.shots});
  final double targetSize = 280.0;
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(targetSize / 2, targetSize / 2);
    
    // Calculate minimum ring from shots (only rings 5-10 exist)
    int minRing = 10;
    if (shots.isNotEmpty) {
      for (var shot in shots) {
        final score = (shot['score'] ?? 10.0) as double;
        final ring = score.floor();
        if (ring >= 5 && ring < minRing) {
          minRing = ring;
        }
      }
    }
    
    // ✅ Show TWO extra rings: one for pellet edge, one for safety margin
    // But clamp to minimum ring 5 (since this target only has rings 5-10)
    final startRing = (minRing - 2).clamp(5, 10);
    
    // ✅ 25m Rapid Fire Target - Ring DIAMETERS in mm
    final Map<int, double> ringDiameters = {
      10: 100.0,
      9: 160.0,
      8: 220.0,
      7: 280.0,
      6: 340.0,
      5: 400.0,
    };
    
    final outerDiameter = ringDiameters[startRing]!;
    
    // Calculate both scales
    final originalScale = targetSize / 400.0; // Original full target scale
    final scale = targetSize / outerDiameter; // Zoomed scale
    final scaleRatio = scale / originalScale;
    
    // Convert diameters to radii in pixels
    final Map<int, double> ringRadii = {};
    ringDiameters.forEach((ring, diameter) {
      ringRadii[ring] = (diameter / 2) * scale;
    });
    
    final double innerTenRadius = (56.0 / 2.0) * scale;  // Inner 10 ring radius (50mm)

    // ✅ Draw rings (startRing to 10) - ALL BLACK with WHITE borders
    for (int ringNum = startRing; ringNum <= 10; ringNum++) {
      final radius = ringRadii[ringNum]!;
      
      // Fill with black
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black..style = PaintingStyle.fill,
      );
      
      // White border
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale,
      );
    }

    // ✅ Draw numbers in WHITE (since background is black)
    for (int ringNum = startRing; ringNum <= 9; ringNum++) {
      final outerRadius = ringRadii[ringNum]!;
      final innerRadius = ringRadii[ringNum + 1]!;
      final midRadius = (outerRadius + innerRadius) / 2;

      // Place numbers at 4 cardinal positions
      for (int angle in [270, 0, 90, 180]) {
        final radians = angle * math.pi / 180;
        final x = center.dx + midRadius * math.cos(radians);
        final y = center.dy + midRadius * math.sin(radians);

        final textPainter = TextPainter(
          text: TextSpan(
            text: ringNum.toString(),
            style: TextStyle(
              color: Colors.white, // ✅ White text on black background
              fontSize: 12 * scale,
              fontWeight: FontWeight.bold,
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
final Paint linePaint = Paint()
  ..color = Colors.white
  ..strokeWidth = 2.5 * scale
  ..style = PaintingStyle.stroke;

// LEFT Line 2: Ring 7 OUTER edge → shortened inner end
final ring7Radius = ringRadii[5]!;
final innerGap = 95.0 * scale;  // Gap from center side (like Line 2)
final leftInnerEndRadius = ring7Radius - innerGap;  // Inner stop point

canvas.drawLine(
  Offset(center.dx - ring7Radius, center.dy),  // START: Ring 7 outer edge
  Offset(center.dx - leftInnerEndRadius, center.dy),  // END: Inner with gap
  linePaint,
);

// RIGHT line: Full center to ring 5 outer
// ✅ RIGHT LINE: Ring 5 OUTER edge → INNER (same Line 2 style)
final ring5Radius = ringRadii[5]!;
final rightInnerGap = 95.0 * scale;  // Same gap as left (adjust as needed)
final rightInnerEndRadius = ring5Radius - rightInnerGap;

canvas.drawLine(
  Offset(center.dx + ring5Radius, center.dy),    // START: Ring 5 outer edge
  Offset(center.dx + rightInnerEndRadius, center.dy),  // END: Inner with gap
  linePaint,
);


    // ✅ Inner ten (solid black circle with white border)
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()..color = Colors.black..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      innerTenRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale,
    );


    // ✅ Draw shots with re-scaled positions
    final pelletRadius = 5.6 / 2 * scale; // 5.6mm pellet diameter for .22 LR
    final totalShots = shots.length;
    
    for (int i = 0; i < shots.length; i++) {
      final shot = shots[i];
      
      final originalX = (shot['x'] ?? targetSize / 2) as double;
      final originalY = (shot['y'] ?? targetSize / 2) as double;
      
      final originalCenter = targetSize / 2;
      final offsetX = originalX - originalCenter;
      final offsetY = originalY - originalCenter;
      
      // Apply zoom scale
      final scaledOffsetX = offsetX * scaleRatio;
      final scaledOffsetY = offsetY * scaleRatio;
      
      final position = Offset(
        center.dx + scaledOffsetX,
        center.dy + scaledOffsetY,
      );
      
      // Opacity gradient for shot visibility
      final opacity = totalShots > 1 
          ? 0.65 + (i / (totalShots - 1)) * 0.35 
          : 1.0;
      
      // Draw pellet
      canvas.drawCircle(
        position, 
        pelletRadius, 
        Paint()..color = Colors.red.withOpacity(opacity)..style = PaintingStyle.fill
      );
      
      // Draw white outline for visibility on black target
      canvas.drawCircle(
        position, 
        pelletRadius,
        Paint()
          ..color = Colors.white.withOpacity(opacity * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5 * scale
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
