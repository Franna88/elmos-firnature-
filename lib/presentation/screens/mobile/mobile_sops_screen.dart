import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:alphabet_scroll_view/alphabet_scroll_view.dart';
import '../../../data/services/sop_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/models/sop_model.dart';
import '../../../core/theme/app_theme.dart';

class MobileSOPsScreen extends StatefulWidget {
  const MobileSOPsScreen({super.key});

  @override
  State<MobileSOPsScreen> createState() => _MobileSOPsScreenState();
}

class _MobileSOPsScreenState extends State<MobileSOPsScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _selectedLetter;
  final ScrollController _scrollController = ScrollController();

  // Define a custom alphabet list
  final List<String> _alphabet = const [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final sopService = Provider.of<SOPService>(context, listen: false);
    final categoryService =
        Provider.of<CategoryService>(context, listen: false);

    await Future.wait([
      sopService.refreshSOPs(),
      categoryService.refreshCategories(),
    ]);

    // Check if widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToLetter(String letter, List<SOP> sops) {
    final int sopIndex =
        sops.indexWhere((sop) => sop.title.toUpperCase().startsWith(letter));

    if (sopIndex >= 0) {
      setState(() {
        _selectedLetter = letter;
      });

      // Calculate the approximate scroll position (height of card * index)
      final double scrollPosition = sopIndex * 180.0;

      _scrollController.animateTo(scrollPosition,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);

      // Show a visual indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scrolled to $letter'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sopService = Provider.of<SOPService>(context);
    final categoryService = Provider.of<CategoryService>(context);
    final authService = Provider.of<AuthService>(context);

    // Filter SOPs based on search query and category
    List<SOP> filteredSOPs = sopService.searchSOPs(_searchQuery);
    if (_selectedCategory != 'All') {
      filteredSOPs = filteredSOPs
          .where((sop) => sop.categoryName == _selectedCategory)
          .toList();
    }

    // Sort SOPs alphabetically by title for the alphabet index
    filteredSOPs.sort((a, b) => a.title.compareTo(b.title));

    // Get unique categories for filter dropdown
    final categories = [
      'All',
      ...categoryService.categories.map((cat) => cat.name).toSet().toList()
    ];

    // Create AlphaModel list from SOPs for the alphabet scroller
    final List<AlphaModel> alphabetList =
        filteredSOPs.map((sop) => AlphaModel(sop.title)).toList();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("SOPs", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Elmo's Furniture",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome, ${authService.userName ?? 'User'}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authService.userEmail ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.article),
              title: const Text('SOPs'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                context.go('/mobile/categories');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search SOPs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                value: _selectedCategory,
                items: categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ),
          ),

          // SOPs list with alphabet scroll
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSOPs.isEmpty
                    ? const Center(child: Text('No SOPs found'))
                    : Row(
                        children: [
                          // Main SOP list
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16.0),
                              itemCount: filteredSOPs.length,
                              itemBuilder: (context, index) {
                                final sop = filteredSOPs[index];
                                return _buildSOPCard(context, sop);
                              },
                            ),
                          ),

                          // Alphabet sidebar
                          Container(
                            width: 30,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                bottomLeft: Radius.circular(15),
                              ),
                            ),
                            child: ListView.builder(
                              itemCount: _alphabet.length,
                              itemBuilder: (context, index) {
                                final letter = _alphabet[index];
                                final bool isSelected =
                                    letter == _selectedLetter;

                                return GestureDetector(
                                  onTap: () =>
                                      _scrollToLetter(letter, filteredSOPs),
                                  child: Container(
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOPCard(BuildContext context, SOP sop) {
    // Get primary image for the card if available
    final String? imageUrl =
        sop.steps.isNotEmpty && sop.steps.first.imageUrl != null
            ? sop.steps.first.imageUrl
            : null;

    // Get category color
    final Color categoryColor =
        _getCategoryColor(sop.categoryName ?? 'Unknown');

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0), // Reduced margin
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: InkWell(
        onTap: () {
          context.go('/mobile/sop/${sop.id}');
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and category badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12.0),
                    topRight: Radius.circular(12.0),
                  ),
                  child: imageUrl != null
                      ? _buildImageFromUrl(imageUrl)
                      : Container(
                          width: double.infinity,
                          height: 100, // Reduced height
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      sop.categoryName ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(8.0), // Reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sop.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0, // Smaller font
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'Rev ${sop.revisionNumber}',
                          style: TextStyle(
                            fontSize: 10.0, // Smaller font
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0), // Reduced spacing
                  Text(
                    sop.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.0, // Smaller font
                    ),
                    maxLines: 1, // Reduced to one line
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0), // Reduced spacing
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 14.0, // Smaller icon
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        '${sop.steps.length} steps',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10.0, // Smaller font
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14.0, // Smaller icon
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _formatDate(sop.updatedAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10.0, // Smaller font
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
    );
  }

  Widget _buildImageFromUrl(String imageUrl) {
    // Check if this is a data URL
    if (imageUrl.startsWith('data:image/')) {
      try {
        final bytes = base64Decode(imageUrl.split(',')[1]);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 100, // Reduced height
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageError(),
        );
      } catch (e) {
        debugPrint('Error displaying data URL image: $e');
        return _buildImageError();
      }
    }
    // Check if this is an asset image
    else if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: 100, // Reduced height
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
    // Otherwise, assume it's a network image
    else {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 100, // Reduced height
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      height: 100, // Reduced height
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 48,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'assembly':
        return AppColors.blueAccent;
      case 'finishing':
        return AppColors.greenAccent;
      case 'machinery':
        return AppColors.orangeAccent;
      case 'quality':
        return AppColors.purpleAccent;
      case 'upholstery':
        return Colors.redAccent;
      default:
        return AppColors.primaryRed;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
