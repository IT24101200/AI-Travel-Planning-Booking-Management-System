import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Tour search and browse screen matching Figma Dev Mode (05 · Tour Search & Browse).
/// Real API integration, destination & budget filter chips, infinite scroll pagination,
/// loading, empty, and error states, and strict LKR pricing.
class TourSearchBrowseScreen extends StatefulWidget {
  const TourSearchBrowseScreen({super.key});

  @override
  State<TourSearchBrowseScreen> createState() => _TourSearchBrowseScreenState();
}

class _TourSearchBrowseScreenState extends State<TourSearchBrowseScreen> {
  final List<dynamic> _tours = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _page = 1;
  final int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedCategory = 'All';
  int? _selectedDestinationId;
  int _selectedBudgetIndex = 0;

  final List<String> _categories = [
    'All',
    'Culture',
    'Wildlife',
    'Hiking',
    'Heritage',
    'Coast',
  ];

  List<Map<String, dynamic>> _destinationFilters = [
    {'id': null, 'name': 'All Destinations'},
    {'id': 4, 'name': 'Sigiriya'},
    {'id': 2, 'name': 'Kandy'},
    {'id': 5, 'name': 'Ella'},
    {'id': 3, 'name': 'Galle'},
    {'id': 7, 'name': 'Mirissa'},
    {'id': 6, 'name': 'Yala'},
    {'id': 8, 'name': 'Nuwara Eliya'},
  ];

  final List<Map<String, dynamic>> _budgetFilters = [
    {'label': 'All Budgets', 'min': null, 'max': null},
    {'label': '< LKR 2,500', 'min': null, 'max': 2500},
    {'label': 'LKR 2,500 – 5,000', 'min': 2500, 'max': 5000},
    {'label': '> LKR 5,000', 'min': 5000, 'max': null},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadDestinations();
    _loadTours();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = ModalRoute.of(context)?.settings.arguments as String?;
    if (query != null && query.isNotEmpty && _searchCtrl.text.isEmpty) {
      _searchCtrl.text = query;
      _resetAndLoad();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Infinite scroll listener for pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreTours();
    }
  }

  /// Load destinations from backend API to dynamically populate destination chips
  Future<void> _loadDestinations() async {
    try {
      final dests = await ApiService.getDestinations();
      if (dests.isNotEmpty && mounted) {
        setState(() {
          _destinationFilters = [
            {'id': null, 'name': 'All Destinations'},
            ...dests.map((d) => {
                  'id': d['id'] as int?,
                  'name': d['name']?.toString() ?? '',
                }),
          ];
        });
      }
    } catch (_) {}
  }

