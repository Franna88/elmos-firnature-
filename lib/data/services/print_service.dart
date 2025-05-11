import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/sop_model.dart';
import 'qr_code_service.dart';
import 'package:image_network/image_network.dart';

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
      pw.MemoryImage? logoImage;

      try {
        logoImage = await _loadAssetImage('assets/images/logo.png');
      } catch (e) {
        debugPrint('Error loading logo: $e');
      }

      if (logoImage == null) {
        // Use embedded fallback logo if asset loading fails
        logoImage = _getEmbeddedLogo();
      }

      debugPrint('Logo loaded: ${logoImage != null ? 'success' : 'failed'}');

      // Pre-load all step images
      debugPrint('Loading step images for ${sop.steps.length} steps...');
      final Map<String, pw.MemoryImage?> stepImages = {};
      int imagesLoaded = 0;
      int imagesFailed = 0;

      for (int i = 0; i < sop.steps.length; i++) {
        final step = sop.steps[i];

        if (step.imageUrl != null && step.imageUrl!.isNotEmpty) {
          // First try loading the actual image
          pw.MemoryImage? image;

          // For web platform, try to use a more direct approach first
          if (kIsWeb) {
            image = await _convertCrossPlatformImageForPdf(step.imageUrl!);
          }

          // If the direct approach fails, fall back to network image loading
          if (image == null) {
            image = await _loadNetworkImage(step.imageUrl);
          }

          if (image != null) {
            stepImages[step.id] = image;
            imagesLoaded++;
            debugPrint('✓ Successfully loaded image for step ${step.id}');
          } else {
            // If the actual image fails, use a generated placeholder
            imagesFailed++;
            debugPrint('✗ Failed to load image for step ${step.id}');

            // Create a placeholder image with step number
            final placeholder = _generatePlaceholderImage(i);
            if (placeholder != null) {
              stepImages[step.id] = placeholder;
              debugPrint('Using generated placeholder for step ${step.id}');
            }
          }
        }
      }

      debugPrint(
          'Image loading summary: ${imagesLoaded} loaded, ${imagesFailed} failed');

      // Notify user about image status
      if (imagesFailed > 0 && imagesLoaded == 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Images couldn\'t be loaded due to browser restrictions. Using placeholders.'),
            duration: Duration(seconds: 4),
          ),
        );
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

      // Build steps in groups to avoid overwhelming the PDF renderer
      final steps = sop.steps;
      final int stepsCount = steps.length;

      // Calculate optimal steps per page based on step count
      // Fewer steps = larger images and more details
      final int stepsPerPage = stepsCount <= 6 ? 3 : 6;

      debugPrint(
          'Generating PDF with ${stepsCount} steps across multiple pages');

      // Add first page with header, global information, and description
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo and basic info
                _buildPDFHeader(sop, logoImage, qrCodeImage, pdfCategoryColor),
                pw.SizedBox(height: 15),

                // Global information section (now prominently at the top)
                _buildGlobalInfoSection(sop),
                pw.SizedBox(height: 15),

                // Description section
                _buildSummarySection(sop, pdfCategoryColor),

                pw.Spacer(),
                _buildFooter(context, sop, qrCodeImage),
              ],
            );
          },
        ),
      );

      // Add steps pages
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
                    i == 0
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
      }

      // Show the print dialog
      debugPrint('Showing print dialog...');
      // Print the document using appropriate method based on platform
      final result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          debugPrint(
              'Generating PDF with format: ${format.width}x${format.height}');

          // Log how many images were successfully included
          int imageCount = stepImages.values.where((img) => img != null).length;
          debugPrint(
              'PDF includes $imageCount images out of ${sop.steps.length} steps');

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
          // Determine appropriate success message based on image loading success
          final String successMessage = imagesLoaded == sop.steps.length
              ? 'PDF generated successfully with all images'
              : 'PDF generated successfully with ${imagesLoaded}/${sop.steps.length} images';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              duration: const Duration(seconds: 2),
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
      return _getEmbeddedLogo(); // Use our embedded logo fallback
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
        debugPrint('Detected data URL, decoding inline image data');
        final String data = url.split(',')[1];
        final Uint8List bytes = base64Decode(data);
        debugPrint(
            'Successfully decoded data URL image (${bytes.length} bytes)');
        return pw.MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding data URL image: $e');
        return null;
      }
    }

    // For web platform, use the image_network approach which handles CORS properly
    if (kIsWeb) {
      try {
        debugPrint('Using image_network approach for web platform');

        // Create an ImageNetwork widget to fetch the image
        final imageNetwork = ImageNetwork(
          image: url,
          height: 300,
          width: 300,
          duration: 1500,
          onLoading: Container(),
          onError: Container(),
        );

        // Get the bytes from the image using a different approach
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Accept': 'image/*',
              'Access-Control-Allow-Origin': '*',
              'X-Requested-With': 'XMLHttpRequest',
            },
          );

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image via custom headers: ${response.bodyBytes.length} bytes');
            return pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error using custom headers approach: $e');
        }
      } catch (e) {
        debugPrint('Error using image_network: $e');
      }

      // If image_network approach fails, continue with other approaches
    }

    // Check if this is a Firebase Storage URL
    bool isFirebaseStorageUrl =
        url.contains('firebasestorage.googleapis.com') ||
            url.contains('appspot.com');

    if (isFirebaseStorageUrl) {
      return await _loadFirebaseStorageImage(url);
    }

    // Handle regular network images
    try {
      debugPrint('Fetching regular network image from: $url');

      // Try multiple approaches to fetch the image
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'image/*'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Network image request timed out: $url');
          throw Exception('Network request timed out');
        },
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isNotEmpty) {
          debugPrint(
              'Successfully loaded network image: $url (${bytes.length} bytes)');
          return pw.MemoryImage(bytes);
        } else {
          debugPrint('Network image response was empty: $url');
        }
      } else {
        debugPrint(
            'Failed to load network image. Status code: ${response.statusCode}');

        // Fall back to using a proxy if direct access failed
        try {
          debugPrint('Trying proxy approach for: $url');
          // Use a CORS proxy if needed
          final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
          final proxyResponse = await http.get(Uri.parse(proxyUrl)).timeout(
                const Duration(seconds: 10),
              );

          if (proxyResponse.statusCode == 200 &&
              proxyResponse.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image via proxy: $url (${proxyResponse.bodyBytes.length} bytes)');
            return pw.MemoryImage(proxyResponse.bodyBytes);
          }
        } catch (proxyError) {
          debugPrint('Proxy approach also failed: $proxyError');
        }
      }
    } catch (e) {
      debugPrint('Error loading network image from $url: $e');
    }

    // Return a placeholder image if we weren't able to load the real one
    return null;
  }

  // Specialized method to handle Firebase Storage images
  Future<pw.MemoryImage?> _loadFirebaseStorageImage(String url) async {
    debugPrint('Loading Firebase Storage image: $url');

    try {
      // On web platform, try the custom headers approach that works with the CrossPlatformImage widget
      if (kIsWeb) {
        try {
          debugPrint('Using custom headers approach for Firebase URL on web');

          // Add the alt=media parameter if it's missing
          String processedUrl = url;
          if (!url.contains('alt=media')) {
            processedUrl =
                url.contains('?') ? '$url&alt=media' : '$url?alt=media';
          }

          // Make the request with CORS-friendly headers
          final response = await http.get(
            Uri.parse(processedUrl),
            headers: {
              'Accept': 'image/*',
              'Access-Control-Allow-Origin': '*',
              'X-Requested-With': 'XMLHttpRequest',
            },
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded Firebase image with custom headers: ${response.bodyBytes.length} bytes');
            return pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Custom headers approach failed for Firebase URL: $e');
          // Continue with other approaches if this fails
        }
      }

      // Pre-process the Firebase Storage URL to ensure it's properly formatted
      Uri uri = Uri.parse(url);
      String processedUrl = url;

      // Make sure we have the alt=media parameter
      if (!uri.queryParameters.containsKey('alt') ||
          uri.queryParameters['alt'] != 'media') {
        processedUrl = url.contains('?') ? '$url&alt=media' : '$url?alt=media';
        debugPrint('Added alt=media parameter: $processedUrl');
      }

      // Convert to a public download URL format if needed
      if (processedUrl.contains('/o/')) {
        // Extract the path component after /o/
        final pathRegExp = RegExp(r'/o/([^?]+)');
        final match = pathRegExp.firstMatch(processedUrl);
        if (match != null && match.groupCount >= 1) {
          final encodedPath = match.group(1);
          if (encodedPath != null) {
            // Create a direct download URL format
            final storageUrl =
                processedUrl.contains('firebasestorage.googleapis.com')
                    ? 'https://storage.googleapis.com/'
                    : 'https://firebasestorage.googleapis.com/v0/b/';

            // Create a more direct URL that might bypass CORS
            final directUrl = '$storageUrl$encodedPath';
            debugPrint('Trying direct storage URL: $directUrl');

            try {
              final directResponse =
                  await http.get(Uri.parse(directUrl)).timeout(
                        const Duration(seconds: 5),
                      );

              if (directResponse.statusCode == 200 &&
                  directResponse.bodyBytes.isNotEmpty) {
                debugPrint(
                    'Direct Storage URL succeeded: ${directResponse.bodyBytes.length} bytes');
                return pw.MemoryImage(directResponse.bodyBytes);
              }
            } catch (e) {
              debugPrint('Direct Storage URL failed: $e');
            }
          }
        }
      }

      // Use a CORS proxy as last resort for Firebase Storage URLs
      debugPrint('Trying CORS proxy for Firebase URL');
      final proxyUrl =
          'https://corsproxy.io/?${Uri.encodeComponent(processedUrl)}';

      final response = await http.get(Uri.parse(proxyUrl)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint(
            'Successfully loaded Firebase image via proxy: ${response.bodyBytes.length} bytes');
        return pw.MemoryImage(response.bodyBytes);
      } else {
        debugPrint('Proxy failed. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Firebase image loading error: $e');
    }

    return null;
  }

  // Alternative method to embed sample images when real ones fail to load
  pw.MemoryImage? _getSampleImage() {
    try {
      // This is a very small base64-encoded 1x1 pixel transparent PNG
      const String transparentPixel =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
      final bytes = base64Decode(transparentPixel);
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Failed to create sample image: $e');
      return null;
    }
  }

  // Alternative approach to load Firebase Storage images if the standard approach fails
  Future<pw.MemoryImage?> _loadFirebaseImageAlternative(String url) async {
    try {
      debugPrint('Using alternative Firebase image loading approach for: $url');

      // Try parsing the URL to get the downloadable URL path
      final Uri uri = Uri.parse(url);

      // Try a CORS proxy with multiple different URL formats

      // 1. Try original URL with CORS proxy
      final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      debugPrint('Trying CORS proxy URL: $proxyUrl');

      try {
        final proxyResponse = await http.get(Uri.parse(proxyUrl)).timeout(
              const Duration(seconds: 10),
            );

        if (proxyResponse.statusCode == 200 &&
            proxyResponse.bodyBytes.isNotEmpty) {
          debugPrint(
              'CORS proxy approach succeeded (${proxyResponse.bodyBytes.length} bytes)');
          return pw.MemoryImage(proxyResponse.bodyBytes);
        }
      } catch (e) {
        debugPrint('CORS proxy approach failed: $e');
      }

      // 2. Try to extract and use a direct storage URL
      if (url.contains('/o/')) {
        try {
          // Use a different proxy
          final alternateProxyUrl =
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
          debugPrint('Trying alternate proxy: $alternateProxyUrl');

          final altProxyResponse =
              await http.get(Uri.parse(alternateProxyUrl)).timeout(
                    const Duration(seconds: 10),
                  );

          if (altProxyResponse.statusCode == 200 &&
              altProxyResponse.bodyBytes.isNotEmpty) {
            debugPrint(
                'Alternate proxy succeeded (${altProxyResponse.bodyBytes.length} bytes)');
            return pw.MemoryImage(altProxyResponse.bodyBytes);
          }
        } catch (e) {
          debugPrint('Alternate proxy failed: $e');
        }
      }

      // 3. Sample image as fallback
      debugPrint(
          'All Firebase image loading approaches failed. Using sample image.');
      return _getSampleImage();
    } catch (e) {
      debugPrint('Firebase alternative loading completely failed: $e');
      return _getSampleImage();
    }
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
    // This ensures consistent layout and maximizes paper usage
    for (int i = startIndex; i < endIndex; i += 3) {
      final int rowEndIndex = i + 3 > endIndex ? endIndex : i + 3;
      final rowSteps = steps.sublist(i, rowEndIndex);
      final int stepsInRow = rowSteps.length;

      // Create a row with up to 3 steps of equal width
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Fill the row with steps
            ...rowSteps.map((step) => pw.Expanded(
                  flex: 1, // Equal flex for consistent sizing
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                    child: _buildStepCard(step, i + rowSteps.indexOf(step) + 1,
                        stepImages[step.id], categoryColor),
                  ),
                )),

            // If row has fewer than 3 steps, add empty expanded widgets to maintain layout
            if (stepsInRow < 3)
              ...List.generate(
                  3 - stepsInRow,
                  (_) => pw.Expanded(
                        flex: 1,
                        child: pw.Container(),
                      )),
          ],
        ),
      );
      rows.add(pw.SizedBox(height: 10)); // Spacing between rows
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
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

          // Image container with fixed height - this helps maintain consistent card sizing
          pw.Container(
            width: double.infinity,
            height:
                120, // Reduced height to leave more room for instruction text
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: const pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            alignment: pw.Alignment.center,
            child: stepImage != null
                ? pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Image(
                      stepImage,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                : pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(20),
                          border: pw.Border.all(color: PdfColors.grey400),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          "!",
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'No image',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
          ),

          // Step content - instruction with compact layout
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Present instruction text
                pw.Text(
                  step.instruction,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                // Add step-specific tools if available
                if (step.stepTools.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Step tools: ${step.stepTools.join(', ')}",
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.blue900,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
                // Add step hazards if available
                if (step.stepHazards.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Hazards: ${step.stepHazards.join(', ')}",
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.red900,
                      fontStyle: pw.FontStyle.italic,
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
        border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: PdfColors.grey50,
      ),
      padding: const pw.EdgeInsets.all(15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            color: PdfColors.grey200,
            child: pw.Text(
              "GLOBAL SOP INFORMATION",
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 12),

          // Three columns layout for global information with equal width
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // GLOBAL TOOLS SECTION
              pw.Expanded(
                flex: 1,
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
                    // If no tools, show placeholder
                    if (sop.tools.isEmpty)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          border: pw.Border.all(color: PdfColors.blue200),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text("No tools specified",
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey)),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(width: 15),

              // SAFETY REQUIREMENTS
              pw.Expanded(
                flex: 1,
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
                    // If no safety requirements, show placeholder
                    if (sop.safetyRequirements.isEmpty)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red50,
                          border: pw.Border.all(color: PdfColors.red200),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text("No safety requirements specified",
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey)),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(width: 15),

              // CAUTIONS & WARNINGS
              pw.Expanded(
                flex: 1,
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
                    // If no cautions, show placeholder
                    if (sop.cautions.isEmpty)
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.amber50,
                          border: pw.Border.all(color: PdfColors.amber),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text("No cautions specified",
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey)),
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

  // Get embedded logo for when asset loading fails
  pw.MemoryImage? _getEmbeddedLogo() {
    try {
      // A minimal base64-encoded logo (very small PNG)
      const String logoBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAApgAAAKYB3X3/OAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAANCSURBVEiJtZZPbBtFFMZ/M7ubXdtdb1xSFyeilBapySVU8h8OoFaooFSqiihIVIpQBKci6KEg9Q6H9kovIHoCIVQJJCKE1ENFjnAgcaSGC6rEnxBwA04Tx43t2FnvDAfjkNibxgHxnWb2e/u992bee7tCa00YFsffekFY+nUzFtjW0LrvjRXrCDIAaPLlW0nHL0SsZtVoaF98mLrx3pdhOqLtYPHChahZcYYO7KvPFxvRl5XPp1sN3adWiD1ZAqD6XYK1b/dvE5IWryTt2udLFedwc1+9kLp+vbbpoDh+6TklxBeAi9TL0taeWpdmZzQDry0AcO+jQ12RyohqqoYoo8RDwJrU+qXkjWtfi8Xxt58BdQuwQs9qC/afLwCw8tnQbqYAPsgxE1S6F3EAIXux2oQFKm0ihMsOF71dHYx+f3NND68ghCu1YIoePPQN1pGRABkJ6Bus96CutRZMydTl+TvuiRW1m3n0eDl0vRPcEysqdXn+jsQPsrHMquGeXEaY4Yk4wxWcY5V/9scqOMOVUFthatyTy8QyqwZ+kDURKoMWxNKr2EeqVKcTNOajqKoBgOE28U4tdQl5p5bwCw7BWquaZSzAPlwjlithJtp3pTImSqQRrb2Z8PHGigD4RZuNX6JYj6wj7O4TFLbCO/Mn/m8R+h6rYSUb3ekokRY6f/YukArN979jcW+V/S8g0eT/N3VN3kTqWbQ428m9/8k0P/1aIhF36PccEl6EhOcAUCrXKZXXWS3XKd2vc/TRBG9O5ELC17MmWubD2nKhUKZa26Ba2+D3P+4/MNCFwg59oWVeYhkzgN/JDR8deKBoD7Y+ljEjGZ0sosXVTvbc6RHirr2reNy1OXd6pJsQ+gqjk8VWFYmHrwBzW/n+uMPFiRwHB2I7ih8ciHFxIkd/3Omk5tCDV1t+2nNu5sxxpDFNx+huNhVT3/zMDz8usXC3ddaHBj1GHj/As08fwTS7Kt1HBTmyN29vdwAw+/wbwLVOJ3uAD1wi/dUH7Qei66PfyuRj4Ik9is+hglfbkbfR3cnZm7chlUWLdwmprtCohX4HUtlOcQjLYCu+fzGJH2QRKvP3UNz8bWk1qMxjGTOMThZ3kvgLI5AzFfo379UAAAAASUVORK5CYII=';
      final bytes = base64Decode(logoBase64);
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error creating embedded logo: $e');
      return null;
    }
  }

  // Create a list of sample images to use when network images can't be loaded
  List<pw.MemoryImage?> _getHardcodedSampleImages() {
    List<pw.MemoryImage?> images = [];

    try {
      // List of small base64-encoded images (1x1 pixel PNGs with different colors)
      const List<String> sampleBase64Images = [
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', // red
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', // green
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', // blue
      ];

      for (var encodedImage in sampleBase64Images) {
        try {
          final bytes = base64Decode(encodedImage);
          images.add(pw.MemoryImage(bytes));
        } catch (e) {
          debugPrint('Error decoding sample image: $e');
        }
      }
    } catch (e) {
      debugPrint('Error preparing sample images: $e');
    }

    return images;
  }

  // Create a sample image with a solid color that works in all environments
  pw.MemoryImage? _createSampleImage(int width, int height, PdfColor color) {
    try {
      final pdf = pw.Document();
      final page = pw.Page(
        build: (context) {
          return pw.Container(
            width: width.toDouble(),
            height: height.toDouble(),
            color: color,
          );
        },
      );
      pdf.addPage(page);

      // Generate the PDF as bytes and use it as an image
      final bytes = pdf.save();
      return pw.MemoryImage(bytes as Uint8List);
    } catch (e) {
      debugPrint('Error creating sample image: $e');
      return null;
    }
  }

  // Generate a placeholder image with text when network image fails
  pw.MemoryImage? _generatePlaceholderImage(int stepNumber) {
    final placeholderColors = [
      PdfColors.blue100,
      PdfColors.green100,
      PdfColors.amber100,
      PdfColors.purple100,
      PdfColors.red100,
      PdfColors.teal100,
    ];

    // Use a different color for each step (cycling through the colors)
    final bgColor = placeholderColors[stepNumber % placeholderColors.length];

    try {
      // Create a simple PDF with text as our placeholder
      final pdf = pw.Document();
      final page = pw.Page(
        pageFormat: PdfPageFormat(150, 150),
        build: (context) {
          return pw.Container(
            width: 150,
            height: 150,
            color: bgColor,
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'STEP',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.black,
                  ),
                ),
                pw.Text(
                  '${stepNumber + 1}',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          );
        },
      );
      pdf.addPage(page);

      final bytes = pdf.save();
      return pw.MemoryImage(bytes as Uint8List);
    } catch (e) {
      debugPrint('Error generating placeholder image: $e');
      return null;
    }
  }

  // Convert an image from the CrossPlatformImage widget for PDF use
  Future<pw.MemoryImage?> _convertCrossPlatformImageForPdf(
      String imageUrl) async {
    debugPrint(
        'Attempting to convert CrossPlatformImage to PDF image: $imageUrl');

    try {
      // Try to load the image using the same approach as CrossPlatformImage
      // First check if it's a data URL
      if (imageUrl.startsWith('data:image/')) {
        try {
          final String data = imageUrl.split(',')[1];
          final Uint8List bytes = base64Decode(data);
          return pw.MemoryImage(bytes);
        } catch (e) {
          debugPrint('Error decoding data URL: $e');
          return null;
        }
      }

      // Use custom headers that simulate the image_network package's approach
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'Accept': 'image/*',
          'Access-Control-Allow-Origin': '*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://firebasestorage.googleapis.com/',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint(
            'Successfully converted CrossPlatformImage for PDF: ${response.bodyBytes.length} bytes');
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('Error converting CrossPlatformImage for PDF: $e');
    }

    return null;
  }
}
