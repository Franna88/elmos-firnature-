import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../data/services/sop_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../data/models/category_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/cross_platform_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import '../../../utils/permission_handler.dart';
import 'package:image/image.dart' as img;

class MobileSOPEditorScreen extends StatefulWidget {
  final String sopId;
  final int? initialStepIndex;

  const MobileSOPEditorScreen({
    super.key,
    required this.sopId,
    this.initialStepIndex,
  });

  @override
  State<MobileSOPEditorScreen> createState() => _MobileSOPEditorScreenState();
}

class _MobileSOPEditorScreenState extends State<MobileSOPEditorScreen> {
  late SOP _sop;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  int _currentStepIndex = -1; // -1 means editing SOP details, not steps
  int _selectedStepTab = 0; // Track selected step tab
  String? _tempImageUrl; // Store temporary image URL for new steps

  // Focus nodes
  final FocusNode _stepToolFocusNode = FocusNode();
  final FocusNode _stepHazardFocusNode = FocusNode();
  final FocusNode _sopToolFocusNode = FocusNode();
  final FocusNode _sopSafetyFocusNode = FocusNode();
  final FocusNode _sopCautionFocusNode = FocusNode();

  // Current section of the SOP being edited
  int _currentSection = 0;
  // Section titles - these will be updated based on category settings
  List<String> _sectionTitles = [
    'Basic Information',
    'Tools',
    'Safety Requirements',
    'Cautions',
    'Steps'
  ];

  // Store section visibility based on category settings
  Map<String, bool> _sectionVisibility = {
    'tools': true,
    'safety': true,
    'cautions': true,
  };

  // Store custom sections from selected category
  List<String> _customSections = [];

  // Store custom section contents
  Map<String, List<String>> _customSectionContent = {};

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _stepTitleController;
  late TextEditingController _stepInstructionController;
  late TextEditingController _stepHelpNoteController;
  // Estimated time controllers removed - no longer used
  // Tools and hazards for the current step being edited
  List<String> _currentStepTools = [];
  List<String> _currentStepHazards = [];
  // SOP-level tools, safety requirements, and cautions
  List<String> _sopTools = [];
  List<String> _sopSafetyRequirements = [];
  List<String> _sopCautions = [];
  // Thumbnail URL for the SOP
  String? _thumbnailUrl;
  // YouTube URL for the SOP
  String? _youtubeUrl;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _stepTitleController = TextEditingController();
    _stepInstructionController = TextEditingController();
    _stepHelpNoteController = TextEditingController();
    // Estimated time controllers removed - no longer used

