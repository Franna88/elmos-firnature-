import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/sop_model.dart';
import 'qr_code_service.dart';

class PrintService {
  final QRCodeService _qrCodeService = QRCodeService();

  // Function to generate a print-friendly PDF for an SOP
  Future<void> printSOP(BuildContext context, SOP sop) async {
    debugPrint('Starting PDF generation for SOP #${sop.id} - ${sop.title}');
    try {
      final pdf = pw.Document();

      // Get printer information - skip on web platform which doesn't support it
      if (!kIsWeb) {
        try {
          final printerList = await Printing.listPrinters();
          debugPrint(
              'Available printers: ${printerList.map((p) => p.name).join(', ')}');
        } catch (e) {
          debugPrint('Error listing printers (non-critical): $e');
          // Continue with PDF generation even if printer listing fails
        }
      } else {
        debugPrint('Running on web platform - printer listing skipped');
      }

      // Load the company logo
      debugPrint('Loading company logo...');
      final logoImage = await _loadAssetImage('assets/images/logo.png');
      debugPrint('Logo loaded: ${logoImage != null ? 'success' : 'failed'}');

      // Pre-load all step images
      debugPrint('Loading step images for ${sop.steps.length} steps...');
      final Map<String, pw.MemoryImage?> stepImages = {};
      for (final step in sop.steps) {
        if (step.imageUrl != null && step.imageUrl!.isNotEmpty) {
          stepImages[step.id] = await _loadNetworkImage(step.imageUrl);
          debugPrint(
              'Loaded image for step ${step.id}: ${step.imageUrl != null ? 'success' : 'failed'}');
        }
      }

      // Generate QR code for the SOP
      Uint8List? qrCodeBytes;
      if (sop.qrCodeUrl != null) {
        debugPrint('Using existing QR code URL: ${sop.qrCodeUrl}');
        // Already has QR code URL, use it to generate image
        qrCodeBytes = await _qrCodeService.generateQRImageBytes(sop.id, 200);
      } else {
        debugPrint('Generating new QR code for SOP');
        // Generate new QR code
        qrCodeBytes = await _qrCodeService.generateQRImageBytes(sop.id, 200);
      }

      pw.MemoryImage? qrCodeImage;
      if (qrCodeBytes != null) {
        qrCodeImage = pw.MemoryImage(qrCodeBytes);
        debugPrint('QR code generated successfully');
      } else {
        debugPrint('Failed to generate QR code');
      }

      debugPrint('Building PDF document...');
      // Create a PDF document in landscape orientation
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            // Build all the widgets for the page
            return [
              _buildPDFHeader(sop, logoImage, qrCodeImage),
              pw.SizedBox(height: 10), // Reduced spacing
              _buildSummarySection(sop),
              pw.SizedBox(height: 10), // Reduced spacing
              _buildStepsGrid(sop, stepImages),
            ];
          },
          footer: (context) => _buildFooter(context, sop, qrCodeImage),
        ),
      );

      debugPrint('Showing print dialog...');
      // Print the document using appropriate method based on platform
      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          debugPrint(
              'Generating PDF with format: ${format.width}x${format.height}');
          return pdf.save();
        },
        name: '${sop.title} - SOP #${sop.id}',
        format: PdfPageFormat.a4.landscape,
      );

      debugPrint('Print result: $result');

      if (!result) {
        // If printing failed, show a message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to print or save the document'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF generated successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error generating PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Load an image from assets
  Future<pw.MemoryImage?> _loadAssetImage(String assetPath) async {
    debugPrint('Attempting to load asset image from: $assetPath');
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      debugPrint(
          'Successfully loaded asset image: $assetPath (${bytes.length} bytes)');
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error loading asset image from $assetPath: $e');
      // Try to load a fallback image or continue without an image
      try {
        // Try to load the logo from a simpler path if the main path failed
        final fallbackPath = 'assets/images/logo.png';
        if (fallbackPath != assetPath) {
          debugPrint('Trying fallback path: $fallbackPath');
          final ByteData fallbackData = await rootBundle.load(fallbackPath);
          final Uint8List fallbackBytes = fallbackData.buffer.asUint8List();
          debugPrint('Successfully loaded fallback image: $fallbackPath');
          return pw.MemoryImage(fallbackBytes);
        }
      } catch (fallbackError) {
        debugPrint('Fallback image also failed: $fallbackError');
      }
      return null;
    }
  }

  // Try to load an image from a URL
  Future<pw.MemoryImage?> _loadNetworkImage(String? url) async {
    if (url == null || url.isEmpty) {
      debugPrint('Empty image URL provided');
      return null;
    }

    debugPrint('Attempting to load image from: $url');

    // If it's a data URL, decode it directly
    if (url.startsWith('data:image/')) {
      try {
        final data = url.split(',')[1];
        final bytes = base64Decode(data);
        debugPrint(
            'Successfully decoded data URL image (${bytes.length} bytes)');
        return pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding data URL image: $e');
        return null;
      }
    }

    // Handle network images
    try {
      debugPrint('Fetching network image from: $url');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Network image request timed out: $url');
          throw Exception('Network request timed out');
        },
      );

      if (response.statusCode == 200) {
        debugPrint(
            'Successfully loaded network image: $url (${response.bodyBytes.length} bytes)');
        return pw.MemoryImage(response.bodyBytes);
      } else {
        debugPrint(
            'Failed to load network image. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading network image from $url: $e');
    }
    return null;
  }

  // Build the PDF header with company logo and SOP information - more compact
  pw.Widget _buildPDFHeader(
      SOP sop, pw.MemoryImage? logoImage, pw.MemoryImage? qrCodeImage) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo on the left - smaller
        pw.Container(
          width: 90, // Reduced width
          child: logoImage != null
              ? pw.Image(logoImage)
              : pw.Container(
                  height: 50, // Reduced height
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text("Logo",
                      style: pw.TextStyle(color: PdfColors.grey)),
                ),
        ),

        pw.SizedBox(width: 15), // Reduced spacing

        // SOP info in the middle
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                sop.title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'SOP ID: ${sop.id}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Revision: ${sop.revisionNumber}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Category: ${sop.categoryName ?? 'Uncategorized'}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Last Updated: ${_formatDate(sop.updatedAt)}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),

        // QR Code on the right
        pw.Container(
          width: 80,
          height: 80,
          child: qrCodeImage != null
              ? pw.Image(qrCodeImage)
              : pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text("QR Code",
                      style: pw.TextStyle(color: PdfColors.grey)),
                ),
        ),
      ],
    );
  }

  // Build the summary section with tools, safety requirements, and cautions
  pw.Widget _buildSummarySection(SOP sop) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Required Tools:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.tools.map((tool) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            border: pw.Border.all(color: PdfColors.blue200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(tool,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Safety Requirements:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.safetyRequirements.map((safety) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red50,
                            border: pw.Border.all(color: PdfColors.red200),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(safety,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      "Cautions:",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: sop.cautions.map((caution) {
                        return pw.Container(
                          padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.amber50,
                            border: pw.Border.all(color: PdfColors.amber),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(caution,
                              style: const pw.TextStyle(fontSize: 10)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build a grid of steps with 5 steps per row
  pw.Widget _buildStepsGrid(SOP sop, Map<String, pw.MemoryImage?> stepImages) {
    final steps = sop.steps;
    final List<pw.Widget> rows = [];

    // Create rows with 5 steps per row
    for (int i = 0; i < steps.length; i += 5) {
      final rowSteps = steps.skip(i).take(5).toList();
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rowSteps
              .map((step) => pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: _buildStepCard(step,
                          i + rowSteps.indexOf(step) + 1, stepImages[step.id]),
                    ),
                  ))
              .toList(),
        ),
      );
      rows.add(pw.SizedBox(height: 10)); // Reduced spacing
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Step-by-Step Procedure",
          style: pw.TextStyle(
            fontSize: 14, // Smaller font
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(),
        pw.SizedBox(height: 8), // Reduced spacing
        ...rows,
      ],
    );
  }

  // Build an individual step card with image at the top
  pw.Widget _buildStepCard(
      SOPStep step, int stepNumber, pw.MemoryImage? stepImage) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Step header with step number
          pw.Container(
            padding: const pw.EdgeInsets.all(6), // Reduced padding
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 20, // Smaller size
                  height: 20, // Smaller size
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue700,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "$stepNumber",
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10, // Smaller font
                    ),
                  ),
                ),
                pw.SizedBox(width: 6), // Reduced spacing
                pw.Expanded(
                  child: pw.Text(
                    step.title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10, // Smaller font
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Step image (if available) - display in proper aspect ratio
          if (stepImage != null)
            pw.Container(
              width: double.infinity,
              height: 100, // Increased height for better image display
              child: pw.Center(
                child: pw.Image(stepImage,
                    fit: pw.BoxFit.contain), // Use contain instead of cover
              ),
            ),

          // Step content
          pw.Padding(
            padding: const pw.EdgeInsets.all(6), // Reduced padding
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(step.instruction,
                    style: const pw.TextStyle(fontSize: 9)), // Smaller font
                if (step.helpNote != null && step.helpNote!.isNotEmpty) ...[
                  pw.SizedBox(height: 4), // Reduced spacing
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4), // Reduced padding
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber50,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "ⓘ ",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.amber800,
                            fontSize: 8, // Smaller font
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            step.helpNote!,
                            style: pw.TextStyle(
                              fontSize: 8, // Smaller font
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tools and hazards in a more compact format
                pw.SizedBox(height: 4), // Reduced spacing
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (step.stepTools.isNotEmpty)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Tools:",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8, // Smaller font
                              ),
                            ),
                            pw.SizedBox(height: 2), // Reduced spacing
                            pw.Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children: step.stepTools.map((tool) {
                                return pw.Container(
                                  padding:
                                      const pw.EdgeInsets.fromLTRB(3, 1, 3, 1),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.blue50,
                                    borderRadius: pw.BorderRadius.circular(2),
                                  ),
                                  child: pw.Text(
                                    tool,
                                    style: const pw.TextStyle(
                                        fontSize: 6), // Smaller font
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    if (step.stepTools.isNotEmpty &&
                        step.stepHazards.isNotEmpty)
                      pw.SizedBox(width: 4), // Reduced spacing
                    if (step.stepHazards.isNotEmpty)
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Hazards:",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8, // Smaller font
                              ),
                            ),
                            pw.SizedBox(height: 2), // Reduced spacing
                            pw.Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children: step.stepHazards.map((hazard) {
                                return pw.Container(
                                  padding:
                                      const pw.EdgeInsets.fromLTRB(3, 1, 3, 1),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.orange50,
                                    borderRadius: pw.BorderRadius.circular(2),
                                  ),
                                  child: pw.Text(
                                    hazard,
                                    style: const pw.TextStyle(
                                        fontSize: 6), // Smaller font
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Assigned to and estimated time in a single row
                if ((step.assignedTo != null && step.assignedTo!.isNotEmpty) ||
                    step.estimatedTime != null) ...[
                  pw.SizedBox(height: 3), // Reduced spacing
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      if (step.assignedTo != null &&
                          step.assignedTo!.isNotEmpty)
                        pw.Row(
                          children: [
                            pw.Text(
                              "Assigned: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 6, // Smaller font
                              ),
                            ),
                            pw.Text(
                              step.assignedTo!,
                              style: const pw.TextStyle(
                                  fontSize: 6), // Smaller font
                            ),
                          ],
                        ),
                      if (step.estimatedTime != null)
                        pw.Row(
                          children: [
                            pw.Text(
                              "Time: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 6, // Smaller font
                              ),
                            ),
                            pw.Text(
                              "${step.estimatedTime} min",
                              style: const pw.TextStyle(
                                  fontSize: 6), // Smaller font
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the footer for each page
  pw.Widget _buildFooter(
      pw.Context context, SOP sop, pw.MemoryImage? qrCodeImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Text(
                  "Created by: ${sop.createdBy}",
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),

          // Show smaller QR code in footer
          pw.Container(
            width: 40,
            height: 40,
            child: qrCodeImage != null
                ? pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 40,
                        height: 40,
                        child: pw.Image(qrCodeImage),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Scan to view on mobile",
                        style: const pw.TextStyle(fontSize: 6),
                      ),
                    ],
                  )
                : pw.Container(),
          ),

          pw.SizedBox(width: 10),
          pw.Text(
            "Printed on: ${_formatDate(DateTime.now())}",
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }

  // Helper method to format dates
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
