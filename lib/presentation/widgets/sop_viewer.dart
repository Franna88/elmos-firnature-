import 'package:flutter/material.dart';
import '../../data/models/sop_model.dart';
import 'dart:convert';
import '../../data/services/qr_code_service.dart';
import 'package:provider/provider.dart';
import '../../data/services/sop_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/cross_platform_image.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:image_network/image_network.dart';
import 'package:flutter/rendering.dart';

class SOPViewer extends StatefulWidget {
  final SOP sop;
  final bool showFullDetails;
  final VoidCallback? onPrint;
  final VoidCallback? onDownloadQRCode;
  final Function(int)? onEditStep;

  const SOPViewer({
    super.key,
    required this.sop,
    this.showFullDetails = true,
    this.onPrint,
    this.onDownloadQRCode,
    this.onEditStep,
  });

  @override
  State<SOPViewer> createState() => _SOPViewerState();
}

class _SOPViewerState extends State<SOPViewer> {
  int _selectedStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _validateSelectedStepIndex();

    // Preload all images for this SOP to improve viewing experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sopService = Provider.of<SOPService>(context, listen: false);
      sopService.preloadSOPImages(widget.sop.id).then((_) {
        if (kDebugMode) {
          print('All SOP images preloaded successfully in SOPViewer');
        }
      });
    });
  }

  @override
  void didUpdateWidget(SOPViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sop.id != widget.sop.id ||
        oldWidget.sop.steps.length != widget.sop.steps.length) {
      _validateSelectedStepIndex();
    }
  }

  void _validateSelectedStepIndex() {
    // Reset to first step if current index is invalid
    if (widget.sop.steps.isEmpty) {
      _selectedStepIndex = 0;
    } else if (_selectedStepIndex >= widget.sop.steps.length) {
      _selectedStepIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // SOP Header
        //_buildHeader(context),

        // Main content with side navigation
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left navigation bar for steps
              _buildStepNavigation(context),

              // Main content area
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey('step-content-${_selectedStepIndex}'),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current step details
                      if (widget.sop.steps.isNotEmpty)
                        _buildCurrentStepCard(
                            context,
                            widget.sop.steps[_selectedStepIndex],
                            _selectedStepIndex)
                      else
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No steps have been added to this SOP.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),

                      // Only show these sections if full details are requested
                      if (widget.showFullDetails) ...[
                        const SizedBox(height: 24),

                        // Tools section
                        if (widget.sop.tools.isNotEmpty)
                          _buildToolsSection(context),

                        const SizedBox(height: 24),

                        // Safety requirements section
                        if (widget.sop.safetyRequirements.isNotEmpty)
                          _buildSafetyRequirementsSection(context),

                        const SizedBox(height: 24),

                        // Cautions section
                        if (widget.sop.cautions.isNotEmpty)
                          _buildCautionsSection(context),

                        // Custom sections
                        if (widget.sop.customSectionContent.isNotEmpty) ...[
                          for (final entry
                              in widget.sop.customSectionContent.entries)
                            if (entry.value.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _buildCustomSection(
                                  context, entry.key, entry.value),
                            ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar with title and actions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // SOP icon and title
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sop.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.sop.categoryName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.sop.categoryName!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // SOP actions
                Row(
                  children: [
                    // YouTube video button
                    if (widget.sop.youtubeUrl != null &&
                        widget.sop.youtubeUrl!.isNotEmpty)
                      Tooltip(
                        message: 'Watch video tutorial',
                        child: ElevatedButton.icon(
                          onPressed: _launchYoutubeVideo,
                          icon: const Icon(Icons.play_circle_fill,
                              color: Colors.red),
                          label: const Text(
                            'Video Tutorial',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),

                    // Info button
                    Tooltip(
                      message: 'View SOP information',
                      child: IconButton(
                        onPressed: () => _showSOPInfoDialog(context),
                        icon:
                            const Icon(Icons.info_outline, color: Colors.white),
                      ),
                    ),

                    // Print button
                    if (widget.onPrint != null)
                      Tooltip(
                        message: 'Print SOP',
                        child: IconButton(
                          onPressed: widget.onPrint,
                          icon: const Icon(Icons.print_outlined,
                              color: Colors.white),
                        ),
                      ),

                    // QR Code button
                    if (widget.onDownloadQRCode != null)
                      Tooltip(
                        message: 'Download QR Code',
                        child: IconButton(
                          onPressed: widget.onDownloadQRCode,
                          icon: const Icon(Icons.qr_code_2_outlined,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Method to launch YouTube video URL
  Future<void> _launchYoutubeVideo() async {
    if (widget.sop.youtubeUrl != null && widget.sop.youtubeUrl!.isNotEmpty) {
      final Uri url = Uri.parse(widget.sop.youtubeUrl!);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Handle error
      }
    }
  }

  // New method to show SOP info in a dialog
  void _showSOPInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.sop.title} - Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Category', widget.sop.categoryName ?? 'Unknown',
                  Icons.business),
              const SizedBox(height: 12),
              _buildInfoRow('Revision', widget.sop.revisionNumber.toString(),
                  Icons.history),
              const SizedBox(height: 12),
              _buildInfoRow('Created', _formatDate(widget.sop.createdAt),
                  Icons.calendar_today),
              const SizedBox(height: 12),
              _buildInfoRow('Last Updated', _formatDate(widget.sop.updatedAt),
                  Icons.update),

              // Display YouTube video information if available
              if (widget.sop.youtubeUrl != null &&
                  widget.sop.youtubeUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Video Tutorial Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (widget.sop.youtubeUrl != null &&
              widget.sop.youtubeUrl!.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchYoutubeVideo();
              },
              icon: const Icon(Icons.play_circle_outline, color: Colors.red),
              label: const Text(
                'Watch Video',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blueGrey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepNavigation(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Procedure Steps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.sop.steps.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Steps list
          Expanded(
            child: widget.sop.steps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add_check_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No steps available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('step-list-${widget.sop.id}'),
                    itemCount: widget.sop.steps.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final step = widget.sop.steps[index];
                      final isSelected = index == _selectedStepIndex;
                      final isCompleted = index < _selectedStepIndex;

                      return Padding(
                        key: ValueKey('step-item-${step.id}-$index'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Material(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isCompleted
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.08)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedStepIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Step number or checkmark
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : (isCompleted
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey.shade200),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: isCompleted
                                          ? Icon(
                                              Icons.check,
                                              size: 16,
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Colors.white,
                                            )
                                          : Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Step title
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.grey.shade800,
                                          ),
                                        ),

                                        // Show step indicators (image, help note, etc.)
                                        if (step.imageUrl != null ||
                                            step.helpNote != null ||
                                            step.estimatedTime != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Row(
                                              children: [
                                                if (step.imageUrl != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 14,
                                                      color: isSelected
                                                          ? Colors.white
                                                              .withOpacity(0.7)
                                                          : Colors
                                                              .grey.shade500,
                                                    ),
                                                  ),
                                                if (step.helpNote != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: Icon(
                                                      Icons.tips_and_updates,
                                                      size: 14,
                                                      color: isSelected
                                                          ? Colors.white
                                                              .withOpacity(0.7)
                                                          : Colors
                                                              .grey.shade500,
                                                    ),
                                                  ),
                                                if (step.estimatedTime != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: Icon(
                                                      Icons.timer_outlined,
                                                      size: 14,
                                                      color: isSelected
                                                          ? Colors.white
                                                              .withOpacity(0.7)
                                                          : Colors
                                                              .grey.shade500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '${_selectedStepIndex + 1}/${widget.sop.steps.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: widget.sop.steps.isEmpty
                        ? 0
                        : (_selectedStepIndex + 1) / widget.sop.steps.length,
                    backgroundColor: Colors.grey.shade200,
                    minHeight: 8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard(BuildContext context, SOPStep step, int index) {
    return Card(
      key: ValueKey('step-card-$index'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step header with number and title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Step number circle
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onEditStep != null)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: 'Edit this step',
                    onPressed: () => widget.onEditStep!(index),
                  ),
                if (step.estimatedTime != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatTimeInMinutes(step.estimatedTime!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Image as the main focus (if available)
          if (step.imageUrl != null)
            Stack(
              key: ValueKey('step-image-stack-$index'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.8, // 80% of the card's width
                      child: Container(
                        height: 450, // Fixed height for the image area
                        width: double.infinity, // Take all available width
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: CrossPlatformImage(
                          key: ValueKey('step-image-${step.imageUrl}'),
                          imageUrl: step.imageUrl!,
                          width: 550, // Fill parent width
                          height: 450, // Match container height
                          fit: BoxFit
                              .cover, // Fill the container, cropping if needed
                          errorWidget: _buildImageError(),
                        ),
                      ),
                    ),
                  ),
                ),
                // Fullscreen button overlay
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      icon: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 28),
                      label: const Text(
                        'FULLSCREEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        // Show full-size image dialog
                        showDialog(
                          context: context,
                          barrierColor: Colors.black87,
                          builder: (context) => Dialog.fullscreen(
                            backgroundColor: Colors.black,
                            child: Stack(
                              children: [
                                // Full screen image
                                Center(
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.5,
                                    maxScale: 3.0,
                                    child: ImageNetwork(
                                      image: step.imageUrl!,
                                      height:
                                          MediaQuery.of(context).size.height,
                                      width: MediaQuery.of(context).size.width,
                                      duration: 500,
                                      curve: Curves.easeIn,
                                      onPointer: true,
                                      debugPrint: false,
                                      borderRadius: BorderRadius.circular(0),
                                      onLoading: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onError: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                              size: 64,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Failed to load image',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Close button
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

          // Step details section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruction
                Text(
                  step.instruction,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),

                // Help note (if available)
                if (step.helpNote != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates,
                            color: Colors.blue.shade700, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Helpful Tip',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                step.helpNote!,
                                style: TextStyle(
                                  height: 1.5,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Step-specific details (if available)
                if (step.assignedTo != null ||
                    step.stepTools.isNotEmpty ||
                    step.stepHazards.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Assigned to
                  if (step.assignedTo != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person,
                              size: 16, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assigned to',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              step.assignedTo!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step Tools
                  if (step.stepTools.isNotEmpty) ...[
                    const Text(
                      'Required Tools',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: step.stepTools
                          .map((tool) => Chip(
                                avatar: const Icon(Icons.build, size: 16),
                                label: Text(tool),
                                backgroundColor: Colors.grey.shade100,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step Hazards
                  if (step.stepHazards.isNotEmpty) ...[
                    const Text(
                      'Hazards & Warnings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...step.stepHazards
                        .map((hazard) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber,
                                      color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(hazard),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ],
              ],
            ),
          ),

          // Step navigation footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_selectedStepIndex > 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous Step'),
                    onPressed: () {
                      setState(() {
                        _selectedStepIndex--;
                      });
                    },
                  )
                else
                  const SizedBox(),
                if (_selectedStepIndex < widget.sop.steps.length - 1)
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next Step'),
                    onPressed: () {
                      setState(() {
                        _selectedStepIndex++;
                      });
                    },
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                    onPressed: () {
                      // Show completion dialog or action
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('SOP completed successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools and Equipment',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.tools.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.build, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.tools[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyRequirementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Requirements',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.safetyRequirements.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.security, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.safetyRequirements[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCautionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cautions and Limitations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.sop.cautions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(widget.sop.cautions[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(value),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTimeInMinutes(int seconds) {
    int minutes = (seconds / 60).ceil();
    return minutes == 1 ? "$minutes min" : "$minutes mins";
  }

  Widget _buildStepImage(String imageUrl, BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.8, // 80% of the available width
        child: Container(
          // Optionally set a max height if you want to limit vertical size
          constraints: BoxConstraints(
            maxHeight: 350, // or any value you prefer
          ),
          child: CrossPlatformImage(
            key: ValueKey('step-image-$imageUrl'),
            imageUrl: imageUrl,
            fit: BoxFit.contain, // or BoxFit.cover if you want to crop
            errorWidget: _buildImageError(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenImage(String imageUrl, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.9,
      color: Colors.black,
      clipBehavior: Clip.antiAlias,
      child: CrossPlatformImage(
        key: ValueKey('fullscreen-image-$imageUrl'),
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        errorWidget: _buildImageError(),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 300,
      color: Colors.grey.shade100,
      clipBehavior: Clip.none,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Colors.grey.shade400,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Image could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Build QR code section
  Widget _buildQRCodeSection(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code, color: Color(0xFFBB2222)),
                    const SizedBox(width: 8),
                    Text('SOP QR Code',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: 'Learn how to use this QR code',
                  onPressed: () {
                    // Show help information
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFBB2222)),
                            SizedBox(width: 8),
                            Text('Using SOP QR Codes'),
                          ],
                        ),
                        content: const SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QR codes enable quick access to SOPs on mobile devices:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('1.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Print this QR code and attach it to relevant equipment, workstations, or materials.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('2.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Team members can scan it with the Elmo\'s Furniture mobile app.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('3.'),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'The app immediately opens this specific SOP, showing all steps and details.',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Benefits:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Instant access to procedures without searching'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Ensures team members follow correct procedures'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.update, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Always shows the latest version of the SOP'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan this QR code with the Elmo\'s Furniture mobile app to instantly access this SOP on a mobile device.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  // Display QR code
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: sopService.qrCodeService
                        .generateQRWidget(widget.sop.id, size: 200),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SOP ID: ${widget.sop.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a new method to build custom sections
  Widget _buildCustomSection(
      BuildContext context, String sectionName, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.article,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(items[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