    _loadSOP().then((_) {
      // If initialStepIndex is provided and valid, navigate to the Steps section and set the correct tab
      if (widget.initialStepIndex != null &&
          widget.initialStepIndex! >= 0 &&
          _sop.steps.isNotEmpty &&
          widget.initialStepIndex! < _sop.steps.length) {
        // Schedule the navigation after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Navigate to the Steps section (last section in the list)
          setState(() {
            _currentSection =
                _sectionTitles.length - 1; // Steps is always the last section
            // Ensure the selected step tab is within bounds
            _selectedStepTab =
                widget.initialStepIndex!.clamp(0, _sop.steps.length - 1);
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _stepTitleController.dispose();
    _stepInstructionController.dispose();
    _stepHelpNoteController.dispose();
    // Estimated time controllers removed - no longer used

    // Dispose focus nodes
    _stepToolFocusNode.dispose();
    _stepHazardFocusNode.dispose();
    _sopToolFocusNode.dispose();
    _sopSafetyFocusNode.dispose();
    _sopCautionFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      if (widget.sopId == 'new') {
        // Create a new SOP locally (without saving to Firebase)
        Future.microtask(() {
          final newSop = sopService.createLocalSop(
            '',
            '',
            '', // Empty categoryId - will be selected by user
          );

          if (mounted) {
            setState(
              () {
                _sop = newSop;
                // Initialize controllers with empty strings
                _titleController = TextEditingController();
                _descriptionController = TextEditingController();
                _youtubeUrlController = TextEditingController();
                _stepTitleController = TextEditingController();
                _stepInstructionController = TextEditingController();
                _stepHelpNoteController = TextEditingController();
                // Estimated time controllers removed - no longer used
                _currentStepTools = [];
                _currentStepHazards = [];
                _sopTools = [];
                _sopSafetyRequirements = [];
                _sopCautions = [];
                _customSectionContent = {};
                _thumbnailUrl =
                    null; // Initialize thumbnail URL to null for new SOPs
                _youtubeUrl =
                    null; // Initialize YouTube URL to null for new SOPs

                // Set default section visibility for new SOPs
                _sectionVisibility = {
                  'tools': true,
                  'safety': true,
                  'cautions': true,
                };

                // Initialize section titles
                _rebuildSectionTitles();

                _isLoading = false;
              },
            );
          }
        });
        return;
      } else {
        // Load existing SOP
        final existingSop = sopService.getSopById(widget.sopId);
        if (existingSop == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SOP not found')),
            );
            context.go('/mobile/sops');
            return;
          }
        }
        _sop = existingSop!;
        _sopTools = List.from(_sop.tools);
        _sopSafetyRequirements = List.from(_sop.safetyRequirements);
        _sopCautions = List.from(_sop.cautions);
        _customSectionContent = Map.from(_sop.customSectionContent);
        _thumbnailUrl =
            _sop.thumbnailUrl; // Initialize thumbnail URL from existing SOP
        _youtubeUrl =
            _sop.youtubeUrl; // Initialize YouTube URL from existing SOP

        // Update sections for selected category if a category is set
        if (_sop.categoryId.isNotEmpty) {
          _updateSectionsForCategory(_sop.categoryId);
        } else {
          // Set default visibility and build section titles
          _sectionVisibility = {
            'tools': true,
            'safety': true,
            'cautions': true,
          };
          _rebuildSectionTitles();
        }
      }

      // Initialize controllers
      _titleController = TextEditingController(text: _sop.title);
      _descriptionController = TextEditingController(text: _sop.description);
      _youtubeUrlController =
          TextEditingController(text: _sop.youtubeUrl ?? '');
      _stepTitleController = TextEditingController();
      _stepInstructionController = TextEditingController();
      _stepHelpNoteController = TextEditingController();
      // Estimated time controllers removed - no longer used

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading SOP: $e')),
        );
        context.go('/mobile/sops');
      }
    }
  }

  /// Validates the current section's fields
  bool _validateCurrentSection() {
    // Basic Information is always the first section
    if (_currentSection == 0) {
      if (_titleController.text.isEmpty ||
          _descriptionController.text.isEmpty ||
          _sop.categoryId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields in General Info'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      return true;
    }

    // Steps is always the last section
    if (_currentSection == _sectionTitles.length - 1) {
      if (_sop.steps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one step'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      return true;
    }

    // For all other sections (standard and custom), no validation is required as they're optional
    return true;
  }

  /// Updates the SOP locally without saving to Firebase
  Future<void> _updateSOPLocally() async {
    setState(() {
      _sop = _sop.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        categoryId: _sop.categoryId,
        updatedAt: DateTime.now(),
        tools: _sopTools,
        safetyRequirements: _sopSafetyRequirements,
        cautions: _sopCautions,
        thumbnailUrl: _thumbnailUrl,
        youtubeUrl: _youtubeUrlController.text.isEmpty
            ? null
            : _youtubeUrlController.text,
        customSectionContent: _customSectionContent,
      );
    });
    // Return a completed future to allow chaining
    return Future.value();
  }

  /// Saves the SOP to Firebase
  Future<void> _saveSOP() async {
    // Set loading state to prevent multiple submissions
    setState(() {
      _isLoading = true;
    });

    try {
      // First update locally to ensure we have the latest data
      await _updateSOPLocally();

      // Get the SOP service from provider
      final sopService = Provider.of<SOPService>(context, listen: false);

      // For new SOPs, use saveLocalSopToFirebase to save it to Firebase
      // For existing SOPs, use updateSop to update it in Firebase
      if (widget.sopId == 'new') {
        final savedSop = await sopService.saveLocalSopToFirebase(_sop);
        // Update the local SOP with the Firebase ID and any processed image URLs
        setState(() {
          _sop = savedSop;
        });
      } else {
        await sopService.updateSop(_sop);
      }

      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOP saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Hide loading indicator on error
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving SOP: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Open step editor
  void _editStep(int index) {
    if (index < _sop.steps.length) {
      final step = _sop.steps[index];
      _stepTitleController.text = step.title;
      _stepInstructionController.text = step.instruction;
      _stepHelpNoteController.text = step.helpNote ?? '';

      // Estimated time parsing removed - no longer used

      _currentStepTools = List.from(step.stepTools);
      _currentStepHazards = List.from(step.stepHazards);
    } else {
      _stepTitleController.text = '';
      _stepInstructionController.text = '';
      _stepHelpNoteController.text = '';
      // Estimated time controllers removed - no longer used
      _currentStepTools = [];
      _currentStepHazards = [];
    }

    setState(() {
      _currentStepIndex = index;
    });
  }

  // Save current step
  Future<void> _saveStep() async {
    if (_stepTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Step title cannot be empty')),
      );
      return;
    }

    // Show loading indicator and prevent multiple submissions
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      List<SOPStep> updatedSteps = List.from(_sop.steps);

      // Generate a step ID
      final String stepId = _currentStepIndex < _sop.steps.length
          ? _sop.steps[_currentStepIndex].id
          : '${_sop.id}_step_${DateTime.now().millisecondsSinceEpoch}';

      final newStep = SOPStep(
        id: stepId,
        title: _stepTitleController.text,
        instruction: _stepInstructionController.text,
        imageUrl: _currentStepIndex < _sop.steps.length
            ? _sop.steps[_currentStepIndex].imageUrl
            : _tempImageUrl, // Use the temp image URL for new steps
        helpNote: _stepHelpNoteController.text.isEmpty
            ? null
            : _stepHelpNoteController.text,
        estimatedTime: null, // Estimated time removed from UI
        stepTools: _currentStepTools,
        stepHazards: _currentStepHazards,
      );

      if (_currentStepIndex < updatedSteps.length) {
        // Update existing step
        updatedSteps[_currentStepIndex] = newStep;
      } else {
        // Add new step
        updatedSteps.add(newStep);
      }

      // Store the correct step index for navigation after saving
      final int savedStepIndex = _currentStepIndex < _sop.steps.length
          ? _currentStepIndex // For existing step, use current index
          : updatedSteps.length -
              1; // For new step, use the index of the newly added step

      final updatedSop = _sop.copyWith(steps: updatedSteps);

      // First, update locally
      await sopService.updateSopLocally(updatedSop);

      SOP finalSop;
      // For new SOPs, save to Firebase first to ensure the document exists
      if (widget.sopId == 'new') {
        finalSop = await sopService.saveLocalSopToFirebase(updatedSop);
        if (kDebugMode) {
          print('New SOP saved to Firebase with ID: ${finalSop.id}');
        }
      } else {
        // For existing SOPs, just update
        await sopService.updateSop(updatedSop);
        finalSop = updatedSop;
      }

      setState(() {
        _sop = finalSop;
        _tempImageUrl = null; // Clear temporary image URL
        _isLoading = false; // Hide loading indicator
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Step saved successfully')),
      );

      // Navigate back to SOP viewer with the saved step index
      if (widget.sopId != 'new') {
        if (kDebugMode) {
          print('Navigating back to step index: $savedStepIndex');
        }
        context.go('/mobile/sop/${finalSop.id}?stepIndex=$savedStepIndex');
      } else {
        // For new SOPs, return to the main editor form
        setState(() {
          _currentStepIndex = -1;
        });
      }
    } catch (e) {
      // Hide loading indicator even if there's an error
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving step: $e')),
      );
    }
  }

  // Reorder steps
  void _reorderSteps(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final SOPStep step = _sop.steps[oldIndex];
      final List<SOPStep> updatedSteps = List.from(_sop.steps)
        ..removeAt(oldIndex)
        ..insert(newIndex, step);

      _sop = _sop.copyWith(steps: updatedSteps);
    });
  }

  // Add a tool to the SOP
  void _addSOPTool(String tool) {
    if (tool.isNotEmpty && !_sopTools.contains(tool)) {
      setState(() {
        _sopTools.add(tool);
      });
    }
  }

  // Remove a tool from the SOP
  void _removeSOPTool(String tool) {
    setState(() {
      _sopTools.remove(tool);
    });
  }

  // Add a safety requirement to the SOP
  void _addSOPSafetyRequirement(String requirement) {
    if (requirement.isNotEmpty &&
        !_sopSafetyRequirements.contains(requirement)) {
      setState(() {
        _sopSafetyRequirements.add(requirement);
      });
    }
  }

  // Remove a safety requirement from the SOP
  void _removeSOPSafetyRequirement(String requirement) {
    setState(() {
      _sopSafetyRequirements.remove(requirement);
    });
  }

  // Add a caution to the SOP
  void _addSOPCaution(String caution) {
    if (caution.isNotEmpty && !_sopCautions.contains(caution)) {
      setState(() {
        _sopCautions.add(caution);
      });
    }
  }

  // Remove a caution from the SOP
  void _removeSOPCaution(String caution) {
    setState(() {
      _sopCautions.remove(caution);
    });
  }

  // Delete a step
  Future<void> _deleteStep(int index) async {
    if (index >= 0 && index < _sop.steps.length) {
      final sopService = Provider.of<SOPService>(context, listen: false);
      List<SOPStep> updatedSteps = List.from(_sop.steps);
      updatedSteps.removeAt(index);

      final updatedSop = _sop.copyWith(steps: updatedSteps);

      try {
        await sopService.updateSopLocally(updatedSop);
        setState(() {
          _sop = updatedSop;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting step: $e')),
        );
      }
    }
  }

  // Upload image for a step
  Future<void> _uploadStepImage() async {
    await _showImageSourceDialog((ImageSource source) async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        await _processPickedImage(image);
      }
    });
  }

  // Upload thumbnail image for the SOP
  Future<void> _uploadSOPThumbnail() async {
    if (kIsWeb) {
      // For web, use gallery directly since camera is inconsistent
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processThumbnailImage(image);
      }
      return;
    }

    // For native Android, show proper source selection
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await PermissionHandler.pickImage(
                      context, ImageSource.gallery);
                  if (image != null) {
                    await _processThumbnailImage(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await PermissionHandler.pickImage(
                      context, ImageSource.camera);
                  if (image != null) {
                    await _processThumbnailImage(image);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Process the thumbnail image
  Future<void> _processThumbnailImage(XFile image) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      // Optimize the image before uploading
      final Uint8List optimizedBytes =
          await _optimizeImage(image, isThumbnail: true);

      // Create data URL for the optimized image
      final String dataUrl =
          'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';

      // Upload the thumbnail to Firebase Storage
      final String thumbnailId =
          'thumbnail-${DateTime.now().millisecondsSinceEpoch}';
      final String? imageUrl = await sopService.uploadImageFromDataUrl(
          dataUrl, _sop.id, thumbnailId);

      if (kDebugMode) {
        print('Uploaded thumbnail, received URL: $imageUrl');
      }

      setState(() {
        _thumbnailUrl = imageUrl;
        _isLoading = false;
      });

      // Update the SOP with the new thumbnail URL
      final updatedSop = _sop.copyWith(thumbnailUrl: imageUrl);
      await sopService.updateSop(updatedSop);

      setState(() {
        _sop = updatedSop;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thumbnail uploaded successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error uploading thumbnail: $e')),
      // );
    }
  }

  // Show a dialog to select image source (camera or gallery)
  Future<void> _showImageSourceDialog(
      Function(ImageSource) onSourceSelected) async {
    if (kIsWeb) {
      // On mobile web, we'll just use gallery option directly
      // as camera support is inconsistent across mobile browsers
      onSourceSelected(ImageSource.gallery);
      return;
    }

    // For native Android, show a proper dialog with both options
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await PermissionHandler.pickImage(
                      context, ImageSource.gallery);
                  if (image != null) {
                    await _processPickedImage(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await PermissionHandler.pickImage(
                      context, ImageSource.camera);
                  if (image != null) {
                    await _processPickedImage(image);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Process the image picked from camera or gallery
  Future<void> _processPickedImage(XFile image) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);

      // Optimize the image before uploading
      final Uint8List optimizedBytes =
          await _optimizeImage(image, isThumbnail: true);

      // Create data URL for the optimized image
      final String dataUrl =
          'data:image/jpeg;base64,${base64Encode(optimizedBytes)}';

      // If this is a new SOP (not saved to Firebase yet), store the image as a base64 string temporarily
      if (widget.sopId == 'new' && !_sop.id.startsWith('firebase')) {
        // Just store the data URL directly as the image URL
        setState(() {
          _tempImageUrl = dataUrl;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image added - save step to apply changes')),
        );
        return;
      }

      // Generate a step ID if this is a new step not yet saved
      final String stepId = _currentStepIndex < _sop.steps.length
          ? _sop.steps[_currentStepIndex].id
          : '${_sop.id}_step_${DateTime.now().millisecondsSinceEpoch}';

      // Upload to Firebase Storage and get the URL
      final String? imageUrl =
          await sopService.uploadImageFromDataUrl(dataUrl, _sop.id, stepId);

      if (kDebugMode) {
        print('Uploaded image for step $stepId: $imageUrl');
      }

      // If editing an existing step, update that step
      if (_currentStepIndex < _sop.steps.length) {
        List<SOPStep> updatedSteps = List.from(_sop.steps);
        final currentStep = updatedSteps[_currentStepIndex];
        updatedSteps[_currentStepIndex] =
            currentStep.copyWith(imageUrl: dataUrl);
        setState(() {
          _sop = _sop.copyWith(steps: updatedSteps);
          _isLoading = false;
        });
      } else {
        setState(() {
          _tempImageUrl = dataUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    }
  }

  // Method to build the content for the current section
  Widget _buildCurrentSectionContent() {
    // Basic Information is always the first section
    if (_currentSection == 0) {
      return _buildBasicInfoSection();
    }

    // Steps is always the last section
    if (_currentSection == _sectionTitles.length - 1) {
      return _buildStepsSection();
    }

    // Handle standard sections
    final sectionTitle = _sectionTitles[_currentSection];

    if (sectionTitle == 'Tools') {
      return _buildToolsSection();
    } else if (sectionTitle == 'Safety Requirements') {
      return _buildSafetyRequirementsSection();
    } else if (sectionTitle == 'Cautions') {
      return _buildCautionsSection();
    }

    // If not a standard section, it must be a custom section
    return _buildCustomSection(sectionTitle);
  }

  // Method to build a custom section UI
  Widget _buildCustomSection(String sectionTitle) {
    final TextEditingController itemController = TextEditingController();
    final FocusNode itemFocusNode = FocusNode();

    // Ensure section exists in content map
    if (!_customSectionContent.containsKey(sectionTitle)) {
      _customSectionContent[sectionTitle] = [];
    }

    List<String> sectionItems = _customSectionContent[sectionTitle] ?? [];

    // Request focus when this section is built
    Future.microtask(() => itemFocusNode.requestFocus());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add items for "$sectionTitle" section (Optional)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemController,
                  focusNode: itemFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Add $sectionTitle item',
                    border: const OutlineInputBorder(),
                    hintText: 'E.g., Required item or information',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (itemController.text.isNotEmpty) {
                    setState(() {
                      if (!sectionItems.contains(itemController.text)) {
                        sectionItems.add(itemController.text);
                        _customSectionContent[sectionTitle] = sectionItems;
                      }
                    });
                    itemController.clear();
                    itemFocusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '$sectionTitle items added:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sectionItems.isEmpty
                ? Center(
                    child: Text(
                      'No $sectionTitle items added yet. Add some using the field above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: sectionItems.length,
                    itemBuilder: (context, index) {
                      final item = sectionItems[index];
                      return _buildItemChip(
                        item,
                        onDelete: () {
                          setState(() {
                            sectionItems.remove(item);
                            _customSectionContent[sectionTitle] = sectionItems;
                          });
                        },
                        color: Colors.purple,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // SOP Build Step 1: Basic Information
  Widget _buildBasicInfoSection() {
    final categoryService = Provider.of<CategoryService>(context);
    final categories = categoryService.categories
        .fold<Map<String, Category>>({}, (map, cat) {
          map[cat.name] = cat;
          return map;
        })
        .values
        .toList();

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Enter the basic information about this SOP',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // SOP Thumbnail
            Center(
              child: Column(
                children: [
                  const Text(
                    'SOP Thumbnail',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add an image that represents the end product or result of this SOP',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Thumbnail image or placeholder
                  _buildThumbnailDisplay(),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _uploadSOPThumbnail,
                    icon: const Icon(Icons.upload),
                    label: Text(_thumbnailUrl != null
                        ? 'Change Thumbnail'
                        : 'Upload Thumbnail'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'SOP Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'Describe the purpose of this SOP'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _youtubeUrlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube URL (Optional)',
                    hintText: 'https://youtube.com/watch?v=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.video_library),
                  ),
                  onChanged: (value) {
                    // Force refresh to update QR code
                    setState(() {});
                  },
                ),
                if (_youtubeUrlController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: !_isValidYoutubeUrl(_youtubeUrlController.text)
                        ? const Text(
                            'Please enter a valid YouTube URL',
                            style: TextStyle(color: Colors.red),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 8.0),
                              const Text(
                                'YouTube Video QR Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Center(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: _generateYouTubeQRCode(),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              const Text(
                                'This QR code will be displayed on the printable SOP',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _sop.categoryId.isNotEmpty ? _sop.categoryId : null,
              hint: const Text('Select a category'),
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
              onChanged: (value) {
                if (value != null) {
                  // Get the category service to access the category details
                  final categoryService =
                      Provider.of<CategoryService>(context, listen: false);
                  final selectedCategory =
                      categoryService.getCategoryById(value);

                  setState(() {
                    // Update both categoryId and categoryName in the SOP
                    _sop = _sop.copyWith(
                      categoryId: value,
                      categoryName: selectedCategory?.name,
                    );
                  });

                  // Update sections based on the selected category
                  _updateSectionsForCategory(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Add a method to generate a QR code for the YouTube URL
  QrImageView? _generateYouTubeQRCode() {
    if (_youtubeUrlController.text.isEmpty) {
      return null;
    }

    // Check if it's a valid YouTube URL
    if (!_isValidYoutubeUrl(_youtubeUrlController.text)) {
      return null;
    }

    return QrImageView(
      data: _youtubeUrlController.text,
      version: QrVersions.auto,
      size: 150.0,
      backgroundColor: Colors.white,
    );
  }

  // Validate YouTube URL
  bool _isValidYoutubeUrl(String url) {
    // This is a simple validation, you might want to improve it
    return url.contains('youtube.com/') || url.contains('youtu.be/');
  }

  // SOP Build Step 2: Tools
  Widget _buildToolsSection() {
    final TextEditingController toolController = TextEditingController();

    // Request focus when this section is built
    Future.microtask(() => _sopToolFocusNode.requestFocus());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add tools required for this SOP (Optional)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: toolController,
                  focusNode: _sopToolFocusNode,
                  decoration: const InputDecoration(
                      labelText: 'Tool name',
                      border: OutlineInputBorder(),
                      hintText: 'E.g., Screwdriver, Hammer'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (toolController.text.isNotEmpty) {
                    _addSOPTool(toolController.text);
                    toolController.clear();
                    // Maintain focus on text field
                    _sopToolFocusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Tools added:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sopTools.isEmpty
                ? const Center(
                    child: Text(
                      'No tools added yet. Add some tools using the field above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _sopTools.length,
                    itemBuilder: (context, index) {
                      final tool = _sopTools[index];
                      return _buildItemChip(
                        tool,
                        onDelete: () => _removeSOPTool(tool),
                        color: Colors.blue,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // SOP Build Step 3: Safety Requirements
  Widget _buildSafetyRequirementsSection() {
    final TextEditingController requirementController = TextEditingController();

    // Request focus when this section is built
    Future.microtask(() => _sopSafetyFocusNode.requestFocus());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add safety requirements for this SOP (Optional)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: requirementController,
                  focusNode: _sopSafetyFocusNode,
                  decoration: const InputDecoration(
                      labelText: 'Safety requirement',
                      border: OutlineInputBorder(),
                      hintText: 'E.g., Wear safety glasses'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (requirementController.text.isNotEmpty) {
                    _addSOPSafetyRequirement(requirementController.text);
                    requirementController.clear();
                    // Maintain focus on text field
                    _sopSafetyFocusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Safety requirements added:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sopSafetyRequirements.isEmpty
                ? const Center(
                    child: Text(
                      'No safety requirements added yet. Add some using the field above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _sopSafetyRequirements.length,
                    itemBuilder: (context, index) {
                      final requirement = _sopSafetyRequirements[index];
                      return _buildItemChip(
                        requirement,
                        onDelete: () =>
                            _removeSOPSafetyRequirement(requirement),
                        color: Colors.green,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // SOP Build Step 4: Cautions
  Widget _buildCautionsSection() {
    final TextEditingController cautionController = TextEditingController();

    // Request focus when this section is built
    Future.microtask(() => _sopCautionFocusNode.requestFocus());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add cautions and warnings for this SOP (Optional)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cautionController,
                  focusNode: _sopCautionFocusNode,
                  decoration: const InputDecoration(
                      labelText: 'Caution',
                      border: OutlineInputBorder(),
                      hintText: 'E.g., Do not overtighten fasteners'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (cautionController.text.isNotEmpty) {
                    _addSOPCaution(cautionController.text);
                    cautionController.clear();
                    // Maintain focus on text field
                    _sopCautionFocusNode.requestFocus();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Cautions added:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sopCautions.isEmpty
                ? const Center(
                    child: Text(
                      'No cautions added yet. Add some using the field above.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _sopCautions.length,
                    itemBuilder: (context, index) {
                      final caution = _sopCautions[index];
                      return _buildItemChip(
                        caution,
                        onDelete: () => _removeSOPCaution(caution),
                        color: Colors.orange,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // SOP Build Step 5: Steps with Tabbed View
  Widget _buildStepsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Steps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _sop.steps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No steps added yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the "+" icon in the app bar to add your first step.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tab navigation for steps
                      Container(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sop.steps.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedStepTab = index;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedStepTab == index
                                      ? AppColors.primaryBlue
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _selectedStepTab == index
                                            ? Colors.white.withOpacity(0.3)
                                            : AppColors.primaryBlue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: _selectedStepTab == index
                                                ? Colors.white
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _sop.steps[index].title.length > 15
                                          ? '${_sop.steps[index].title.substring(0, 15)}...'
                                          : _sop.steps[index].title,
                                      style: TextStyle(
                                        color: _selectedStepTab == index
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: _selectedStepTab == index
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Currently selected step details
                      Expanded(
                        child: _sop.steps.isNotEmpty &&
                                _selectedStepTab < _sop.steps.length
                            ? _buildStepCard(
                                _sop.steps[_selectedStepTab], _selectedStepTab)
                            : Container(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Build a card to display step details in the tabbed view
  Widget _buildStepCard(SOPStep step, int index) {
    return Card(
      key: ValueKey(
          'step_card_$index'), // Add unique key to force rebuild when step changes
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (step.estimatedTime != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.blue.withOpacity(0.5)),
                        ),
                        child: Text(
                          _formatTime(step.estimatedTime!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step image
                    if (step.imageUrl != null && step.imageUrl!.isNotEmpty)
                      Container(
                        height: 400,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildImageWidget(step.imageUrl),
                        ),
                      ),

                    // Instructions
                    const Text(
                      'Instructions:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(step.instruction),
                    const SizedBox(height: 16),

                    // Help note if exists
                    if (step.helpNote != null && step.helpNote!.isNotEmpty) ...[
                      const Text(
                        'Help Note:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow[700]!),
                        ),
                        child: Text(step.helpNote!),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Reorder button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reorder Steps'),
                        content: Container(
                          width: double.maxFinite,
                          height: 300,
                          child: ReorderableListView.builder(
                            itemCount: _sop.steps.length,
                            onReorder: _reorderSteps,
                            itemBuilder: (context, i) {
                              return ListTile(
                                key: ValueKey(_sop.steps[i].id),
                                leading: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red[700],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(_sop.steps[i].title),
                                trailing: const Icon(Icons.drag_handle),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('DONE'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.reorder),
                  label: const Text('Reorder Steps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build a chip for displaying a removable item
  Widget _buildItemChip(String text,
      {required Function() onDelete, required Color color}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Chip(
        label: Text(text),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDelete,
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.5)),
        labelStyle: TextStyle(color: color),
      ),
    );
  }

  // Show confirmation dialog for step deletion
  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Step'),
        content: const Text('Are you sure you want to delete this step?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteStep(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentStepIndex == -1) {
      // Show loading screen only when loading the entire SOP (not when editing a step)
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.sopId == 'new' ? 'Create New SOP' : 'Edit SOP',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If we're in step editor mode, show the step editor
    if (_currentStepIndex >= 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _currentStepIndex >= _sop.steps.length
                ? 'Add New Step'
                : 'Edit Step ${_currentStepIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isLoading
                ? null // Disable back button when loading
                : () {
                    if (kDebugMode) {
                      print(
                          'Back button: navigating to step index: $_currentStepIndex');
                    }
                    context.go(
                        '/mobile/sop/${_sop.id}?stepIndex=${_currentStepIndex}');
                  },
          ),
          actions: [
            // Save step button in app bar
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveStep,
              tooltip: 'Save Step',
            ),
            // Delete step button in app bar (only for existing steps)
            if (_currentStepIndex < _sop.steps.length)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _isLoading
                    ? null
                    : () => _showDeleteConfirmation(_currentStepIndex),
                tooltip: 'Delete Step',
              ),
          ],
        ),
        body: _buildStepEditorForm(),
      );
    }

    // Otherwise, show the appropriate section of the SOP form
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.sopId == 'new' ? 'Create New SOP' : 'Edit SOP',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.sopId == 'new') {
              // For new SOPs, navigate through sections or exit to SOPs screen
              if (_currentSection > 0) {
                // Navigate to previous section
                setState(() {
                  _currentSection--;
                });
              } else {
                // Exit to SOPs screen
                context.go('/mobile/sops');
              }
            } else {
              // For existing SOPs, return to the SOP viewer
              context.go('/mobile/sop/${widget.sopId}');
            }
          },
        ),
        actions: [
          // Add Step button - only show when in steps section
          if (_currentSection == _sectionTitles.length - 1) // Steps section
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _editStep(_sop.steps.length); // Create new step
              },
              tooltip: 'Add Step',
            ),
          // Save button
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading
                ? null
                : () {
                    if (widget.sopId == 'new') {
                      // For new SOPs, save the SOP
                      if (_validateCurrentSection()) {
                        _updateSOPLocally().then((_) {
                          _saveSOP();
                        });
                      }
                    } else {
                      // For existing SOPs, save changes
                      if (_validateCurrentSection()) {
                        _updateSOPLocally().then((_) {
                          _saveSOP();
                        });
                      }
                    }
                  },
            tooltip: widget.sopId == 'new' ? 'Save SOP' : 'Save Changes',
          ),
          // Only show delete button for existing SOPs (not new ones)
          if (widget.sopId != 'new')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteConfirmationDialog,
              tooltip: 'Delete SOP',
            ),
        ],
      ),
      body: Column(
        children: [
          // Current section content
          Expanded(
            child: _buildCurrentSectionContent(),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.sopId == 'new' && _currentSection > 0)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentSection--;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                    ),
                  )
                else
                  const SizedBox(width: 100), // Placeholder for spacing

                // For new SOPs, show Next/Save navigation
                if (widget.sopId == 'new')
                  _currentSection < _sectionTitles.length - 1
                      ? ElevatedButton.icon(
                          onPressed: () {
                            // Validate current section before proceeding
                            if (_validateCurrentSection()) {
                              // Update SOP locally before moving to next section
                              _updateSOPLocally().then((_) {
                                setState(() {
                                  _currentSection++;
                                });
                              });
                            }
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : const SizedBox
                          .shrink() // Hide save button for new SOPs in last section
                // For existing SOPs, don't show save button at bottom
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before deleting the SOP
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SOP'),
        content: const Text(
          'Are you sure you want to delete this SOP? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSOP();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  /// Deletes the SOP from Firebase
  Future<void> _deleteSOP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sopService = Provider.of<SOPService>(context, listen: false);
      await sopService.deleteSop(_sop.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOP deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to SOPs list
        context.go('/mobile/sops');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting SOP: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to format time in HH:MM:SS format
  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    String hourStr = hours > 0 ? '${hours}h ' : '';
    String minStr = minutes > 0 ? '${minutes}m ' : '';
    String secStr = seconds > 0 ? '${seconds}s' : '';

    // If all are zero, show 0s
    if (hours == 0 && minutes == 0 && seconds == 0) {
      return '0s';
    }

    return '$hourStr$minStr$secStr'.trim();
  }

  // Build the step editor form
  Widget _buildStepEditorForm() {
    final bool isNewStep = _currentStepIndex >= _sop.steps.length;
    // For existing steps, use the step's imageUrl, for new steps use _tempImageUrl
    final String imageUrl = !isNewStep && _currentStepIndex < _sop.steps.length
        ? _sop.steps[_currentStepIndex].imageUrl ?? ''
        : _tempImageUrl ?? '';

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Step Title
              TextFormField(
                controller: _stepTitleController,
                decoration: const InputDecoration(
                  labelText: 'Step Title',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isLoading,
              ),

              // Step Image (moved after title to match SOP view layout)
              const SizedBox(height: 24),
              const Text(
                'Step Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (imageUrl.isNotEmpty)
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildImageWidget(imageUrl),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No image added'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadStepImage,
                icon: const Icon(Icons.image),
                label: Text(imageUrl.isNotEmpty ? 'Change Image' : 'Add Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
              ),

              // Step Instructions (moved after image to match SOP view layout)
              const SizedBox(height: 24),
              TextFormField(
                controller: _stepInstructionController,
                decoration: const InputDecoration(
                  labelText: 'Step Instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stepHelpNoteController,
                decoration: const InputDecoration(
                  labelText: 'Help Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isLoading,
              ),

              // Save button removed - now in app bar
              // Add extra space at the bottom for the loading overlay
              if (_isLoading) const SizedBox(height: 80),
            ],
          ),
        ),
        // Full-screen loading overlay when saving (semi-transparent)
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Saving step...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_tempImageUrl != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Uploading image...',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Update the _buildImageWidget method to use CrossPlatformImage
  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        width: double.infinity,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CrossPlatformImage(
          key: ValueKey(
              imageUrl), // Add unique key to force rebuild when image changes
          imageUrl: imageUrl,
          width: constraints.maxWidth,
          height: 400,
          fit: BoxFit.contain,
        );
      },
    );
  }

  // Update thumbnail display code
  Widget _buildThumbnailDisplay() {
    return GestureDetector(
      onTap: () => _uploadSOPThumbnail(),
      child: Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _thumbnailUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CrossPlatformImage(
                      imageUrl: _thumbnailUrl!,
                      width: constraints.maxWidth,
                      height: 250,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Add Thumbnail',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
      ),
    );
  }

  // Update step image display code
  Widget _buildStepImageDisplay(String? imageUrl) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CrossPlatformImage(
                    imageUrl: imageUrl,
                    width: constraints.maxWidth,
                    height: 250,
                    fit: BoxFit.contain,
                  );
                },
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate,
                    size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No Image',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
    );
  }

  /// Updates the sections based on selected category
  void _updateSectionsForCategory(String categoryId) {
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);
    final selectedCategory = categoryService.getCategoryById(categoryId);

    if (selectedCategory == null || selectedCategory.id.isEmpty) return;

    if (kDebugMode) {
      print('Updating sections for category: ${selectedCategory.name}');
      print('Category settings: ${selectedCategory.categorySettings}');
      print('Custom sections: ${selectedCategory.customSections}');
    }

    // Update section visibility based on category settings
    setState(() {
      // Reset section visibility to defaults
      _sectionVisibility = {
        'tools': true,
        'safety': true,
        'cautions': true,
      };

      // Apply category-specific settings for standard sections
      _sectionVisibility['tools'] =
          selectedCategory.categorySettings['tools'] ?? true;
      _sectionVisibility['safety'] =
          selectedCategory.categorySettings['safety'] ?? true;
      _sectionVisibility['cautions'] =
          selectedCategory.categorySettings['cautions'] ?? true;

      if (kDebugMode) {
        print('Updated section visibility: $_sectionVisibility');
      }

      // Update custom sections
      _customSections = List.from(selectedCategory.customSections);

      // Initialize or update custom section content
      for (final section in _customSections) {
        if (!_customSectionContent.containsKey(section)) {
          _customSectionContent[section] = [];
        }
      }

      // Rebuild section titles list
      _rebuildSectionTitles();
    });
  }

  /// Rebuilds the section titles list based on visibility settings
  void _rebuildSectionTitles() {
    _sectionTitles = ['Basic Information'];

    if (_sectionVisibility['tools'] == true) {
      _sectionTitles.add('Tools');
    }

    if (_sectionVisibility['safety'] == true) {
      _sectionTitles.add('Safety Requirements');
    }

    if (_sectionVisibility['cautions'] == true) {
      _sectionTitles.add('Cautions');
    }

    // Add custom sections
    _sectionTitles.addAll(_customSections);

    // Steps is always the last section
    _sectionTitles.add('Steps');

    // Ensure current section index is valid
    if (_currentSection >= _sectionTitles.length) {
      _currentSection = 0;
    }
  }

  /// Optimizes an image by resizing and compressing it
  Future<Uint8List> _optimizeImage(XFile image,
      {bool isThumbnail = false}) async {
    try {
      final Uint8List imageBytes = await image.readAsBytes();

      // Get image dimensions
      final decodedImage = await decodeImageFromList(imageBytes);
      final int originalWidth = decodedImage.width;
      final int originalHeight = decodedImage.height;

      final int maxDimension = 1200;
      int targetWidth = originalWidth;
      int targetHeight = originalHeight;

      if (originalWidth > maxDimension || originalHeight > maxDimension) {
        if (originalWidth > originalHeight) {
          targetWidth = maxDimension;
          targetHeight =
              (originalHeight * maxDimension / originalWidth).round();
        } else {
          targetHeight = maxDimension;
          targetWidth = (originalWidth * maxDimension / originalHeight).round();
        }
      }

      if (kIsWeb) {
        final img.Image? decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          if (kDebugMode) {
            print('Failed to decode image for web optimization');
          }
          return imageBytes;
        }

        // Resize the image
        final img.Image resizedImage = img.copyResize(
          decodedImage,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );

        List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);

        final Uint8List optimizedBytes = Uint8List.fromList(compressedBytes);

        if (kDebugMode) {
          print('Web platform detected - using image package optimization');
          print('Original size: ${imageBytes.length} bytes');
          print('Optimized size: ${optimizedBytes.length} bytes');
          print('Original dimensions: ${originalWidth}x$originalHeight');
          print('Target dimensions: ${targetWidth}x$targetHeight');
          print(
              'Size reduction: ${((imageBytes.length - optimizedBytes.length) / imageBytes.length * 100).toStringAsFixed(1)}%');
        }

        return optimizedBytes.length < imageBytes.length * 0.9
            ? optimizedBytes
            : imageBytes;
      } else {
        Uint8List optimizedBytes = await FlutterImageCompress.compressWithList(
          imageBytes,
          minWidth: targetWidth,
          minHeight: targetHeight,
          quality: 85,
          format: CompressFormat.jpeg,
        );

        if (kDebugMode) {
          print('Mobile platform detected - using flutter_image_compress');
          print('Original size: ${imageBytes.length} bytes');
          print('Optimized size: ${optimizedBytes.length} bytes');
          print('Original dimensions: ${originalWidth}x$originalHeight');
          print('Target dimensions: ${targetWidth}x$targetHeight');
          print(
              'Size reduction: ${((imageBytes.length - optimizedBytes.length) / imageBytes.length * 100).toStringAsFixed(1)}%');
        }

        return optimizedBytes.length < imageBytes.length * 0.9
            ? optimizedBytes
            : imageBytes;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error optimizing image: $e');
      }
      return await image.readAsBytes();
    }
  }
}
