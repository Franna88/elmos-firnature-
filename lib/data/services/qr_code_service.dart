import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import '../models/sop_model.dart';

/// Service to handle QR code generation and scanning for SOPs
class QRCodeService {
  /// Base URL for accessing SOPs via QR code
  /// This URL needs to point to your deployed web app on Firebase Hosting
  static const String baseUrl = 'https://elmos-furniture.web.app/mobile/sop/';

  /// Legacy URL scheme for deep linking in mobile apps
  /// Keep this for backward compatibility
  static const String legacyScheme = 'elmos-furniture://sop/';

  /// Generate a QR code data URL for a specific SOP
  /// This returns the data needed to create a QR code that points to this SOP
  String generateQRDataForSOP(String sopId) {
    return '$baseUrl$sopId';
  }

  /// Generate a QR code widget for a specific SOP
  /// This is useful for displaying the QR code in the app
  QrImageView generateQRWidget(String sopId, {double size = 200}) {
    final qrData = generateQRDataForSOP(sopId);

    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(16),
      errorStateBuilder: (context, error) {
        return Container(
          width: size,
          height: size,
          color: Colors.white,
          child: Center(
            child: Text(
              'Error generating QR code',
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        );
      },
    );
  }

  /// Generate a QR code image as a byte array
  /// This is useful for saving the QR code to a file or sending it to a printer
  Future<Uint8List?> generateQRImageBytes(String sopId, double size) async {
    try {
      final qrData = generateQRDataForSOP(sopId);
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      // Create an image from the QR code
      final imageSize = Size(size, size);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromPoints(
          const Offset(0, 0),
          Offset(imageSize.width, imageSize.height),
        ),
      );

      // Paint white background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );

      // Draw QR code
      qrPainter.paint(canvas, imageSize);
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        imageSize.width.toInt(),
        imageSize.height.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating QR code image: $e');
      return null;
    }
  }

  /// Extract the SOP ID from a QR code data string
  /// This is useful when scanning a QR code
  String? extractSOPIdFromQRData(String qrData) {
    // Check for web URL format first
    if (qrData.startsWith(baseUrl)) {
      return qrData.substring(baseUrl.length);
    }

    // Check for legacy deep link format as backup
    if (qrData.startsWith(legacyScheme)) {
      return qrData.substring(legacyScheme.length);
    }

    return null;
  }

  /// Parse a deep link URL to extract the SOP ID
  /// This is useful for handling deep links from QR codes
  String? parseSOPIdFromLink(String? link) {
    if (link == null) return null;

    // Check for web URL format first
    if (link.startsWith(baseUrl)) {
      return link.substring(baseUrl.length);
    }

    // Check for legacy deep link format as backup
    if (link.startsWith(legacyScheme)) {
      return link.substring(legacyScheme.length);
    }

    return null;
  }

  /// Converts a QR code widget to a data URL that can be embedded in HTML or SVG
  Future<String?> qrCodeToDataUrl(String sopId, double size) async {
    final bytes = await generateQRImageBytes(sopId, size);
    if (bytes != null) {
      final base64String = base64Encode(bytes);
      return 'data:image/png;base64,$base64String';
    }
    return null;
  }
}
