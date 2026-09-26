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

  String _selectedSort = 'Top Rated';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'label': 'All Tours', 'icon': Icons.explore},
    {'name': 'Heritage', 'label': 'Heritage & Citadels', 'icon': Icons.account_balance},
    {'name': 'Rail journey', 'label': 'Scenic Tea & Trains', 'icon': Icons.train},
    {'name': 'Safari', 'label': 'Wildlife Safari', 'icon': Icons.pets},
    {'name': 'Marine', 'label': 'Coastal & Surfing', 'icon': Icons.surfing},
    {'name': 'Tea', 'label': 'Highland Estates', 'icon': Icons.local_florist},
    {'name': 'Snorkelling', 'label': 'Reef Snorkelling', 'icon': Icons.scuba_diving},
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
    List<dynamic> list = List.from(_tours);
    if (_selectedCategory != 'All') {
      final cat = _selectedCategory.toLowerCase();
      list = list.where((tour) {
        final name = (tour['name'] ?? '').toString().toLowerCase();
        final category = (tour['category'] ?? '').toString().toLowerCase();
        return name.contains(cat) || category.contains(cat);
      }).toList();
    }

    if (_selectedSort == 'Price: Low to High') {
      list.sort((a, b) => ((a['price'] ?? 0) as num).compareTo((b['price'] ?? 0) as num));
    } else if (_selectedSort == 'Price: High to Low') {
      list.sort((a, b) => ((b['price'] ?? 0) as num).compareTo((a['price'] ?? 0) as num));
    }
    return list;
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Tour Search & Browse',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.jungle600),
            tooltip: 'Filter options',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter presets applied')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Search & Filter Controls (Stitch Serendib Verdant style) ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Integrated Search Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: AppColors.inkTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search Sigiriya, Ella, Yala safari...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.inkTertiary,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                onSubmitted: (value) => _loadTours(search: value),
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  _loadTours();
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.inkTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.leaf100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.leaf200),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.tune, color: AppColors.jungle600, size: 20),
                            onPressed: () {
                              _showSortBottomSheet();
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.sand500,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Horizontal Category ChoiceChips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((catItem) {
                      final catName = catItem['name'] as String;
                      final catLabel = catItem['label'] as String;
                      final catIcon = catItem['icon'] as IconData;
                      final isSelected = _selectedCategory == catName;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() => _selectedCategory = catName);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.jungle600 : AppColors.leaf100,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.jungle600.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  catIcon,
                                  size: 15,
                                  color: isSelected ? Colors.white : AppColors.jungle600,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  catName == 'All' ? 'All Tours (${displayList.length})' : catLabel,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.jungle700,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),
                // Status Count & Sort Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.jungle500,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${displayList.length} Expeditions available',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _showSortBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Sort: ',
                              style: TextStyle(fontSize: 11, color: AppColors.inkTertiary),
                            ),
                            Text(
                              _selectedSort,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.jungle600,
                              ),
                            ),
                            const Icon(Icons.expand_more, size: 14, color: AppColors.inkSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tour List ──
          Expanded(
            child: _loading
                ? const LoadingIndicator(message: 'Discovering Serendib expeditions...')
                : _error != null
                    ? ErrorMessage(message: _error!, onRetry: () => _loadTours())
                    : displayList.isEmpty
                        ? EmptyState(
                            icon: Icons.tour_outlined,
                            message: _searchCtrl.text.isNotEmpty
                                ? 'No expeditions matching "${_searchCtrl.text}"'
                                : 'No expeditions available for category $_selectedCategory',
                            actionLabel: 'Reset Filters',
                            onAction: () {
                              _searchCtrl.clear();
                              setState(() {
                                _selectedCategory = 'All';
                                _selectedSort = 'Top Rated';
                              });
                              _loadTours();
                            },
                          )
                        : RefreshIndicator(
                            color: AppColors.jungle600,
                            onRefresh: () => _loadTours(search: _searchCtrl.text),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort Expeditions By',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.star, color: AppColors.sand500),
                  title: const Text('Top Rated (4.8+ First)'),
                  trailing: _selectedSort == 'Top Rated' ? const Icon(Icons.check, color: AppColors.jungle600) : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Top Rated');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward, color: AppColors.jungle600),
                  title: const Text('Price: Low to High'),
                  trailing: _selectedSort == 'Price: Low to High' ? const Icon(Icons.check, color: AppColors.jungle600) : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Price: Low to High');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_downward, color: AppColors.coral500),
                  title: const Text('Price: High to Low'),
                  trailing: _selectedSort == 'Price: High to Low' ? const Icon(Icons.check, color: AppColors.jungle600) : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Price: High to Low');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build an image-rich Serendib Verdant tour card
  Widget _buildTourCard(Map<String, dynamic> tour) {
    final tourName = tour['name'] ?? 'Unnamed Tour';
    final uploadedImage = ApiService.resolveMediaUrl(
      tour['imageUrl']?.toString(),
    );
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);
    final price = (tour['price'] ?? 0).toDouble();
    final duration = tour['durationHours'] ?? 6;
    final category = tour['category'] ?? 'Heritage';
    final location = tour['location'] ?? 'Cultural Triangle, Sri Lanka';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            // Tour Image with Badges & Vignette
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Atmospheric gradient vignette
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.jungle900.withValues(alpha: 0.8),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top Category & Duration Badges
                Positioned(
                  top: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: AppColors.jungle700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sand100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.sand700),
                            const SizedBox(width: 3),
                            Text(
                              '${duration}h Duration',
                              style: const TextStyle(
                                color: AppColors.sand700,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating Pill Float (Bottom Left)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.jungle900.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 14, color: AppColors.sand400),
                        SizedBox(width: 4),
                        Text(
                          '4.9',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ' (128)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Price Badge Float (Bottom Right)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sand500,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.jungle900,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '/person',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.jungle900,
                            fontWeight: FontWeight.w500,
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
                    location.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sand600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tourName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (tour['description'] != null &&
                      tour['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tour['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Highlights & Amenities Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPillTag(Icons.verified, 'Expert Guide', AppColors.leaf50, AppColors.jungle600),
                      _buildPillTag(Icons.directions_car, 'AC Transfer', AppColors.mist, AppColors.inkSecondary),
                      _buildPillTag(Icons.local_cafe, 'Refreshment', AppColors.mist, AppColors.inkSecondary),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons Row
                  Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: AppColors.leaf50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.favorite_border, color: AppColors.jungle600, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Saved $tourName to wishlist')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/tour-details', arguments: tour['id']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.jungle600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'View Expedition',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                          ),
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

  Widget _buildPillTag(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
