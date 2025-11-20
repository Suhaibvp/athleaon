import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/photo_data.dart';
import '../models/session_notes.dart';

class PdfService {
  static const double _marginSize = 10.0;
  static const double _borderWidth = 1.5;

  // Capture widget as image
  static Future<Uint8List> captureWidget(GlobalKey key) async {
    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Error capturing widget: $e');
    }
  }

  // Load image from local path
  static Future<Uint8List?> loadImageFromPath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error loading image from path: $e');
      return null;
    }
  }

  // Generate PDF
// Generate PDF
static Future<void> generateAndSharePdf({
  required String sessionName,
  required String studentName,
  required String eventType,
  required double totalScore,
  required Duration totalTime,
  required String notes,
  required List<GlobalKey> groupKeys,
  required Map<String, dynamic> summaryData,
  required String coachName,
  required List<PhotoData> attachedImages,
  required int totalScoreWithoutDecimal,
  required List<SessionNote>? notesList
}) async {
  try {
    final pdf = pw.Document();
    int pageNumber = 1;

    // Page 1: Summary
await _addSummaryPage(
  pdf,
  sessionName,
  studentName,
  eventType,
  totalScore,
  totalTime,
  notes,
  summaryData,
  pageNumber,
  coachName,
  totalScoreWithoutDecimal,
  notesList, // ✅ Pass notes list
);
    pageNumber++;
  await _addFeedbackGuidePage(pdf, pageNumber, studentName, coachName);
  pageNumber++;
    // ✅ Group photos by shot group for easy access
    final groupedPhotos = <int, List<PhotoData>>{};
    for (final photo in attachedImages) {
      groupedPhotos.putIfAbsent(photo.shotGroup, () => []).add(photo);
    }

    // ✅ Pages 2+: Group cards + their images
    for (int i = 0; i < groupKeys.length; i++) {
      try {
        // Add group card
        if (groupKeys[i].currentContext != null) {
          final groupImageBytes = await captureWidget(groupKeys[i]);
          final groupImage = pw.MemoryImage(groupImageBytes);

          await _addGroupPage(pdf, groupImage, pageNumber, studentName, coachName);
          pageNumber++;
        }

        // ✅ Add images for this group immediately after the group card
        final groupNumber = i + 1; // Group numbers are 1-indexed
        if (groupedPhotos.containsKey(groupNumber)) {
          final groupPhotos = groupedPhotos[groupNumber]!;
          
          // Add photos 2 per page
          for (int j = 0; j < groupPhotos.length; j += 2) {
            final firstPhoto = groupPhotos[j];
            final secondPhoto = j + 1 < groupPhotos.length ? groupPhotos[j + 1] : null;

            // Load images from local paths
            final firstImageBytes = await loadImageFromPath(firstPhoto.localPath);
            final secondImageBytes = secondPhoto != null 
                ? await loadImageFromPath(secondPhoto.localPath) 
                : null;

            // Add image page for this group
            await _addGroupImagesPage(
              pdf,
              groupNumber,
              firstPhoto,
              firstImageBytes,
              secondPhoto,
              secondImageBytes,
              pageNumber,
              studentName,
              coachName,
            );
            pageNumber++;
          }
        }
      } catch (e) {
        print('Error capturing group $i: $e');
      }
    }

    // Cumulative Target Page
    await _addCumulativeTargetPage(pdf, summaryData, pageNumber, studentName, coachName);
    pageNumber++;

    // Shots Table Page
    await _addShotsTablePage(pdf, summaryData, pageNumber, studentName, coachName);
    pageNumber++;

    // Share PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${sessionName}_Report.pdf',
    );
  } catch (e) {
    throw Exception('Error generating PDF: $e');
  }
}

// ✅ NEW: Add images page for a specific group
static Future<void> _addGroupImagesPage(
  pw.Document pdf,
  int groupNumber,
  PhotoData firstPhoto,
  Uint8List? firstImageBytes,
  PhotoData? secondPhoto,
  Uint8List? secondImageBytes,
  int pageNumber,
  String studentName,
  String coachName,
) async {
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(_marginSize),
          child: _buildMarginBorder(
            pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                children: [
                  _buildPageHeader(studentName, coachName),
                  pw.SizedBox(height: 8),
                  pw.Divider(height: 1),
                  pw.SizedBox(height: 8),

                  // Shot Group Label
                  pw.Text(
                    'Group $groupNumber - Photos',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),

                  // First Image
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _buildPdfImageFromBytes(firstImageBytes),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            firstPhoto.note.isNotEmpty ? firstPhoto.note : 'No note',
                            style: const pw.TextStyle(fontSize: 9),
                            maxLines: 3,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  // Second Image (if exists)
                  if (secondPhoto != null && secondImageBytes != null)
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: _buildPdfImageFromBytes(secondImageBytes),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              secondPhoto.note.isNotEmpty ? secondPhoto.note : 'No note',
                              style: const pw.TextStyle(fontSize: 9),
                              maxLines: 3,
                              overflow: pw.TextOverflow.clip,
                            ),
                          ],
                        ),
                      ),
                    ),

                  pw.SizedBox(height: 8),
                  pw.Divider(height: 1),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
