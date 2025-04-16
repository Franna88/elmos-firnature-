import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/sop_service.dart';

class ImageUploadTestScreen extends StatefulWidget {
  const ImageUploadTestScreen({super.key});

  @override
  State<ImageUploadTestScreen> createState() => _ImageUploadTestScreenState();
}

class _ImageUploadTestScreenState extends State<ImageUploadTestScreen> {
  String? _base64Image;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  final String _testSopId = 'test-sop-${DateTime.now().millisecondsSinceEpoch}';
  final String _testStepId =
      'test-step-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        setState(() {
          _base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadedImageUrl = null;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      final url = await sopService.uploadImageFromDataUrl(
        _base64Image!,
        _testSopId,
        _testStepId,
      );

      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Base64 Image Upload Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Base64 Image to Firebase Storage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Test SOP ID: $_testSopId\nTest Step ID: $_testStepId',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Select Image'),
                    ),
                    const SizedBox(height: 16),
                    if (_base64Image != null) ...[
                      const Text(
                        'Selected Image:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.memory(
                          base64Decode(_base64Image!.split(',')[1]),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _uploadImage,
                        child: _isUploading
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Uploading...'),
                                ],
                              )
                            : const Text('Upload to Firebase Storage'),
                      ),
                    ],
                    if (_uploadedImageUrl != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Uploaded Image URL:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          _uploadedImageUrl!,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Image from URL:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _uploadedImageUrl!.startsWith('data:image/')
                            ? Image.memory(
                                base64Decode(_uploadedImageUrl!.split(',')[1]),
                                fit: BoxFit.contain,
                              )
                            : Image.network(
                                _uploadedImageUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About This Test Page',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This page allows you to test uploading base64-encoded images to Firebase Storage. The process works as follows:\n\n'
                      '1. Select an image from your device\n'
                      '2. The image is converted to a base64 data URL\n'
                      '3. When you click upload, the SOPService.uploadImageFromDataUrl method is called\n'
                      '4. The method converts the base64 data back to binary and uploads it to Firebase Storage\n'
                      '5. The returned URL should be a Firebase Storage URL, not a base64 string\n\n'
                      'This implementation can be used throughout the app to store images properly in Firebase Storage.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