  void _resetAndLoad() {
    setState(() {
      _page = 1;
      _hasMore = true;
      _tours.clear();
    });
    _loadTours();
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCategory = 'All';
      _selectedDestinationId = null;
      _selectedBudgetIndex = 0;
      _page = 1;
      _hasMore = true;
      _tours.clear();
    });
    _loadTours();
  }

  /// Fetches the first page of tours with active filters
  Future<void> _loadTours() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final selectedBudget = _budgetFilters[_selectedBudgetIndex];
      final results = await ApiService.getTours(
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
        destinationId: _selectedDestinationId,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        minPrice: selectedBudget['min'] as num?,
        maxPrice: selectedBudget['max'] as num?,
        page: 1,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _tours.clear();
          _tours.addAll(results);
          _page = 1;
          _hasMore = results.length >= _pageSize;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load tours. Please check your network connection.';
          _loading = false;
        });
      }
    }
  }

  /// Loads subsequent pages when scrolled to bottom
  Future<void> _loadMoreTours() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    final nextPage = _page + 1;

    try {
      final selectedBudget = _budgetFilters[_selectedBudgetIndex];
      final results = await ApiService.getTours(
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
        destinationId: _selectedDestinationId,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        minPrice: selectedBudget['min'] as num?,
        maxPrice: selectedBudget['max'] as num?,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _page = nextPage;
          _tours.addAll(results);
          _hasMore = results.length >= _pageSize;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find a tour',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Handpicked island experiences',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _resetAndLoad,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.refresh, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating Search Pill ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDECE4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF0E382C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search Sigiriya, safari, surf...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8A9E96),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _resetAndLoad(),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          _resetAndLoad();
                        },
                        child: const Icon(Icons.close, color: Color(0xFF8A9E96), size: 18),
                      )
                    else
                      GestureDetector(
                        onTap: _resetAndLoad,
                        child: const Icon(Icons.tune, color: Color(0xFF6B7280), size: 18),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Category Filter Pills ──
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _resetAndLoad();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Destination Filter Chips ──
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _destinationFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final dest = _destinationFilters[index];
                  final isSelected = _selectedDestinationId == dest['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDestinationId = dest['id'] as int?);
                      _resetAndLoad();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFD4A346) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4A346) : const Color(0xFFEDECE4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: isSelected ? Colors.white : const Color(0xFF8A9E96),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dest['name'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF08201A),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Budget Filter Chips ──
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: _budgetFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final b = _budgetFilters[index];
                  final isSelected = _selectedBudgetIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedBudgetIndex = index);
                      _resetAndLoad();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF134035) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF134035) : const Color(0xFFEDECE4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 13,
                            color: isSelected ? Colors.white : const Color(0xFF8A9E96),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            b['label'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF08201A),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Count and Active Filters Row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _loading ? 'Searching...' : '${_tours.length} experiences',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF08201A),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty ||
                      _selectedCategory != 'All' ||
                      _selectedDestinationId != null ||
                      _selectedBudgetIndex != 0)
                    GestureDetector(
                      onTap: _resetFilters,
                      child: const Text(
                        'Clear filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD4A346),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Body Content (Loading / Error / Empty / List with pagination) ──
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _tours.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0E382C)),
            SizedBox(height: 14),
            Text(
              'Finding island tours...',
              style: TextStyle(color: Color(0xFF5A7067), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _tours.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Color(0xFFD9534F)),
              const SizedBox(height: 14),
              const Text(
                'Unable to load tours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF08201A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A9E96)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadTours,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tours.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6EED8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_outlined, size: 34, color: Color(0xFFD4A346)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No tours found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF08201A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No tours match your current search or filters. Try adjusting your destination, category, or budget.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8A9E96), height: 1.4),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF0E382C)),
                label: const Text(
                  'Reset Filters',
                  style: TextStyle(color: Color(0xFF0E382C), fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0E382C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF0E382C),
      onRefresh: () async => _resetAndLoad(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        itemCount: _tours.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _tours.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF0E382C),
                  ),
                ),
              ),
            );
          }
          final tour = _tours[index];
          return _buildFigmaTourCard(tour);
        },
      ),
    );
  }

  Widget _buildFigmaTourCard(dynamic tourData) {
    final Map<String, dynamic> tour = tourData is Map<String, dynamic>
        ? tourData
        : Map<String, dynamic>.from(tourData as Map);

    final tourName = tour['name']?.toString() ?? 'Sri Lanka Tour';
    final category = (tour['category'] ?? 'EXPERIENCE').toString().toUpperCase();
    final location = tour['location']?.toString() ??
        tour['destinationName']?.toString() ??
        'Sri Lanka';

    final duration = tour['duration']?.toString() ??
        (tour['durationHours'] != null ? '${tour['durationHours']} hours' : 'Half day');

    final rating = (tour['rating'] ?? 4.9).toString();

    final num priceNum = tour['price'] is num
        ? tour['price'] as num
        : num.tryParse(tour['price']?.toString() ?? '0') ?? 0;
    final formattedPrice = 'LKR ${NumberFormat('#,##0').format(priceNum)}';

    final tourId = tour['id']?.toString() ?? '1';

    final uploadedImage = ApiService.resolveMediaUrl(tour['imageUrl']?.toString());
    final imageUrl = uploadedImage.isNotEmpty
        ? uploadedImage
        : AppDestinations.getImageForDestination(tourName);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDECE4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Image (rounded square)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 106,
              height: 106,
              child: imageUrl.startsWith('http')
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: const Color(0xFF0E382C)),
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: const Color(0xFF0E382C)),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Right Content
          Expanded(
            child: SizedBox(
              height: 106,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category & Rating Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD4A346),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFD4A346), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Title
                  Text(
                    tourName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF08201A),
                    ),
                  ),

                  // Location & Duration Row
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF8A9E96)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.schedule, size: 13, color: Color(0xFF8A9E96)),
                      const SizedBox(width: 2),
                      Text(
                        duration,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),

                  // Price & Action Arrow Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'from',
                            style: TextStyle(fontSize: 10, color: Color(0xFF8A9E96)),
                          ),
                          Text(
                            formattedPrice,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0E382C),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/tour-details', arguments: tourId),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0E382C),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.north_east, color: Colors.white, size: 17),
                          ),
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
