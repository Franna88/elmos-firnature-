import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io' show Platform;
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
    bool dialogShown = false;

    // Show loading indicator
    if (context.mounted) {
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Generating PDF..."),
                ],
              ),
            ),
          );
        },
      );
    }

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

      // Enable this flag to use direct Uint8List bytes when available on tablets
      bool useDirectImageBytes = true;

      // Create a temporary cache for images to improve loading reliability
      final Map<String, Uint8List> tempImageCache = {};

      // Log platform information to help with debugging
      debugPrint('Running on platform: ${kIsWeb ? 'Web' : 'Mobile/Tablet'}');
      debugPrint('PDF generation targeting print output on tablet');

      // FORCE PRE-LOADING OF ALL IMAGES BEFORE PDF GENERATION
      await _preloadAllImagesForPdf(sop, tempImageCache);

      for (int i = 0; i < sop.steps.length; i++) {
        final step = sop.steps[i];

        if (step.imageUrl != null && step.imageUrl!.isNotEmpty) {
          // First check if we already have this image in the cache
          if (tempImageCache.containsKey(step.imageUrl!)) {
            final cachedBytes = tempImageCache[step.imageUrl!]!;
            try {
              stepImages[step.id] = pw.MemoryImage(cachedBytes);
              imagesLoaded++;
              debugPrint(
                  '✓ Using cached image for step ${step.id} (${cachedBytes.length} bytes)');
            } catch (e) {
              debugPrint('Error creating pw.MemoryImage from cached bytes: $e');
              imagesFailed++;
            }
            continue;
          }

          // First check if the image URL is a data URL that can be directly decoded
          if (step.imageUrl!.startsWith('data:image/')) {
            try {
              debugPrint('Detected data URL, decoding inline image data');
              final String data = step.imageUrl!.split(',')[1];
              final Uint8List bytes = base64Decode(data);
              tempImageCache[step.imageUrl!] = bytes; // Cache the image
              stepImages[step.id] = pw.MemoryImage(bytes);
              imagesLoaded++;
              debugPrint(
                  '✓ Successfully loaded data URL image for step ${step.id}');
              continue; // Skip other loading methods if data URL works
            } catch (e) {
              debugPrint('Error decoding data URL image: $e');
              // Continue to try other methods
            }
          }

          // Try all available methods to load the image, prioritizing tablet-friendly approaches
          pw.MemoryImage? image;

          // First try our aggressive tablet-specific approach
          try {
            debugPrint(
                'Attempting aggressive tablet image loading for step ${step.id}');
            final bytes = await _loadImageAggressiveForTablet(step.imageUrl!);
            if (bytes != null) {
              tempImageCache[step.imageUrl!] = bytes; // Cache the image
              image = pw.MemoryImage(bytes);
              debugPrint(
                  '✓ Successfully loaded image with aggressive tablet approach (${bytes.length} bytes)');
            }
          } catch (e) {
            debugPrint('Error in aggressive tablet image loading: $e');
          }

          // If that fails, try using ImageNetwork approach
          if (image == null) {
            try {
              debugPrint(
                  'Attempting to load image via ImageNetwork for step ${step.id}');
              image = await _loadImageWithImageNetwork(step.imageUrl!);
              if (image != null) {
                debugPrint(
                    '✓ Successfully loaded image via ImageNetwork for step ${step.id}');
              }
            } catch (e) {
              debugPrint('Error using ImageNetwork: $e');
            }
          }

          // If that fails, try direct conversion approach
          if (image == null && (kIsWeb || useDirectImageBytes)) {
            try {
              image = await _convertCrossPlatformImageForPdf(step.imageUrl!);
              debugPrint(
                  'Direct conversion approach result: ${image != null ? "success" : "failed"}');
            } catch (e) {
              debugPrint('Error in direct conversion: $e');
            }
          }

          // If all else fails, fall back to network image loading
          if (image == null) {
            try {
              // Enhanced approach with longer timeout for tablets
              image = await _loadNetworkImage(step.imageUrl,
                  timeout: 30); // Increased timeout even more
            } catch (e) {
              debugPrint('All network approaches failed: $e');
            }
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
      if (imagesFailed > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imagesLoaded > 0
                  ? 'Some images couldn\'t be loaded (${imagesLoaded}/${sop.steps.length} loaded). Check the PDF output.'
                  : 'Images couldn\'t be loaded. Using placeholders. Check device connectivity and try again.',
            ),
            duration: const Duration(seconds: 4),
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
      // We now always want 6 steps per page for better consistency
      const int stepsPerPage = 6;

      debugPrint(
          'Generating PDF with ${stepsCount} steps across multiple pages');

      // Add first page with header, global information, and description
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with logo and basic info
                _buildPDFHeader(sop, logoImage, qrCodeImage, pdfCategoryColor),
                pw.SizedBox(height: 4),

                // Description section - much more compact
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Global information in a single row
                    pw.Expanded(
                      flex: 4,
                      child: _buildGlobalInfoSection(sop),
                    ),

                    pw.SizedBox(width: 8),

                    // Description to the right
                    pw.Expanded(
                      flex: 2,
                      child: _buildSummarySection(sop, pdfCategoryColor),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),

                // First 6 steps or all if <= 6
                _buildStepsSection(sop, stepImages, pdfCategoryColor, 0,
                    stepsCount <= 6 ? stepsCount : 6),

                pw.Spacer(),
                _buildFooter(context, sop, qrCodeImage),
              ],
            );
          },
        ),
      );

      // Add steps pages - only if there are more than 6 steps
      if (stepsCount > 6) {
        for (int i = 6; i < stepsCount; i += stepsPerPage) {
          final int endIndex =
              i + stepsPerPage > stepsCount ? stepsCount : i + stepsPerPage;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(15),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPDFHeader(
                        sop, logoImage, qrCodeImage, pdfCategoryColor),
                    pw.SizedBox(height: 4),
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
      }

      // Show the print dialog
      debugPrint('Showing print dialog...');

      // Dismiss loading indicator before showing print dialog - FIX NAVIGATION ERROR
      if (dialogShown && context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          dialogShown = false;
        } catch (e) {
          debugPrint('Error dismissing loading dialog: $e');
          // Continue even if dialog dismissal fails
        }
      }

      // Make sure context is still mounted before showing print dialog
      if (!context.mounted) {
        debugPrint('Context is no longer mounted, aborting print operation');
        return;
      }

      // Print the document using appropriate method
      debugPrint('Using enhanced PDF printing for tablets');

      // Add extra logging to help with debugging
      debugPrint('Total steps: ${sop.steps.length}');
      debugPrint('Steps with images: ${stepImages.length}');
      debugPrint('Total images successfully loaded: ${imagesLoaded}');

      try {
        // For tablets, try a more direct printing approach with optimized PDF settings
        final result = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async {
            debugPrint(
                'Generating PDF with format: ${format.width}x${format.height}');

            // Log how many images were successfully included
            int imageCount =
                stepImages.values.where((img) => img != null).length;
            debugPrint(
                'PDF includes $imageCount images out of ${sop.steps.length} steps');

            // Generate the PDF
            try {
              debugPrint('Using optimized PDF generation settings for tablet');
              return pdf.save();
            } catch (e) {
              debugPrint('Error in PDF generation: $e');
              return pdf.save();
            }
          },
          name: _removeEmojis(sop.title),
          format: PdfPageFormat.a4.landscape,
          usePrinterSettings: true, // Use printer's default settings
        );

        debugPrint('Print result: $result');

        if (!result && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to print or save the document. Try using a different device or check printer connection.'),
              duration: Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        } else if (context.mounted) {
          // Determine appropriate success message based on image loading success
          final String successMessage = imagesLoaded == sop.steps.length
              ? 'PDF generated successfully with all images'
              : 'PDF generated successfully with ${imagesLoaded}/${sop.steps.length} images';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error during printing process: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error printing: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // Dismiss loading indicator if there's an error
      if (dialogShown && context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
          debugPrint('Error dismissing dialog: $navError');
        }
      }

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

  // Load an image from a URL with enhanced error handling for tablets
  Future<pw.MemoryImage?> _loadNetworkImage(String? url,
      {int timeout = 15}) async {
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

    // Check if this is a Firebase Storage URL
    bool isFirebaseStorageUrl =
        url.contains('firebasestorage.googleapis.com') ||
            url.contains('appspot.com');

    if (isFirebaseStorageUrl) {
      return await _loadFirebaseStorageImage(url, timeout: timeout);
    }

    // Handle regular network images
    try {
      debugPrint('Fetching regular network image from: $url');

      // Try multiple approaches to fetch the image
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'image/*',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'User-Agent': 'Flutter PDF Generator',
          'Access-Control-Allow-Origin': '*'
        },
      ).timeout(
        Duration(seconds: timeout),
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
                Duration(seconds: timeout),
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

        // Try alternative proxy as last resort
        try {
          final altProxyUrl =
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
          final altProxyResponse =
              await http.get(Uri.parse(altProxyUrl)).timeout(
                    Duration(seconds: timeout),
                  );

          if (altProxyResponse.statusCode == 200 &&
              altProxyResponse.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image via alt proxy: $url (${altProxyResponse.bodyBytes.length} bytes)');
            return pw.MemoryImage(altProxyResponse.bodyBytes);
          }
        } catch (altProxyError) {
          debugPrint('Alternative proxy approach also failed: $altProxyError');
        }
      }
    } catch (e) {
      debugPrint('Error loading network image from $url: $e');
    }

    // Return a placeholder image if we weren't able to load the real one
    return null;
  }

  // Specialized method to handle Firebase Storage images
  Future<pw.MemoryImage?> _loadFirebaseStorageImage(String url,
      {int timeout = 15}) async {
    debugPrint('Loading Firebase Storage image: $url');

    try {
      // On web platform or tablets, try the custom headers approach first
      try {
        debugPrint('Using enhanced headers approach for Firebase URL');

        // Add the alt=media parameter if it's missing
        String processedUrl = url;
        if (!url.contains('alt=media')) {
          processedUrl =
              url.contains('?') ? '$url&alt=media' : '$url?alt=media';
        }

        // Make the request with enhanced CORS-friendly headers
        final response = await http.get(
          Uri.parse(processedUrl),
          headers: {
            'Accept': 'image/*',
            'Access-Control-Allow-Origin': '*',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://firebasestorage.googleapis.com/',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Origin': 'https://firebasestorage.googleapis.com',
            'User-Agent': 'Flutter PDF Generator'
          },
        ).timeout(Duration(seconds: timeout));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Successfully loaded Firebase image with enhanced headers: ${response.bodyBytes.length} bytes');
          return pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Enhanced headers approach failed for Firebase URL: $e');
        // Continue with other approaches if this fails
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

      // Try a more direct approach with longer timeout
      try {
        final directResponse = await http.get(
          Uri.parse(processedUrl),
          headers: {
            'Accept': 'image/*',
            'Cache-Control': 'no-cache',
            'Origin': 'https://firebasestorage.googleapis.com'
          },
        ).timeout(Duration(seconds: timeout));

        if (directResponse.statusCode == 200 &&
            directResponse.bodyBytes.isNotEmpty) {
          debugPrint(
              'Direct Firebase URL approach succeeded: ${directResponse.bodyBytes.length} bytes');
          return pw.MemoryImage(directResponse.bodyBytes);
        }
      } catch (e) {
        debugPrint('Direct Firebase URL approach failed: $e');
      }

      // Use a CORS proxy as last resort for Firebase Storage URLs
      debugPrint('Trying CORS proxy for Firebase URL');
      // Try multiple CORS proxies
      final proxies = [
        'https://corsproxy.io/?${Uri.encodeComponent(processedUrl)}',
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(processedUrl)}',
        'https://cors-anywhere.herokuapp.com/${Uri.encodeComponent(processedUrl)}'
      ];

      for (final proxyUrl in proxies) {
        try {
          debugPrint('Trying proxy: $proxyUrl');
          final response = await http.get(Uri.parse(proxyUrl)).timeout(
                Duration(seconds: timeout),
              );

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded Firebase image via proxy: ${response.bodyBytes.length} bytes');
            return pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Proxy failed: $e');
        }
      }

      // If we reach here, try the alternative approach
      return await _loadFirebaseImageAlternative(url, timeout: timeout);
    } catch (e) {
      debugPrint('Firebase image loading error: $e');
      return _getSampleImage(); // Return a sample image as last resort
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

      // For tablets, we need stronger headers and timeout
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'Accept': 'image/*',
          'Access-Control-Allow-Origin': '*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://firebasestorage.googleapis.com/',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Origin': 'https://firebasestorage.googleapis.com',
          'User-Agent': 'Flutter PDF Generator'
        },
      ).timeout(const Duration(seconds: 20)); // Increased timeout for tablets

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint(
            'Successfully converted CrossPlatformImage for PDF: ${response.bodyBytes.length} bytes');
        return pw.MemoryImage(response.bodyBytes);
      }

      // If direct approach fails, try with a CORS proxy
      debugPrint('Direct image fetch failed, trying with CORS proxy');
      final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(imageUrl)}';
      final proxyResponse = await http
          .get(
            Uri.parse(proxyUrl),
          )
          .timeout(const Duration(seconds: 20));

      if (proxyResponse.statusCode == 200 &&
          proxyResponse.bodyBytes.isNotEmpty) {
        debugPrint(
            'Successfully loaded image via proxy: ${proxyResponse.bodyBytes.length} bytes');
        return pw.MemoryImage(proxyResponse.bodyBytes);
      }

      // Try an alternative proxy as last resort
      final altProxyUrl =
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(imageUrl)}';
      final altProxyResponse = await http.get(Uri.parse(altProxyUrl)).timeout(
            const Duration(seconds: 20),
          );

      if (altProxyResponse.statusCode == 200 &&
          altProxyResponse.bodyBytes.isNotEmpty) {
        debugPrint(
            'Successfully loaded image via alt proxy: ${altProxyResponse.bodyBytes.length} bytes');
        return pw.MemoryImage(altProxyResponse.bodyBytes);
      }
    } catch (e) {
      debugPrint('Error converting CrossPlatformImage for PDF: $e');
    }

    return null;
  }

  // Build the PDF header with company logo, SOP information, and total time (more compact)
  pw.Widget _buildPDFHeader(SOP sop, pw.MemoryImage? logoImage,
      pw.MemoryImage? qrCodeImage, PdfColor categoryColor) {
    // Calculate total SOP time
    final totalTime = _calculateTotalSOPTime(sop);

    // Remove emojis from the title
    final String cleanTitle = _removeEmojis(sop.title);

    // Create a lighter version of the category color
    final PdfColor lightCategoryColor = PdfColor(
      categoryColor.red,
      (categoryColor.green + 0.7).clamp(0, 1),
      (categoryColor.blue + 0.7).clamp(0, 1),
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(
          bottom: pw.BorderSide(color: categoryColor, width: 2),
        ),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            offset: const PdfPoint(0, 2),
            blurRadius: 3,
          )
        ],
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // QR Code and company logo on the left
          pw.Container(
            width: 120,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR Code with border
                pw.Container(
                  width: 50,
                  height: 50,
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: categoryColor, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
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
                pw.SizedBox(width: 10),
                // Company name/logo
                pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Elmos",
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                    pw.Text(
                      "Furniture",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SOP info - professional layout with title and metadata
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // SOP title with border and background
                pw.Container(
                  width: double.infinity,
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: lightCategoryColor,
                    border: pw.Border.all(color: categoryColor, width: 0.5),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    cleanTitle,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
                // Metadata row
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Revision and category
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(2)),
                              border: pw.Border.all(color: PdfColors.grey400),
                            ),
                            child: pw.Text(
                              'Rev: ${sop.revisionNumber}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: pw.BoxDecoration(
                              color: lightCategoryColor,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(2)),
                              border: pw.Border.all(color: categoryColor),
                            ),
                            child: pw.Text(
                              'Category: ${sop.categoryName ?? 'Uncategorized'}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: categoryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Updated date and estimated time
                      pw.Row(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue50,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(2)),
                              border: pw.Border.all(color: PdfColors.blue200),
                            ),
                            child: pw.Text(
                              'Updated: ${_formatDate(sop.updatedAt)}',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          if (totalTime > 0)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.purple50,
                                borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(2)),
                                border:
                                    pw.Border.all(color: PdfColors.purple200),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Text(
                                    'Est. Time: ',
                                    style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.purple900,
                                    ),
                                  ),
                                  pw.Text(
                                    _formatTime(totalTime),
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.purple900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build the summary section with just the SOP description
  pw.Widget _buildSummarySection(SOP sop, PdfColor categoryColor) {
    // Create a lighter version of the category color
    final PdfColor lightCategoryColor = PdfColor(
      categoryColor.red,
      (categoryColor.green + 0.7).clamp(0, 1),
      (categoryColor.blue + 0.7).clamp(0, 1),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      height: 60, // Increased height for more content
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: categoryColor, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            offset: const PdfPoint(1, 1),
            blurRadius: 2,
          )
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Description title with accent color
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: lightCategoryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: categoryColor),
            ),
            child: pw.Text(
              "DESCRIPTION",
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: categoryColor,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          // Description text
          pw.Expanded(
            child: pw.Text(
              sop.description,
              style: const pw.TextStyle(fontSize: 8),
              maxLines: 4,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  // New method to build steps for a specific page range with maximized space usage
  pw.Widget _buildStepsSection(SOP sop, Map<String, pw.MemoryImage?> stepImages,
      PdfColor categoryColor, int startIndex, int endIndex) {
    final steps = sop.steps;
    final List<pw.Widget> rows = [];

    // Create rows with 3 steps per row from the specified range
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
                    padding: const pw.EdgeInsets.fromLTRB(
                        3, 0, 3, 0), // Increased horizontal padding
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
      // Only add spacing if not the last row
      if (i + 3 < endIndex) {
        rows.add(pw.SizedBox(height: 5)); // Consistent spacing between rows
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  // Build an individual step card with improved borders, professional look, and better space usage
  pw.Widget _buildStepCard(SOPStep step, int stepNumber,
      pw.MemoryImage? stepImage, PdfColor categoryColor) {
    final cardHeight = 220.0; // Increased card height for more content
    final imageHeight = 140.0; // Increased image height
    final textContainerHeight = 60.0; // Increased text container height

    // Create a lighter version of the category color
    final PdfColor lightCategoryColor = PdfColor(
      categoryColor.red,
      (categoryColor.green + 0.7).clamp(0, 1),
      (categoryColor.blue + 0.7).clamp(0, 1),
    );

    // Log image status for debugging
    debugPrint('Building step card #$stepNumber for step ${step.id}');
    debugPrint('Image available: ${stepImage != null ? 'YES' : 'NO'}');

    // Create a placeholder image with step number as fallback
    pw.MemoryImage? placeholderImage;
    try {
      // Generate a simple placeholder with step number
      placeholderImage = _generatePlaceholderImage(stepNumber - 1);
      if (placeholderImage != null) {
        debugPrint('Created placeholder image for step #$stepNumber');
      }
    } catch (e) {
      debugPrint('Error creating placeholder: $e');
    }

    return pw.Container(
      height: cardHeight,
      decoration: pw.BoxDecoration(
        border:
            pw.Border.all(color: categoryColor, width: 1.5), // Thicker border
        borderRadius: const pw.BorderRadius.all(
            pw.Radius.circular(6)), // Increased corner radius
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey300,
            offset: const PdfPoint(2, 2),
            blurRadius: 2,
          )
        ],
      ),
      child: pw.ClipRRect(
        // Clip the content to match the rounded corners
        verticalRadius: 6,
        horizontalRadius: 6,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Step header with step number - more professional gradient-like appearance
            pw.Container(
              height: 20, // Increased height
              decoration: pw.BoxDecoration(
                color:
                    lightCategoryColor, // Use lighter version of category color
                border: pw.Border(
                  bottom: pw.BorderSide(
                    color: categoryColor,
                    width: 1.5,
                  ),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 40, // Wider for step number
                    height: 20,
                    decoration: pw.BoxDecoration(
                      color: categoryColor,
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      "$stepNumber",
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10, // Larger font
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      step.title,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9, // Increased font size
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                    ),
                  ),
                  // Add estimated time if available
                  if (step.estimatedTime != null)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 6),
                      child: pw.Text(
                        _formatTime(step.estimatedTime!),
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Image container with fixed height and improved borders
            pw.Container(
              width: double.infinity,
              height: imageHeight,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              padding:
                  const pw.EdgeInsets.all(3), // Added padding around the image
              alignment: pw.Alignment.center,
              child: _buildStepImage(stepImage, placeholderImage, stepNumber),
            ),

            // Text container with fixed height - maximized space for the text
            pw.Container(
              width: double.infinity,
              height: textContainerHeight,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4), // Increased padding
              color: PdfColors.white,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Present instruction text - maximized space for text
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      step.instruction,
                      style: const pw.TextStyle(
                          fontSize: 8), // Slightly larger text
                      overflow: pw.TextOverflow.clip,
                      maxLines: 7, // Increased number of lines
                    ),
                  ),

                  // If there are tools or hazards, show in styled format
                  if (step.stepTools.isNotEmpty ||
                      step.stepHazards.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Container(
                      width: double.infinity,
                      child: pw.Row(
                        children: [
                          if (step.stepTools.isNotEmpty)
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(2),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.blue50,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(2)),
                                  border:
                                      pw.Border.all(color: PdfColors.blue200),
                                ),
                                child: pw.Text(
                                  "Tools: ${step.stepTools.join(', ')}",
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.blue900,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                            ),
                          if (step.stepTools.isNotEmpty &&
                              step.stepHazards.isNotEmpty)
                            pw.SizedBox(width: 2),
                          if (step.stepHazards.isNotEmpty)
                            pw.Expanded(
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(2),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.red50,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(2)),
                                  border:
                                      pw.Border.all(color: PdfColors.red200),
                                ),
                                child: pw.Text(
                                  "Hazards: ${step.stepHazards.join(', ')}",
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.red900,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: pw.TextOverflow.clip,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the step image with better error handling
  pw.Widget _buildStepImage(pw.MemoryImage? stepImage,
      pw.MemoryImage? placeholderImage, int stepNumber) {
    // Try to use the actual step image first
    if (stepImage != null) {
      try {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          child: pw.Image(
            stepImage,
            fit: pw.BoxFit.contain,
          ),
        );
      } catch (e) {
        debugPrint('Error rendering step image in PDF: $e');
        // Fall through to placeholders if there's an error
      }
    }

    // If stepImage failed, try the generated placeholder
    if (placeholderImage != null) {
      try {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.grey300,
              width: 0.5,
            ),
          ),
          child: pw.Image(
            placeholderImage,
            fit: pw.BoxFit.contain,
          ),
        );
      } catch (e) {
        debugPrint('Error rendering placeholder image in PDF: $e');
        // Fall through to text fallback
      }
    }

    // Last resort - show a text-based placeholder
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(
          width: 40,
          height: 40,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(20),
            border: pw.Border.all(color: PdfColors.grey500),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            "$stepNumber",
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'No image available',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
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

  // Remove emojis from a string
  String _removeEmojis(String input) {
    // Use a more comprehensive emoji regex pattern
    // This pattern catches most emoji characters while preserving normal text and punctuation
    final emojiRegex = RegExp(
        r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])');

    // Replace emojis with empty string and trim any leading/trailing whitespace
    return input.replaceAll(emojiRegex, '').trim();
  }

  // Alternative method to load Firebase Storage images if the standard approach fails
  Future<pw.MemoryImage?> _loadFirebaseImageAlternative(String url,
      {int timeout = 15}) async {
    try {
      debugPrint('Using alternative Firebase image loading approach for: $url');

      // Try a more direct approach with download token if available
      String processedUrl = url;
      if (!url.contains('alt=media')) {
        processedUrl = url.contains('?') ? '$url&alt=media' : '$url?alt=media';
      }

      // Try with reduced security headers for tablets
      try {
        final response = await http.get(
          Uri.parse(processedUrl),
          headers: {
            'Accept': '*/*',
            'Origin': '*',
            'User-Agent': 'Mozilla/5.0 Flutter App',
          },
        ).timeout(Duration(seconds: timeout));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Basic request succeeded: ${response.bodyBytes.length} bytes');
          return pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Basic request failed: $e');
      }

      // Return a placeholder as fallback
      debugPrint(
          'All Firebase image loading approaches failed. Using placeholder image.');
      return _generatePlaceholderImage(
          url.hashCode % 10); // Use URL hash to get a consistent placeholder
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

  // New method to load images using the ImageNetwork widget
  Future<pw.MemoryImage?> _loadImageWithImageNetwork(String url) async {
    debugPrint('Loading image with ImageNetwork: $url');

    try {
      // Use ImageNetwork to handle CORS and other issues automatically
      if (kIsWeb) {
        // For web and tablets, we need to get the image bytes from ImageNetwork
        // Create a completer to wait for the image to load
        final completer = Completer<Uint8List?>();

        // We need a way to get the bytes from ImageNetwork
        // First try a direct HTTP request with the same headers ImageNetwork would use
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Accept': 'image/*',
              'Access-Control-Allow-Origin': '*',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': 'https://firebasestorage.googleapis.com/',
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              'User-Agent': 'Mozilla/5.0 Flutter ImageNetwork Widget',
              'Origin': 'https://firebasestorage.googleapis.com'
            },
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image directly: ${response.bodyBytes.length} bytes');
            return pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Direct HTTP request failed: $e');
        }

        // If direct request fails, try with CORS proxy
        try {
          final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
          final proxyResponse = await http
              .get(Uri.parse(proxyUrl))
              .timeout(const Duration(seconds: 20));

          if (proxyResponse.statusCode == 200 &&
              proxyResponse.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image via proxy: ${proxyResponse.bodyBytes.length} bytes');
            return pw.MemoryImage(proxyResponse.bodyBytes);
          }
        } catch (e) {
          debugPrint('Proxy approach failed: $e');
        }

        // As a last resort, try another proxy
        try {
          final altProxyUrl =
              'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
          final altProxyResponse = await http
              .get(Uri.parse(altProxyUrl))
              .timeout(const Duration(seconds: 20));

          if (altProxyResponse.statusCode == 200 &&
              altProxyResponse.bodyBytes.isNotEmpty) {
            debugPrint(
                'Successfully loaded image via alt proxy: ${altProxyResponse.bodyBytes.length} bytes');
            return pw.MemoryImage(altProxyResponse.bodyBytes);
          }
        } catch (e) {
          debugPrint('Alternative proxy approach failed: $e');
        }
      } else {
        // For non-web platforms, use regular http client
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'image/*',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Successfully loaded image with HTTP: ${response.bodyBytes.length} bytes');
          return pw.MemoryImage(response.bodyBytes);
        }
      }
    } catch (e) {
      debugPrint('Error loading image with ImageNetwork approach: $e');
    }

    return null;
  }

  // Preload all images aggressively to ensure they're available for PDF
  Future<void> _preloadAllImagesForPdf(
      SOP sop, Map<String, Uint8List> cache) async {
    debugPrint('Preloading all images for improved PDF generation...');

    for (final step in sop.steps) {
      if (step.imageUrl != null && step.imageUrl!.isNotEmpty) {
        try {
          // Skip if already in cache
          if (cache.containsKey(step.imageUrl!)) continue;

          // Try all methods to preload
          Uint8List? bytes;

          // Try data URL first
          if (step.imageUrl!.startsWith('data:image/')) {
            try {
              final String data = step.imageUrl!.split(',')[1];
              bytes = base64Decode(data);
              debugPrint('Preloaded data URL image (${bytes.length} bytes)');
            } catch (e) {
              debugPrint('Error preloading data URL: $e');
            }
          }

          // Try aggressive tablet approach
          if (bytes == null) {
            bytes = await _loadImageAggressiveForTablet(step.imageUrl!);
            if (bytes != null) {
              debugPrint(
                  'Preloaded image with aggressive approach (${bytes.length} bytes)');
            }
          }

          // Store in cache if successful
          if (bytes != null) {
            cache[step.imageUrl!] = bytes;
          }
        } catch (e) {
          debugPrint('Error preloading image: $e');
        }
      }
    }

    debugPrint('Preloading complete - ${cache.length} images in cache');
  }

  // Aggressive approach to load images specifically for tablets
  Future<Uint8List?> _loadImageAggressiveForTablet(String url) async {
    debugPrint('Using aggressive tablet-optimized image loading for: $url');

    // If it's a data URL, decode it directly
    if (url.startsWith('data:image/')) {
      try {
        final String data = url.split(',')[1];
        return base64Decode(data);
      } catch (e) {
        debugPrint('Error decoding data URL: $e');
      }
    }

    // Add asset URL handling
    if (url.startsWith('assets/')) {
      try {
        final ByteData data = await rootBundle.load(url);
        return data.buffer.asUint8List();
      } catch (e) {
        debugPrint('Error loading asset image: $e');
      }
    }

    // Enhanced multi-approach loading strategy - use all approaches in parallel for speed
    List<Future<Uint8List?>> approaches = [];

    // Approach 0: Enhanced direct approach specific for tablets
    approaches.add(() async {
      try {
        // Enhanced tablet-specific approach with more aggressive headers
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'image/*, */*',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Access-Control-Allow-Origin': '*',
            'Cache-Control': 'max-age=0',
            'User-Agent':
                'Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          },
        ).timeout(const Duration(seconds: 20)); // Longer timeout for tablets

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Enhanced tablet approach successful (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Enhanced tablet approach failed: $e');
      }
      return null;
    }());

    // Approach 1: Direct with enhanced headers
    approaches.add(() async {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': '*/*',
            'Access-Control-Allow-Origin': '*',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': url,
            'Origin': '*',
            'User-Agent': 'Mozilla/5.0 Flutter PDF Generator'
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Direct approach successful (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Direct approach failed: $e');
      }
      return null;
    }());

    // Approach 2: CORS Proxy
    approaches.add(() async {
      try {
        final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
        final response = await http
            .get(Uri.parse(proxyUrl))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'CORS proxy successful (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('CORS proxy failed: $e');
      }
      return null;
    }());

    // Approach 3: Alternative Proxy
    approaches.add(() async {
      try {
        final altProxyUrl =
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
        final response = await http
            .get(Uri.parse(altProxyUrl))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          debugPrint(
              'Alt proxy successful (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
      } catch (e) {
        debugPrint('Alt proxy failed: $e');
      }
      return null;
    }());

    // Approach 4: Firebase-specific handling
    if (url.contains('firebasestorage.googleapis.com') ||
        url.contains('appspot.com')) {
      approaches.add(() async {
        try {
          // Make sure we have the alt=media parameter
          String processedUrl = url;
          if (!url.contains('alt=media')) {
            processedUrl =
                url.contains('?') ? '$url&alt=media' : '$url?alt=media';
          }

          final response = await http.get(
            Uri.parse(processedUrl),
            headers: {
              'Accept': 'image/*',
              'Cache-Control': 'no-cache',
              'Origin': 'https://firebasestorage.googleapis.com',
              'User-Agent': 'Mozilla/5.0 (iPad; CPU OS 13_2_3 like Mac OS X)'
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Firebase-specific approach successful (${response.bodyBytes.length} bytes)');
            return response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Firebase-specific approach failed: $e');
        }
        return null;
      }());

      // Additional Firebase-specific approach with token handling
      approaches.add(() async {
        try {
          // Parse the URL to extract token if present
          final Uri uri = Uri.parse(url);
          final String token = uri.queryParameters['token'] ?? '';

          // Construct a direct download URL with the token
          final String downloadUrl =
              url.contains('?') ? '$url&alt=media' : '$url?alt=media';

          final response = await http.get(
            Uri.parse(downloadUrl),
            headers: {
              'Accept': 'image/*',
              'Authorization': token.isNotEmpty ? 'Bearer $token' : '',
              'Origin': 'https://firebasestorage.googleapis.com',
            },
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            debugPrint(
                'Firebase token approach successful (${response.bodyBytes.length} bytes)');
            return response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Firebase token approach failed: $e');
        }
        return null;
      }());
    }

    // Execute all approaches in parallel and use the first successful result
    final results = await Future.wait(approaches);
    for (final bytes in results) {
      if (bytes != null && bytes.isNotEmpty) {
        // Validate that the bytes are actually an image
        try {
          // Simple validation - check for common image header signatures
          if (bytes.length > 2) {
            // JPEG signature check (starts with FF D8)
            if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
              return bytes;
            }
            // PNG signature check (starts with 89 50 4E 47)
            else if (bytes.length > 4 &&
                bytes[0] == 0x89 &&
                bytes[1] == 0x50 &&
                bytes[2] == 0x4E &&
                bytes[3] == 0x47) {
              return bytes;
            }
            // If not a common format, trust the bytes since they came from a successful request
            else {
              debugPrint(
                  'Image format not explicitly recognized, but using data anyway');
              return bytes;
            }
          }
        } catch (e) {
          debugPrint('Error validating image bytes: $e');
        }

        // Even if validation fails, return the bytes since they came from a successful request
        return bytes;
      }
    }

    // All approaches failed
    debugPrint('All approaches failed to load the image: $url');
    return null;
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

  // Build the global information section into horizontal rows
  pw.Widget _buildGlobalInfoSection(SOP sop) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey50,
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // GLOBAL TOOLS SECTION
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  color: PdfColors.blue100,
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    "TOOLS",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 7,
                      color: PdfColors.blue900,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(3, 2, 3, 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                      sop.tools.isEmpty
                          ? "None specified"
                          : sop.tools.join(', '),
                      style: const pw.TextStyle(fontSize: 7)),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 6),

          // SAFETY REQUIREMENTS
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  color: PdfColors.red100,
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    "SAFETY",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 7,
                      color: PdfColors.red900,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(3, 2, 3, 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border.all(color: PdfColors.red200),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                      sop.safetyRequirements.isEmpty
                          ? "None specified"
                          : sop.safetyRequirements.join(', '),
                      style: const pw.TextStyle(fontSize: 7)),
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 6),

          // CAUTIONS & WARNINGS
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  color: PdfColors.amber100,
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(
                    "CAUTIONS",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 7,
                      color: PdfColors.amber900,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.fromLTRB(3, 2, 3, 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    border: pw.Border.all(color: PdfColors.amber),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                      sop.cautions.isEmpty
                          ? "None specified"
                          : sop.cautions.join(', '),
                      style: const pw.TextStyle(fontSize: 7)),
                ),
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
          pw.Text(
            "Printed on: ${_formatDate(DateTime.now())}",
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
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

  // Helper method to format dates
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
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
}
