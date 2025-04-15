import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../data/services/sop_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';

class MobileSOPEditorScreen extends StatefulWidget {
  final String sopId;

  const MobileSOPEditorScreen({super.key, required this.sopId});

  @override
  State<MobileSOPEditorScreen> createState() => _MobileSOPEditorScreenState();
}

class _MobileSOPEditorScreenState extends State<MobileSOPEditorScreen> {
  late SOP _sop;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  int _currentStepIndex = -1; // -1 means editing SOP details, not steps
  int _selectedStepTab = 0; // Track selected step tab

  // Focus nodes
  final FocusNode _stepToolFocusNode = FocusNode();
  final FocusNode _stepHazardFocusNode = FocusNode();
  final FocusNode _sopToolFocusNode = FocusNode();
  final FocusNode _sopSafetyFocusNode = FocusNode();
  final FocusNode _sopCautionFocusNode = FocusNode();

  // Current section of the SOP being edited
  int _currentSection = 0;
  // Section titles
  final List<String> _sectionTitles = [
    'Basic Information',
    'Tools',
    'Safety Requirements',
    'Cautions',
    'Steps'
  ];

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _stepTitleController;
  late TextEditingController _stepInstructionController;
  late TextEditingController _stepHelpNoteController;
  late TextEditingController _stepEstimatedHoursController;
  late TextEditingController _stepEstimatedMinutesController;
  late TextEditingController _stepEstimatedSecondsController;
  // Tools and hazards for the current step being edited
  List<String> _currentStepTools = [];
  List<String> _currentStepHazards = [];
  // SOP-level tools, safety requirements, and cautions
  List<String> _sopTools = [];
  List<String> _sopSafetyRequirements = [];
  List<String> _sopCautions = [];

  @override
  void initState() {
    super.initState();
    _loadSOP();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepTitleController.dispose();
    _stepInstructionController.dispose();
    _stepHelpNoteController.dispose();
    _stepEstimatedHoursController.dispose();
    _stepEstimatedMinutesController.dispose();
    _stepEstimatedSecondsController.dispose();

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
                _stepTitleController = TextEditingController();
                _stepInstructionController = TextEditingController();
                _stepHelpNoteController = TextEditingController();
                _stepEstimatedHoursController =
                    TextEditingController(text: '0');
                _stepEstimatedMinutesController =
                    TextEditingController(text: '0');
                _stepEstimatedSecondsController =
                    TextEditingController(text: '0');
                _currentStepTools = [];
                _currentStepHazards = [];
                _sopTools = [];
                _sopSafetyRequirements = [];
                _sopCautions = [];
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
      }

