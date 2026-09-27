import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final List<String> _categoryTabs = ['All', 'Culture', 'Wildlife', 'Hiking', 'Coast'];

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
      backgroundColor: const Color(0xFFF7F5EF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find a tour',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          'Handpicked island experiences',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border, color: Color(0xFF111827), size: 20),
                  ),
                ],
              ),
            ),

            // ── Search Bar Capsule ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF111827)),
                        decoration: const InputDecoration(
                          hintText: 'Search Sigiriya, safari, surf...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
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
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _showSortBottomSheet,
                      child: const Icon(Icons.tune, color: Color(0xFF6B7280), size: 18),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category Pills Row ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _categoryTabs.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.figmaDarkGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.figmaDarkGreen : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Count and Sort Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayList.length} experiences',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showSortBottomSheet,
                    child: Row(
                      children: [
                        Text(
                          'Top rated ↓',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF166B4F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tour Cards List ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? ErrorMessage(message: _error!, onRetry: () => _loadTours())
                      : displayList.isEmpty
                          ? EmptyState(
                              icon: Icons.tour_outlined,
                              message: 'No experiences found for this filter.',
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
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: displayList.length,
                              itemBuilder: (context, index) {
                                final tour = displayList[index];
                                return _buildFigmaTourCard(tour);
                              },
                            ),
            ),
          ],
        ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort Expeditions By',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.star, color: AppColors.figmaGold),
                  title: const Text('Top Rated (4.8+ First)'),
                  trailing: _selectedSort == 'Top Rated' ? const Icon(Icons.check, color: AppColors.figmaDarkGreen) : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Top Rated');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward, color: AppColors.figmaDarkGreen),
                  title: const Text('Price: Low to High'),
                  trailing: _selectedSort == 'Price: Low to High' ? const Icon(Icons.check, color: AppColors.figmaDarkGreen) : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Price: Low to High');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_downward, color: Color(0xFFE4694A)),
                  title: const Text('Price: High to Low'),
                  trailing: _selectedSort == 'Price: High to Low' ? const Icon(Icons.check, color: AppColors.figmaDarkGreen) : null,
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

  Widget _buildFigmaTourCard(Map<String, dynamic> tour) {
    final tourName = tour['name'] ?? 'Tour';
    final uploadedImage = ApiService.resolveMediaUrl(
      tour['imageUrl']?.toString(),
    );
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);
    final price = (tour['price'] ?? 68).toString();
    final duration = tour['durationHours'] ?? 6;
    final category = (tour['category'] ?? 'CULTURE').toString().toUpperCase();
    final location = tour['location'] ?? (tourName.split(' ').first);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 110,
              height: 125,
              child: AppNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Right: Content details
          Expanded(
            child: SizedBox(
              height: 125,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category & Rating Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            category,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.figmaGold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star_border, color: AppColors.figmaGold, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                '4.9',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Title
                      Text(
                        tourName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Location & Duration
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 3),
                          Text(
                            location,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 3),
                          Text(
                            '$duration hours',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Bottom price & arrow button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'from',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF9CA3AF)),
                          ),
                          Text(
                            '\$$price',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.figmaDarkGreen,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/tour-details', arguments: tour['id']);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.figmaDarkGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.north_east, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