// In pdf_service.dart
static Future<void> buildPdfDocument({
  required pw.Document pdf,
  required String sessionName,
  required String studentName,
  required String coachName,
  required String eventType,
  required double totalScore,
  required int totalScoreWithoutDecimal,
  required Duration totalTime,
  required String notes,
  required List<GlobalKey> groupKeys,
  required Map<String, dynamic> summaryData,
  required List<PhotoData> attachedImages,
  required List<SessionNote>? notesList

}) async {
  int pageNumber = 1;

  // Add summary page
await _addSummaryPage(
  pdf,
  sessionName,
  studentName,
  eventType,
  totalScore,
  totalTime,
  notes,
  summaryData,
  pageNumber,
  coachName,
  totalScoreWithoutDecimal,
  notesList, // ✅ Pass notes list
);
  pageNumber++;
  await _addFeedbackGuidePage(pdf, pageNumber, studentName, coachName);
  pageNumber++;
  // Add group pages
  final groupedPhotos = <int, List<PhotoData>>{};
  for (final photo in attachedImages) {
    groupedPhotos.putIfAbsent(photo.shotGroup, () => []).add(photo);
  }

  for (int i = 0; i < groupKeys.length; i++) {
    try {
      if (groupKeys[i].currentContext != null) {
        final groupImageBytes = await captureWidget(groupKeys[i]);
        final groupImage = pw.MemoryImage(groupImageBytes);
        await _addGroupPage(pdf, groupImage, pageNumber, studentName, coachName);
        pageNumber++;
      }

      final groupNumber = i + 1;
      if (groupedPhotos.containsKey(groupNumber)) {
        final groupPhotos = groupedPhotos[groupNumber]!;
        for (int j = 0; j < groupPhotos.length; j += 2) {
          final firstPhoto = groupPhotos[j];
          final secondPhoto = j + 1 < groupPhotos.length ? groupPhotos[j + 1] : null;
          final firstImageBytes = await loadImageFromPath(firstPhoto.localPath);
          final secondImageBytes = secondPhoto != null 
              ? await loadImageFromPath(secondPhoto.localPath) 
              : null;
          await _addGroupImagesPage(
            pdf, groupNumber, firstPhoto, firstImageBytes,
            secondPhoto, secondImageBytes, pageNumber, studentName, coachName,
          );
          pageNumber++;
        }
      }
    } catch (e) {
      print('Error capturing group $i: $e');
    }
  }

  await _addCumulativeTargetPage(pdf, summaryData, pageNumber, studentName, coachName);
  pageNumber++;
  await _addShotsTablePage(pdf, summaryData, pageNumber, studentName, coachName);
}


  // Add attached images pages (grouped by shot group)
  static Future<void> _addAttachedImagesPages(
    pw.Document pdf,
    List<PhotoData> attachedImages,
    int startPageNumber,
    String studentName,
    String coachName,
  ) async {
    try {
      int pageNumber = startPageNumber;

      // Group photos by shot group
      final groupedPhotos = <int, List<PhotoData>>{};
      for (final photo in attachedImages) {
        groupedPhotos.putIfAbsent(photo.shotGroup, () => []).add(photo);
      }

      // Process each shot group
      for (final groupEntry in groupedPhotos.entries) {
        final shotGroup = groupEntry.key;
        final groupPhotos = groupEntry.value;

        // Process photos 2 per page
        for (int i = 0; i < groupPhotos.length; i += 2) {
          final firstPhoto = groupPhotos[i];
          final secondPhoto = i + 1 < groupPhotos.length ? groupPhotos[i + 1] : null;

          // Load images from local paths
          final firstImageBytes = await loadImageFromPath(firstPhoto.localPath);
          final secondImageBytes = secondPhoto != null 
              ? await loadImageFromPath(secondPhoto.localPath) 
              : null;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(_marginSize),
                  child: _buildMarginBorder(
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Column(
                        children: [
                          _buildPageHeader(studentName, coachName),
                          pw.SizedBox(height: 8),
                          pw.Divider(height: 1),
                          pw.SizedBox(height: 8),

                          // Shot Group Label
                          pw.Text(
                            'Shot Group $shotGroup',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 8),

                          // First Image
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Expanded(
                                    child: _buildPdfImageFromBytes(firstImageBytes),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    firstPhoto.note.isNotEmpty ? firstPhoto.note : 'No note',
                                    style: const pw.TextStyle(fontSize: 9),
                                    maxLines: 3,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          pw.SizedBox(height: 12),

                          // Second Image (if exists)
                          if (secondPhoto != null && secondImageBytes != null)
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(8),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: PdfColors.grey300),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Expanded(
                                      child: _buildPdfImageFromBytes(secondImageBytes),
                                    ),
                                    pw.SizedBox(height: 6),
                                    pw.Text(
                                      secondPhoto.note.isNotEmpty ? secondPhoto.note : 'No note',
                                      style: const pw.TextStyle(fontSize: 9),
                                      maxLines: 3,
                                      overflow: pw.TextOverflow.clip,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          pw.SizedBox(height: 8),
                          pw.Divider(height: 1),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                              pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          pageNumber++;
        }
      }
    } catch (e) {
      print('Error adding attached images pages: $e');
      throw Exception('Error adding attached images pages: $e');
    }
  }

  // Helper to build PDF image from bytes
  static pw.Widget _buildPdfImageFromBytes(Uint8List? imageData) {
    try {
      if (imageData == null || imageData.isEmpty) {
        return pw.Center(
          child: pw.Container(
            width: double.infinity,
            height: double.infinity,
            color: PdfColors.grey100,
            child: pw.Center(
              child: pw.Text(
                'Image not found',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ),
        );
      }

      return pw.Container(
        width: double.infinity,
        height: double.infinity,
        color: PdfColors.grey100,
        child: pw.Center(
          child: pw.Image(
            pw.MemoryImage(imageData),
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    } catch (e) {
      print('Error building PDF image: $e');
      return pw.Center(
        child: pw.Text(
          'Failed to load image',
          style: const pw.TextStyle(fontSize: 10),
        ),
      );
    }
  }

  // Helper: Build margin border box
  static pw.Widget _buildMarginBorder(pw.Widget child) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: _borderWidth),
      ),
      child: child,
    );
  }

  // Helper: Build page header
  static pw.Widget _buildPageHeader(String studentName, String coachName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Student: $studentName', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Coach: $coachName', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  // Add summary page
static Future<void> _addSummaryPage(
  pw.Document pdf,
  String sessionName,
  String studentName,
  String eventType,
  double totalScore,
  Duration totalTime,
  String notes, // Keep for backwards compatibility
  Map<String, dynamic> summaryData,
  int pageNumber,
  String coachName,
  int totalGroupScoreWithoutDecimal,
  List<SessionNote>? notesList, // ✅ Add this parameter
) async {
  try {
    pw.MemoryImage? shootmetrixImage;
    pw.MemoryImage? athleonImage;

    try {
      final shootmetrixData = await rootBundle.load('assets/images/logo.png');
      shootmetrixImage = pw.MemoryImage(shootmetrixData.buffer.asUint8List());
    } catch (e) {
      shootmetrixImage = null;
    }

    try {
      final athleonData = await rootBundle.load('assets/images/athleon.png');
      athleonImage = pw.MemoryImage(athleonData.buffer.asUint8List());
    } catch (e) {
      athleonImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final now = DateTime.now();
          final formattedDate = '${now.day}/${now.month}/${now.year}';
          final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

          return pw.Padding(
            padding: const pw.EdgeInsets.all(_marginSize),
            child: _buildMarginBorder(
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(studentName, coachName),
                    pw.SizedBox(height: 8),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 10),

                    // Logos
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            shootmetrixImage != null
                                ? pw.Image(shootmetrixImage, width: 40, height: 40)
                                : pw.Container(
                                    width: 40,
                                    height: 40,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey400),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    ),
                                    child: pw.Center(
                                      child: pw.Text('[Logo]', style: const pw.TextStyle(fontSize: 8)),
                                    ),
                                  ),
                            pw.SizedBox(width: 8),
                            pw.Text('ShotMetrix', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            athleonImage != null
                                ? pw.Image(athleonImage, width: 80, height: 80)
                                : pw.Container(
                                    width: 80,
                                    height: 80,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: PdfColors.grey400),
                                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    ),
                                    child: pw.Center(
                                      child: pw.Text('[Logo]', style: const pw.TextStyle(fontSize: 8)),
                                    ),
                                  ),
                            pw.SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 12),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 10),

                    // Session Info
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('Coach: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text(coachName, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('Time: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text(formattedTime, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('Date: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text('Student: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text(studentName, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 10),

                    // ✅ UPDATED: Notes Section - Show all notes with timestamps
                    pw.Text('Notes:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    
                    if (notesList != null && notesList.isNotEmpty)
                      // Show all notes in reverse chronological order (latest first)
                      pw.Container(
                        width: double.infinity,
                        constraints: const pw.BoxConstraints(maxHeight: 80),
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: notesList.reversed.map((note) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  // Timestamp
                                  pw.Text(
                                    '${note.timestamp.day}/${note.timestamp.month}/${note.timestamp.year} ${note.timestamp.hour.toString().padLeft(2, '0')}:${note.timestamp.minute.toString().padLeft(2, '0')}',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      color: PdfColors.grey700,
                                      fontStyle: pw.FontStyle.italic,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  // Note text
                                  pw.Text(
                                    note.note,
                                    style: const pw.TextStyle(fontSize: 8),
                                    maxLines: 2,
                                    overflow: pw.TextOverflow.clip,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    else
                      // Fallback to single note field (backwards compatibility)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          notes.isNotEmpty ? notes : 'No notes',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    
                    pw.SizedBox(height: 10),

                    // Summary Stats
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: [
                              pw.Column(
                                children: [
                                  pw.Text(
                                    '${summaryData['totalShots'] ?? 0}',
                                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text('Shots', style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                              pw.Column(
                                children: [
                                  pw.Text(
                                    '${totalGroupScoreWithoutDecimal}(${totalScore.toStringAsFixed(1)})',
                                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text('Score', style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                              pw.Column(
                                children: [
                                  pw.Text(
                                    _formatDurationWithMillis(totalTime),
                                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text('Time', style: const pw.TextStyle(fontSize: 8)),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Divider(height: 1),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: _buildScoreBreakdownForPDF(summaryData),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // Graph
                    if (summaryData['scoreGraphImage'] != null) ...[
                      pw.Text('Score Progress', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: double.infinity,
                        alignment: pw.Alignment.center,
                        child: pw.Image(
                          pw.MemoryImage(summaryData['scoreGraphImage'] as Uint8List),
                          width: 440,
                          height: 100,
                        ),
                      ),
                    ],

                    pw.Spacer(),
                    pw.SizedBox(height: 8),
                    pw.Divider(height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  } catch (e) {
    throw Exception('Error adding summary page: $e');
  }
}

// Add feedback guide page
static Future<void> _addFeedbackGuidePage(
  pw.Document pdf,
  int pageNumber,
  String studentName,
  String coachName,
) async {
  try {
    // Load feedback icon images
    final feedbackIcons = <String, pw.MemoryImage>{};
    final feedbackLabels = {
      'movement': 'Body Movement',
      'stand': 'Standing',
      'sitting': 'Sitting',
      'talk_with_friends': 'Interaction with Coach',
      'random_shoot': 'Weapon Movement',
      'icon_grip (1)': 'GRIP',
      'shoot_tick': 'Perfect Shot',
      'tr': 'Trigger',
      'ft': 'Follow Through',
      'lh': 'Long Hold',
      'dry': 'Dry',
      'cross': 'Cancel',
    };

    // Try to load each feedback icon
    for (final iconId in feedbackLabels.keys) {
      try {
        final iconData = await rootBundle.load('assets/icons/feedback/$iconId.png');
        feedbackIcons[iconId] = pw.MemoryImage(iconData.buffer.asUint8List());
      } catch (e) {
        print('Could not load feedback icon: $iconId');
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(_marginSize),
            child: _buildMarginBorder(
              pw.Padding(
                padding: const pw.EdgeInsets.all(10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(studentName, coachName),
                    pw.SizedBox(height: 8),
                    pw.Divider(height: 1),
                    pw.SizedBox(height: 12),

                    // Page title
                    pw.Center(
                      child: pw.Text(
                        'Feedback Guide',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Center(
                      child: pw.Text(
                        'Visual indicators used throughout this report',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 16),

                    // Feedback icons grid
                    pw.Expanded(
                      child: pw.GridView(
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: feedbackLabels.entries.map((entry) {
                          final iconId = entry.key;
                          final label = entry.value;
                          final icon = feedbackIcons[iconId];

                          return pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                // Icon with dark background
                                if (icon != null)
                                  pw.Container(
                                    width: 44,
                                    height: 44,
                                    padding: const pw.EdgeInsets.all(4),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey900, // ✅ Dark background
                                      borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(6),
                                      ),
                                    ),
                                    child: pw.Image(
                                      icon,
                                      fit: pw.BoxFit.contain,
                                    ),
                                  )
                                else
                                  pw.Container(
                                    width: 44,
                                    height: 44,
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.grey900, // ✅ Dark background for fallback too
                                      borderRadius: const pw.BorderRadius.all(
                                        pw.Radius.circular(6),
                                      ),
                                    ),
                                    child: pw.Center(
                                      child: pw.Text(
                                        iconId.substring(0, 1).toUpperCase(),
                                        style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.white, // ✅ White text on dark bg
                                        ),
                                      ),
                                    ),
                                  ),
                                pw.SizedBox(height: 6),
                                // Label
                                pw.Text(
                                  label,
                                  style: const pw.TextStyle(
                                    fontSize: 9,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                  maxLines: 2,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    pw.SizedBox(height: 12),
                    
                    // Legend explanation
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'How to Read Feedback:',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            '* Each shot in the report may have one or more feedback indicators',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '* These icons help identify specific aspects of technique or performance',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '* Use this guide to understand the feedback throughout the report',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 8),
                    pw.Divider(height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  } catch (e) {
    print('Error adding feedback guide page: $e');
    throw Exception('Error adding feedback guide page: $e');
  }
}


  // Add group page
  static Future<void> _addGroupPage(
    pw.Document pdf,
    pw.MemoryImage groupImage,
    int pageNumber,
    String studentName,
    String coachName,
  ) async {
    try {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(_marginSize),
              child: _buildMarginBorder(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _buildPageHeader(studentName, coachName),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.SizedBox(height: 8),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(groupImage, fit: pw.BoxFit.contain),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      throw Exception('Error adding group page: $e');
    }
  }

  // Add cumulative target page
  static Future<void> _addCumulativeTargetPage(
    pw.Document pdf,
    Map<String, dynamic> summaryData,
    int pageNumber,
    String studentName,
    String coachName,
  ) async {
    try {
      if (summaryData['cumulativeTargetImage'] == null) return;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(_marginSize),
              child: _buildMarginBorder(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _buildPageHeader(studentName, coachName),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.SizedBox(height: 8),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(
                            pw.MemoryImage(summaryData['cumulativeTargetImage'] as Uint8List),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      throw Exception('Error adding cumulative target page: $e');
    }
  }

  // Add shots table page
  static Future<void> _addShotsTablePage(
    pw.Document pdf,
    Map<String, dynamic> summaryData,
    int pageNumber,
    String studentName,
    String coachName,
  ) async {
    try {
      if (summaryData['shotsTableImage'] == null) return;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(_marginSize),
              child: _buildMarginBorder(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Column(
                    children: [
                      _buildPageHeader(studentName, coachName),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.SizedBox(height: 8),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(
                            pw.MemoryImage(summaryData['shotsTableImage'] as Uint8List),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Page $pageNumber', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('ShotMetrix Report', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      throw Exception('Error adding shots table page: $e');
    }
  }

  // Helper: Format duration
  static String _formatDurationWithMillis(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final millis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

  // Helper: Build score breakdown
  static List<pw.Widget> _buildScoreBreakdownForPDF(Map<String, dynamic> summaryData) {
    final shots = summaryData['shots'] as List<dynamic>? ?? [];

    if (shots.isEmpty) {
      return [pw.Text('-', style: const pw.TextStyle(fontSize: 8))];
    }

    final scoreMap = <int, int>{};

    for (var shot in shots) {
      final score = (shot['score'] ?? 0.0) as double;
      final ring = score.toInt();
      scoreMap[ring] = (scoreMap[ring] ?? 0) + 1;
    }

    final sortedEntries = scoreMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return sortedEntries
        .take(5)
        .map((entry) => pw.Text('${entry.key}×${entry.value}', style: const pw.TextStyle(fontSize: 10)))
        .toList();
  }
}
