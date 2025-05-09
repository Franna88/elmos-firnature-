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

      // Get category color for consistent styling
      final categoryColor = _getCategoryColor(sop.categoryId);
      final PdfColor pdfCategoryColor = PdfColor(categoryColor.red / 255,
          categoryColor.green / 255, categoryColor.blue / 255);

      debugPrint('Building PDF document...');

      // Get summary section
      final summarySection = _buildSummarySection(sop, pdfCategoryColor);

      // Build steps in groups to avoid overwhelming the PDF renderer
      final steps = sop.steps;
      final int stepsCount = steps.length;
      final int stepsPerPage = 6; // Show 6 steps per page

      debugPrint(
          'Generating PDF with ${stepsCount} steps across multiple pages');

      // Add first page with summary and first set of steps
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPDFHeader(sop, logoImage, qrCodeImage, pdfCategoryColor),
                pw.SizedBox(height: 10),
                summarySection,
                pw.SizedBox(height: 15),
                _buildGlobalInfoSection(sop),
                pw.Spacer(),
                _buildFooter(context, sop, qrCodeImage),
              ],
            );
          },
        ),
      );

      // Add steps pages
      int pagesCreated = 1;
      for (int i = 0; i < stepsCount; i += stepsPerPage) {
        final int endIndex =
            i + stepsPerPage > stepsCount ? stepsCount : i + stepsPerPage;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPDFHeader(
                      sop, logoImage, qrCodeImage, pdfCategoryColor),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    pagesCreated == 1
                        ? "Step-by-Step Procedure"
                        : "Step-by-Step Procedure (continued)",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  _buildStepsSection(
                      sop, stepImages, pdfCategoryColor, i, endIndex),
                  pw.Spacer(),
                  _buildFooter(context, sop, qrCodeImage),
                ],
              );
            },
          ),
        );
        pagesCreated++;
      }

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

  // Get a consistent color based on the category ID
  Color _getCategoryColor(String categoryId) {
    // Default to a shade of blue if category is empty
    if (categoryId.isEmpty) {
      return Colors.blue.shade700;
    }

    // Generate a consistent color based on the categoryId
    final int hash = categoryId.hashCode;

    // Use a predefined set of professional colors
    final List<Color> colors = [
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.purple.shade700,
      Colors.orange.shade800,
      Colors.teal.shade700,
      Colors.indigo.shade700,
      Colors.red.shade700,
      Colors.amber.shade800,
    ];

    return colors[hash.abs() % colors.length];
  }

  // Build the PDF header with company logo, SOP information, and total time (more compact)
  pw.Widget _buildPDFHeader(SOP sop, pw.MemoryImage? logoImage,
      pw.MemoryImage? qrCodeImage, PdfColor categoryColor) {
    // Calculate total SOP time
    final totalTime = _calculateTotalSOPTime(sop);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo on the left
          pw.Container(
            width: 60,
            height: 60,
            child: logoImage != null
                ? pw.Image(logoImage)
                : pw.Container(
                    height: 40,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text("Logo",
                        style: pw.TextStyle(color: PdfColors.grey)),
                  ),
          ),

          pw.SizedBox(width: 10),

          // SOP info - compact single line
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  sop.title,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(width: 15),
                pw.Text(
                  '| ID: ${sop.id} | Rev: ${sop.revisionNumber} | Cat: ${sop.categoryName ?? 'Uncategorized'} | Updated: ${_formatDate(sop.updatedAt)} | Est. Time: ${_formatTime(totalTime)}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),

          // QR Code on the right
          pw.Container(
            width: 60,
            height: 60,
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
      ),
    );
  }

  // Build the summary section with just the SOP description
  pw.Widget _buildSummarySection(SOP sop, PdfColor categoryColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Description:",
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            sop.description,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  // New method to build steps for a specific page range
  pw.Widget _buildStepsSection(SOP sop, Map<String, pw.MemoryImage?> stepImages,
      PdfColor categoryColor, int startIndex, int endIndex) {
    final steps = sop.steps;
    final List<pw.Widget> rows = [];

    // Create rows with 3 steps per row from the specified range
    for (int i = startIndex; i < endIndex; i += 3) {
      final int rowEndIndex = i + 3 > endIndex ? endIndex : i + 3;
      final rowSteps = steps.sublist(i, rowEndIndex);

      // Create a row with up to 3 steps
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rowSteps
              .map((step) => pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: _buildStepCard(
                          step,
                          i + rowSteps.indexOf(step) + 1,
                          stepImages[step.id],
                          categoryColor),
                    ),
                  ))
              .toList(),
        ),
      );
      rows.add(pw.SizedBox(height: 10)); // Spacing between rows
    }

    // For the first page, include the header
    if (startIndex == 0) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Step-by-Step Procedure",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      );
    } else {
      // For continuation pages, just the rows
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      );
    }
  }

  // Build an individual step card with consistent image size and text limited to 4 lines
  pw.Widget _buildStepCard(SOPStep step, int stepNumber,
      pw.MemoryImage? stepImage, PdfColor categoryColor) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: categoryColor),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Step header with step number
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: categoryColor,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    "$stepNumber",
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    step.title,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ),
                // Add estimated time if available
                if (step.estimatedTime != null)
                  pw.Text(
                    _formatTime(step.estimatedTime!),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
          ),

          // Step image (if available) - consistent height and width for all images
          if (stepImage != null)
            pw.Container(
              width: double.infinity,
              height: 120, // Fixed height for consistent images
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              child: pw.Center(
                child: pw.Image(stepImage,
                    fit: pw.BoxFit.contain), // Consistent image fitting
              ),
            ),

          // Step content - instruction with max 4 lines
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Limit text to approximately 4 lines by limiting characters
                pw.Text(
                  step.instruction.length > 200
                      ? '${step.instruction.substring(0, 200)}...'
                      : step.instruction,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                // No step-specific tools or other information as requested
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format time in hours, minutes, and seconds
  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    String hourStr = hours > 0 ? '${hours}h ' : '';
    String minStr = minutes > 0 ? '${minutes}m ' : '';
    String secStr = seconds > 0 ? '${seconds}s' : '';

    if (hours == 0 && minutes == 0 && seconds == 0) {
      return '0s';
    }

    return '$hourStr$minStr$secStr'.trim();
  }

  // Calculate total SOP time by summing all step times
  int _calculateTotalSOPTime(SOP sop) {
    int totalSeconds = 0;
    for (final step in sop.steps) {
      if (step.estimatedTime != null) {
        totalSeconds += step.estimatedTime!;
      }
    }
    return totalSeconds;
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

  // New method to build global information section
  pw.Widget _buildGlobalInfoSection(SOP sop) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      padding: const pw.EdgeInsets.all(15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "GLOBAL SOP INFORMATION",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // Three columns layout for global information
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // GLOBAL TOOLS SECTION
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      color: PdfColors.blue100,
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(
                        "GLOBAL TOOLS",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    ...sop.tools.map((tool) {
                      return pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          border: pw.Border.all(color: PdfColors.blue200),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(tool,
                            style: const pw.TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(width: 15),

              // SAFETY REQUIREMENTS
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      color: PdfColors.red100,
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(
                        "SAFETY REQUIREMENTS",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.red900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    ...sop.safetyRequirements.map((safety) {
                      return pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red50,
                          border: pw.Border.all(color: PdfColors.red200),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(safety,
                            style: const pw.TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                  ],
                ),
              ),

              pw.SizedBox(width: 15),

              // CAUTIONS & WARNINGS
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      color: PdfColors.amber100,
                      width: double.infinity,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(
                        "CAUTIONS & WARNINGS",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.amber900,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    ...sop.cautions.map((caution) {
                      return pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.amber50,
                          border: pw.Border.all(color: PdfColors.amber),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(caution,
                            style: const pw.TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