      // Initialize controllers
      _titleController = TextEditingController(text: _sop.title);
      _descriptionController = TextEditingController(text: _sop.description);
      _stepTitleController = TextEditingController();
      _stepInstructionController = TextEditingController();
      _stepHelpNoteController = TextEditingController();
      _stepEstimatedHoursController = TextEditingController(text: '0');
      _stepEstimatedMinutesController = TextEditingController(text: '0');
      _stepEstimatedSecondsController = TextEditingController(text: '0');

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
    switch (_currentSection) {
      case 0: // General Info
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
        break;
      case 1: // Tools
        // Tools are optional, no validation required
        break;
      case 2: // Safety Requirements
        // Safety requirements are optional, no validation required
        break;
      case 3: // Cautions
        // Cautions are optional, no validation required
        break;
      case 4: // Steps
        if (_sop.steps.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add at least one step'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
        break;
    }
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
      );
    });
    // Return a completed future to allow chaining
    return Future.value();
  }

  /// Saves the SOP to Firebase
  Future<void> _saveSOP() async {
    // First update locally to ensure we have the latest data
    await _updateSOPLocally();

    try {
      // Get the SOP service from provider
      final sopService = Provider.of<SOPService>(context, listen: false);

      // For new SOPs, use saveLocalSopToFirebase to save it to Firebase
      // For existing SOPs, use updateSop to update it in Firebase
      if (widget.sopId == 'new') {
        await sopService.saveLocalSopToFirebase(_sop);
      } else {
        await sopService.updateSop(_sop);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOP saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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

      // Parse and set time controllers
      if (step.estimatedTime != null) {
        int totalSeconds = step.estimatedTime!;
        int hours = totalSeconds ~/ 3600;
        int minutes = (totalSeconds % 3600) ~/ 60;
        int seconds = totalSeconds % 60;

        _stepEstimatedHoursController.text = hours.toString();
        _stepEstimatedMinutesController.text = minutes.toString();
        _stepEstimatedSecondsController.text = seconds.toString();
      } else {
        _stepEstimatedHoursController.text = '0';
        _stepEstimatedMinutesController.text = '0';
        _stepEstimatedSecondsController.text = '0';
      }

      _currentStepTools = List.from(step.stepTools);
      _currentStepHazards = List.from(step.stepHazards);
    } else {
      _stepTitleController.text = '';
      _stepInstructionController.text = '';
      _stepHelpNoteController.text = '';
      _stepEstimatedHoursController.text = '0';
      _stepEstimatedMinutesController.text = '0';
      _stepEstimatedSecondsController.text = '0';
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

    final sopService = Provider.of<SOPService>(context, listen: false);
    List<SOPStep> updatedSteps = List.from(_sop.steps);

    // Generate a step ID
    final String stepId = _currentStepIndex < _sop.steps.length
        ? _sop.steps[_currentStepIndex].id
        : '${_sop.id}_step_${DateTime.now().millisecondsSinceEpoch}';

    // Calculate total time in seconds
    int? estimatedTime;
    try {
      int hours = int.tryParse(_stepEstimatedHoursController.text) ?? 0;
      int minutes = int.tryParse(_stepEstimatedMinutesController.text) ?? 0;
      int seconds = int.tryParse(_stepEstimatedSecondsController.text) ?? 0;

      // Convert to total seconds
      estimatedTime = (hours * 3600) + (minutes * 60) + seconds;

      // If all values are 0, set to null
      if (estimatedTime == 0) {
        estimatedTime = null;
      }
    } catch (e) {
      estimatedTime = null;
    }

    final newStep = SOPStep(
      id: stepId,
      title: _stepTitleController.text,
      instruction: _stepInstructionController.text,
      imageUrl: _currentStepIndex < _sop.steps.length
          ? _sop.steps[_currentStepIndex].imageUrl
          : null,
      helpNote: _stepHelpNoteController.text.isEmpty
          ? null
          : _stepHelpNoteController.text,
      estimatedTime: estimatedTime,
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

    final updatedSop = _sop.copyWith(steps: updatedSteps);

    try {
      await sopService.updateSopLocally(updatedSop);
      setState(() {
        _sop = updatedSop;
        _currentStepIndex = -1; // Return to main form
      });
    } catch (e) {
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

  // Add a new tool to the current step
  void _addStepTool(String tool) {
    if (tool.isNotEmpty && !_currentStepTools.contains(tool)) {
      setState(() {
        _currentStepTools.add(tool);
      });
    }
  }

  // Remove a tool from the current step
  void _removeStepTool(String tool) {
    setState(() {
      _currentStepTools.remove(tool);
    });
  }

  // Add a new hazard to the current step
  void _addStepHazard(String hazard) {
    if (hazard.isNotEmpty && !_currentStepHazards.contains(hazard)) {
      setState(() {
        _currentStepHazards.add(hazard);
      });
    }
  }

  // Remove a hazard from the current step
  void _removeStepHazard(String hazard) {
    setState(() {
      _currentStepHazards.remove(hazard);
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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final sopService = Provider.of<SOPService>(context, listen: false);
        final imageBytes = await image.readAsBytes();

        // If editing an existing step
        if (_currentStepIndex < _sop.steps.length) {
          List<SOPStep> updatedSteps = List.from(_sop.steps);
          final currentStep = updatedSteps[_currentStepIndex];

          // Simulate uploading the image and getting a URL
          // In a real app, this would actually upload the image to Firebase Storage
          final String imageUrl =
              'data:image/jpeg;base64,${base64Encode(imageBytes)}';

          // Update the step with the new image URL
          updatedSteps[_currentStepIndex] =
              currentStep.copyWith(imageUrl: imageUrl);
          final updatedSop = _sop.copyWith(steps: updatedSteps);

          await sopService.updateSopLocally(updatedSop);
          setState(() {
            _sop = updatedSop;
            _isLoading = false;
          });
        } else {
          // We're creating a new step, so we'll save the step first
          // and then update the image in a separate operation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Save the step first before adding an image')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  // Method to build the content for the current section
  Widget _buildCurrentSectionContent() {
    switch (_currentSection) {
      case 0:
        return _buildBasicInfoSection();
      case 1:
        return _buildToolsSection();
      case 2:
        return _buildSafetyRequirementsSection();
      case 3:
        return _buildCautionsSection();
      case 4:
        return _buildStepsSection();
      default:
        return const Center(child: Text('Unknown section'));
    }
  }

  // Section 1: Basic Information
  Widget _buildBasicInfoSection() {
    final categoryService = Provider.of<CategoryService>(context);
    final categories = categoryService.categories;

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
                  setState(() {
                    _sop = _sop.copyWith(categoryId: value);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Section 2: Tools
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

  // Section 3: Safety Requirements
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

  // Section 4: Cautions
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

  // Section 5: Steps with Tabbed View
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
              ElevatedButton.icon(
                onPressed: () {
                  _editStep(_sop.steps.length); // Create new step
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
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
                          'Tap the "Add Step" button to add your first step.',
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
                                      ? Colors.red[700]
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
                                            : Colors.red[700],
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
                        child: _sop.steps.isNotEmpty
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
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editStep(index),
                      tooltip: 'Edit Step',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _showDeleteConfirmation(index),
                      tooltip: 'Delete Step',
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
                        height: 150,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            step.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          ),
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

                    // Tools
                    if (step.stepTools.isNotEmpty) ...[
                      const Text(
                        'Tools Required:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: step.stepTools
                            .map((tool) => Chip(
                                  label: Text(tool),
                                  backgroundColor: Colors.blue[50],
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Hazards
                    if (step.stepHazards.isNotEmpty) ...[
                      const Text(
                        'Hazards:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: step.stepHazards
                            .map((hazard) => Chip(
                                  label: Text(hazard),
                                  backgroundColor: Colors.red[50],
                                ))
                            .toList(),
                      ),
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
    if (_isLoading) {
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
            onPressed: () {
              setState(() {
                _currentStepIndex = -1;
              });
            },
          ),
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
            if (_currentSection > 0) {
              // Navigate to previous section
              setState(() {
                _currentSection--;
              });
            } else {
              // Exit to SOPs screen
              context.go('/mobile/sops');
            }
          },
        ),
        actions: [
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
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentSection + 1) / _sectionTitles.length,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
          ),

          // Section title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Section ${_currentSection + 1}/${_sectionTitles.length}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  _sectionTitles[_currentSection],
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

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
                if (_currentSection > 0)
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
                    : ElevatedButton.icon(
                        onPressed: () {
                          // Validate current section before saving
                          if (_validateCurrentSection()) {
                            // Save to Firebase only on the final submission
                            _saveSOP().then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SOP saved successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              context.go('/mobile/sops');
                            });
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save SOP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
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
    final String imageUrl = !isNewStep && _currentStepIndex < _sop.steps.length
        ? _sop.steps[_currentStepIndex].imageUrl ?? ''
        : '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Step basic info
          TextFormField(
            controller: _stepTitleController,
            decoration: const InputDecoration(
              labelText: 'Step Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stepInstructionController,
            decoration: const InputDecoration(
              labelText: 'Step Instructions',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stepHelpNoteController,
            decoration: const InputDecoration(
              labelText: 'Help Note (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          // Estimated time fields (hours, minutes, seconds)
          const SizedBox(height: 16),
          const Text(
            'Estimated Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Hours
              Expanded(
                child: TextFormField(
                  controller: _stepEstimatedHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              // Minutes
              Expanded(
                child: TextFormField(
                  controller: _stepEstimatedMinutesController,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              // Seconds
              Expanded(
                child: TextFormField(
                  controller: _stepEstimatedSecondsController,
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          // Step image
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
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 48),
                ),
              ),
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
                    Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No image added'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadStepImage,
            icon: const Icon(Icons.image),
            label: Text(imageUrl.isNotEmpty ? 'Change Image' : 'Add Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),

          // Step Tools
          const SizedBox(height: 24),
          const Text(
            'Tools Required for this Step',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildStepToolsSection(),

          // Step Hazards
          const SizedBox(height: 24),
          const Text(
            'Hazards for this Step',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildStepHazardsSection(),

          // Action buttons
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentStepIndex = -1; // Go back to main form
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                  ),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('SAVE STEP'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build the tools list for the step being edited
  Widget _buildStepToolsSection() {
    final TextEditingController toolController = TextEditingController();

    // Request focus when this section is visible
    Future.microtask(() => _stepToolFocusNode.requestFocus());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: toolController,
                focusNode: _stepToolFocusNode,
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
                  _addStepTool(toolController.text);
                  toolController.clear();
                  // Maintain focus on text field
                  _stepToolFocusNode.requestFocus();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_currentStepTools.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No tools added for this step',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _currentStepTools.map((tool) {
              return _buildItemChip(
                tool,
                onDelete: () => _removeStepTool(tool),
                color: Colors.blue,
              );
            }).toList(),
          ),
      ],
    );
  }

  // Build the hazards list for the step being edited
  Widget _buildStepHazardsSection() {
    final TextEditingController hazardController = TextEditingController();

    // Request focus when this section is visible
    Future.microtask(() => _stepHazardFocusNode.requestFocus());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: hazardController,
                focusNode: _stepHazardFocusNode,
                decoration: const InputDecoration(
                    labelText: 'Hazard description',
                    border: OutlineInputBorder(),
                    hintText: 'E.g., Sharp edges, Hot surfaces'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle),
              color: Theme.of(context).primaryColor,
              onPressed: () {
                if (hazardController.text.isNotEmpty) {
                  _addStepHazard(hazardController.text);
                  hazardController.clear();
                  // Maintain focus on text field
                  _stepHazardFocusNode.requestFocus();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_currentStepHazards.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No hazards added for this step',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _currentStepHazards.map((hazard) {
              return _buildItemChip(
                hazard,
                onDelete: () => _removeStepHazard(hazard),
                color: Colors.red,
              );
            }).toList(),
          ),
      ],
    );
  }
}
