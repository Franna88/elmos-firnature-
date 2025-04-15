import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/sop_model.dart';

class MobileSOPViewerScreen extends StatefulWidget {
  final String sopId;

  const MobileSOPViewerScreen({super.key, required this.sopId});

  @override
  State<MobileSOPViewerScreen> createState() => _MobileSOPViewerScreenState();
}

class _MobileSOPViewerScreenState extends State<MobileSOPViewerScreen>
    with SingleTickerProviderStateMixin {
  late SOP _sop;
  bool _isLoading = true;
  int _currentStepIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  bool _isFromQRScan = false;
  bool _isAnonymousAccess = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize animation controller for QR scan effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;

      // Check if this SOP was accessed via QR code scan - safely done in didChangeDependencies
      final route = ModalRoute.of(context)?.settings.name ?? '';
      _isFromQRScan = route.contains('/sop/') && !route.contains('/editor/');

      // Check if this is anonymous access - safely done in didChangeDependencies
      final authService = Provider.of<AuthService>(context, listen: false);
      _isAnonymousAccess = !authService.isLoggedIn;

      // Load the SOP after dependencies are available
      _loadSOP();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSOP() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);

    try {
      final sop = await sopService.getSopById(widget.sopId);
      if (sop != null) {
        setState(() {
          _sop = sop;
          _isLoading = false;
        });

        // Play animation effect if this was from a QR scan
        if (_isFromQRScan) {
          _animationController.forward();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOP not found'),
              backgroundColor: Colors.red,
            ),
          );
          _navigateBack();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading SOP: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _navigateBack();
      }
    }
  }

  // Helper method to navigate back based on authentication state
  void _navigateBack() {
    if (_isAnonymousAccess) {
      // If accessed anonymously, go to login
      context.go('/login');
    } else {
      // If logged in, go to mobile SOPs list
      context.go('/mobile/sops');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading SOP details...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_sop.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        actions: [
          if (_isAnonymousAccess)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: Colors.blue,
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Public View',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          if (_isFromQRScan)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: Colors.green,
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSOPInfoDialog(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Display login banner for anonymous users
              if (_isAnonymousAccess)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'You\'re viewing this SOP in public mode. Sign in to access all features.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('LOGIN'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Progress indicator
              LinearProgressIndicator(
                value: (_currentStepIndex + 1) / _sop.steps.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary),
              ),

              // Step counter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Step ${_currentStepIndex + 1} of ${_sop.steps.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _sop.steps.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentStepIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final step = _sop.steps[index];
                    return _buildStepCard(step, index + 1);
                  },
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _currentStepIndex > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                    ),
                    _currentStepIndex == _sop.steps.length - 1
                        ? ElevatedButton.icon(
                            onPressed: () {
                              // Show completion message and return to SOPs screen or login
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('SOP completed successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _navigateBack();
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _currentStepIndex < _sop.steps.length - 1
                                ? () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[200],
                              disabledForegroundColor: Colors.grey[400],
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),

          // QR code scan animation overlay
          if (_isFromQRScan)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // Show a fading overlay when the SOP is first loaded from QR
                return _animationController.value < 1.0
                    ? Positioned.fill(
                        child: Container(
                          color: Colors.green.withOpacity(
                              0.3 * (1 - _animationController.value)),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 100 *
                                      (1 - _animationController.value * 0.8),
                                  color: Colors.white,
                                ),
                                SizedBox(
                                    height: 16 *
                                        (1 - _animationController.value * 0.5)),
                                Text(
                                  'SOP Loaded Successfully',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20 *
                                        (1 - _animationController.value * 0.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStepCard(SOPStep step, int stepNumber) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$stepNumber",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Step image
          if (step.imageUrl != null && step.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              margin: const EdgeInsets.only(bottom: 16),
              child: _buildImage(step.imageUrl!),
            ),

          // Instructions
          const Text(
            'Instructions:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.instruction,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),

          // Help Note (if available)
          if (step.helpNote != null && step.helpNote!.isNotEmpty) ...[
            const Text(
              'Help Note:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[700]!),
              ),
              child: Text(
                step.helpNote!,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final data = imageUrl.split(',')[1];
        final bytes = base64Decode(data);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildImageError(),
          ),
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        ),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        ),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Image could not be loaded',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SOP Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Title', _sop.title),
              _buildInfoRow('Description', _sop.description),
              _buildInfoRow('Category', _sop.categoryName ?? 'Uncategorized'),
              _buildInfoRow('Revision', _sop.revisionNumber.toString()),
              _buildInfoRow('Created By', _sop.createdBy),
              _buildInfoRow('Created', _formatDate(_sop.createdAt)),
              _buildInfoRow('Last Updated', _formatDate(_sop.updatedAt)),
              const Divider(),
              const Text(
                'Required Tools:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.tools.map((tool) {
                  return Chip(
                    label: Text(tool),
                    backgroundColor: Colors.blue[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.blue[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Safety Requirements:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.safetyRequirements.map((safety) {
                  return Chip(
                    label: Text(safety),
                    backgroundColor: Colors.red[50],
                    labelStyle: TextStyle(fontSize: 12, color: Colors.red[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cautions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _sop.cautions.map((caution) {
                  return Chip(
                    label: Text(caution),
                    backgroundColor: Colors.amber[50],
                    labelStyle:
                        TextStyle(fontSize: 12, color: Colors.amber[800]),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
