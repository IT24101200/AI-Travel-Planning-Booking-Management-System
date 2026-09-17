import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Tour search and browse screen with category chips, search bar, and scenic tour cards.
class TourSearchBrowseScreen extends StatefulWidget {
  const TourSearchBrowseScreen({super.key});

  @override
  State<TourSearchBrowseScreen> createState() => _TourSearchBrowseScreenState();
}

class _TourSearchBrowseScreenState extends State<TourSearchBrowseScreen> {
  List<dynamic> _tours = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Heritage',
    'Hiking',
    'Wildlife',
    'Beach',
    'Tea',
    'Rail',
  ];

  @override
  void initState() {
    super.initState();
    _loadTours();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = ModalRoute.of(context)?.settings.arguments as String?;
    if (query != null && query.isNotEmpty && _searchCtrl.text.isEmpty) {
      _searchCtrl.text = query;
      _loadTours(search: query);
    }
  }

  /// Fetch tours from the backend API
  Future<void> _loadTours({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ApiService.getTours(search: search);
      if (mounted) {
        setState(() {
          _tours = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to connect to server. Please try again.';
          _loading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredTours {
    if (_selectedCategory == 'All') return _tours;
    final cat = _selectedCategory.toLowerCase();
    return _tours.where((tour) {
      final name = (tour['name'] ?? '').toString().toLowerCase();
      final category = (tour['category'] ?? '').toString().toLowerCase();
      return name.contains(cat) || category.contains(cat);
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredTours;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Tours & Experiences'),
      ),
      body: Column(
        children: [
          // ── Search & Filter Controls ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search tours, locations, activities...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.jungle600),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadTours();
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (value) => _loadTours(search: value),
                ),
                const SizedBox(height: 10),
                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                          selectedColor: AppColors.jungle600,
                          backgroundColor: AppColors.mist,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.ink2,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.jungle600 : AppColors.line,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Tour List ──
          Expanded(
            child: _loading
                ? const LoadingIndicator(message: 'Discovering experiences...')
                : _error != null
                    ? ErrorMessage(message: _error!, onRetry: () => _loadTours())
                    : displayList.isEmpty
                        ? EmptyState(
                            icon: Icons.tour_outlined,
                            message: _searchCtrl.text.isNotEmpty
                                ? 'No tours matching "${_searchCtrl.text}"'
                                : 'No tours available for category $_selectedCategory',
                            actionLabel: 'Reset Filters',
                            onAction: () {
                              _searchCtrl.clear();
                              setState(() => _selectedCategory = 'All');
                              _loadTours();
                            },
                          )
                        : RefreshIndicator(
                            color: AppColors.jungle600,
                            onRefresh: () => _loadTours(search: _searchCtrl.text),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final tour = displayList[index];
                                return _buildTourCard(tour);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Build an image-rich tour card
  Widget _buildTourCard(Map<String, dynamic> tour) {
    final tourName = tour['name'] ?? 'Unnamed Tour';
    final imageUrl = AppDestinations.getImageForDestination(tourName);
    final price = (tour['price'] ?? 0).toDouble();
    final currency = tour['currency'] ?? 'USD';
    final duration = tour['durationHours'] ?? 2;
    final category = tour['category'] ?? 'Excursion';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(context, '/tour-details', arguments: tour['id']);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tour Image with Badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Category Chip
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.jungle900.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Price Tag
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.jungle800,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.sand400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          currency,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Tour Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tourName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (tour['description'] != null && tour['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      tour['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.ink3,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDetailBadge(Icons.timer_outlined, '${duration}h Duration'),
                      const SizedBox(width: 12),
                      _buildDetailBadge(
                        Icons.schedule_outlined,
                        tour['defaultStartTime'] ?? 'Morning',
                      ),
                      const Spacer(),
                      const Text(
                        'Details →',
                        style: TextStyle(
                          color: AppColors.jungle600,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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

  Widget _buildDetailBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.jungle600),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.ink2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
