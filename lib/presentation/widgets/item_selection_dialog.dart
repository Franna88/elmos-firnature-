import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/production_item_model.dart';
import '../../core/theme/app_theme.dart';
import 'cross_platform_image.dart';

/// Dialog for selecting production items with quantity configuration
class ItemSelectionDialog extends StatefulWidget {
  final List<ProductionItem> availableItems;
  final ProductionItem? selectedItem;
  final Function(
          ProductionItem item, int qtyPerCycle, int finishedQty, int? targetQty)
      onItemSelected;
  final VoidCallback? onCancel;
  final bool
      isFromJobComplete; // Whether this dialog is opened from Job Complete action

  const ItemSelectionDialog({
    super.key,
    required this.availableItems,
    this.selectedItem,
    required this.onItemSelected,
    this.onCancel,
    this.isFromJobComplete = false,
  });

  @override
  State<ItemSelectionDialog> createState() => _ItemSelectionDialogState();
}

class _ItemSelectionDialogState extends State<ItemSelectionDialog> {
  ProductionItem? _selectedItem;
  final _qtyPerCycleController = TextEditingController();
  final _finishedQtyController = TextEditingController();
  final _targetQtyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.selectedItem;

    // Pre-populate fields if an item is already selected
    if (_selectedItem != null) {
      _qtyPerCycleController.text = _selectedItem!.qtyPerCycle.toString();
      _finishedQtyController.text = _selectedItem!.finishedQty.toString();
      if (_selectedItem!.targetQty > 0) {
        _targetQtyController.text = _selectedItem!.targetQty.toString();
      }
    } else {
      // Default values for new selection
      _qtyPerCycleController.text = '1';
      _finishedQtyController.text = '0';
    }
  }

  @override
  void dispose() {
    _qtyPerCycleController.dispose();
    _finishedQtyController.dispose();
    _targetQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: isTablet ? 700 : size.width * 0.9,
        height: isTablet ? 600 : size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isFromJobComplete
                        ? Icons.inventory
                        : Icons.add_business,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isFromJobComplete
                          ? 'Count Items & Select Next'
                          : 'Select Production Item',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed:
                        widget.onCancel ?? () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item selection
                      Text(
                        'Select Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        flex: 3,
                        child: _buildItemGrid(isTablet),
                      ),

                      const SizedBox(height: 20),

                      // Quantity configuration
                      if (_selectedItem != null) ...[
                        Text(
                          'Production Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 2,
                          child: _buildQuantityForm(isTablet),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        widget.onCancel ?? () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _selectedItem != null && !_isLoading
                        ? _handleConfirm
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Confirm Selection'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemGrid(bool isTablet) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.availableItems.length,
      itemBuilder: (context, index) {
        final item = widget.availableItems[index];
        final isSelected = _selectedItem?.id == item.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedItem = item;
              // Update form fields with item data
              _qtyPerCycleController.text = item.qtyPerCycle.toString();
              _finishedQtyController.text = item.finishedQty.toString();
              if (item.targetQty > 0) {
                _targetQtyController.text = item.targetQty.toString();
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                    ),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? CrossPlatformImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                ),

                // Item details
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.primaryBlue
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Est: ${item.estimatedTimeInMinutes} min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildQuantityForm(bool isTablet) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _qtyPerCycleController,
                  label: 'QTY per Cycle',
                  hint: '1',
                  isRequired: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    final qty = int.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'Must be > 0';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _finishedQtyController,
                  label: 'Finished QTY',
                  hint: '0',
                  isRequired:
                      widget.isFromJobComplete, // Required when counting
                  validator: (value) {
                    if (widget.isFromJobComplete &&
                        (value == null || value.isEmpty)) {
                      return 'Required for counting';
                    }
                    if (value != null && value.isNotEmpty) {
                      final qty = int.tryParse(value);
                      if (qty == null || qty < 0) {
                        return 'Must be ≥ 0';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNumberField(
            controller: _targetQtyController,
            label: 'Target QTY (Optional)',
            hint: 'Enter target quantity',
            isRequired: false,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final qty = int.tryParse(value);
                if (qty == null || qty <= 0) {
                  return 'Must be > 0';
                }
              }
              return null;
            },
          ),
          if (widget.isFromJobComplete) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Count your finished items and enter the quantity above. You cannot proceed without entering the finished quantity.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRequired,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: validator,
    );
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final qtyPerCycle = int.parse(_qtyPerCycleController.text);
      final finishedQty = int.tryParse(_finishedQtyController.text) ?? 0;
      final targetQty = _targetQtyController.text.isNotEmpty
          ? int.tryParse(_targetQtyController.text)
          : null;

      // Validation for Job Complete scenario
      if (widget.isFromJobComplete && finishedQty == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the finished quantity for counting'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      widget.onItemSelected(
          _selectedItem!, qtyPerCycle, finishedQty, targetQty);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
