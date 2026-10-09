import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../services/booked_inventory_service.dart';
import '../../services/currency_notifier.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/common_widgets.dart';
import '../../main.dart' show currencyNotifier;

/// Browses transport inventory and displays paid transfers in the Booked tab.
///
/// Catalogue selection is a planning preference; the backend owns reservations.
class TransportOptionsScreen extends StatefulWidget {
  const TransportOptionsScreen({super.key});

  @override
  State<TransportOptionsScreen> createState() => _TransportOptionsScreenState();
}

class _TransportOptionsScreenState extends State<TransportOptionsScreen> {
  List<dynamic> _options = [];
  List<Map<String, dynamic>> _bookedOptions = [];
  bool _loading = true;
  String? _error;
  String? _bookingsError;
  bool _bookingsLoading = true;
  int _request = 0;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _moreError;
  String _selectedCategory = 'Car Rental';

  final List<String> _categories = [
    'Car Rental',
    'Train',
    'Bus',
    'Tuk-Tuk',
    'Booked',
  ];

  @override
  void initState() {
    super.initState();
    TripSelectionService.selectedTransport = null;
    currencyNotifier.addListener(_loadTransport);
    _loadTransport();
  }

  @override
  void dispose() {
    currencyNotifier.removeListener(_loadTransport);
    super.dispose();
  }

  Future<void> _loadTransport() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _bookingsError = null;
      _bookingsLoading = true;
      _page = 1;
      _hasMore = false;
      _loadingMore = false;
      _moreError = null;
    });
    // Private booking history must not delay or break the public catalogue.
    _loadBookedTransport(request);
    try {
      final result = await ApiService.getTransportOptionsPage(
        currency: currencyNotifier.value,
      );
      if (mounted && request == _request) {
        setState(() {
          _options = result['data'] as List;
          _hasMore = (result['totalPages'] as int) > 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final request = _request;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final result = await ApiService.getTransportOptionsPage(
        page: _page + 1,
        currency: currencyNotifier.value,
      );
      if (!mounted || request != _request) return;
      final seen = _options.map((option) => '${option['id']}').toSet();
      setState(() {
        _options.addAll(
          (result['data'] as List).where((row) => seen.add('${row['id']}')),
        );
        _page++;
        _hasMore = _page < (result['totalPages'] as int);
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _moreError = error.toString();
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadBookedTransport(int request) async {
    try {
      if (ApiService.mockGetMyBookings == null &&
          await ApiService.getToken() == null) {
        throw const ApiException('Sign in to see your booked transport.');
      }
      final bookings = await ApiService.getMyBookings();
      if (!mounted || request != _request) return;
      setState(() {
        _bookedOptions = BookedInventoryService.paidTransportItems(
          bookings,
        ).map(_displayBookedTransport).toList();
        _bookingsLoading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _bookingsError = error.toString();
        _bookingsLoading = false;
      });
    }
  }

  Map<String, dynamic> _displayBookedTransport(Map<String, dynamic> item) => {
    'id': 'booked-${item['id']}',
    'tag': 'BOOKED & PAID',
    'title': item['transportType'] ?? 'Reserved transport',
    'provider': item['transportProvider'] ?? 'Provider not provided',
    'guests': item['quantity'],
    'bags': null,
    'amenities':
        '${item['routeFrom'] ?? 'Origin not provided'} → ${item['routeTo'] ?? 'Destination not provided'}',
    'price': item['subtotal'] ?? item['unitPrice'],
    'currency': item['currency'],
    'isBestMatch': false,
    'buttonLabel': 'Paid',
    'image': '',
    'booked': true,
    'bookingReference': item['bookingReference'],
    'departureTime': item['departureTime'],
    'arrivalTime': item['arrivalTime'],
  };

  @override
  Widget build(BuildContext context) {
    if (_loading || (_selectedCategory == 'Booked' && _bookingsLoading)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final visibleError = _selectedCategory == 'Booked'
        ? _bookingsError
        : _error;
    if (visibleError != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.figmaDarkGreen),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Transport',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.figmaDarkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Column(
          children: [
            _categorySelector(Theme.of(context)),
            Expanded(
              child: ErrorMessage(
                message: visibleError,
                onRetry: _loadTransport,
              ),
            ),
          ],
        ),
      );
    }

    final availableVehicles = _options
        .map(
          (option) => <String, dynamic>{
            'id': option['id'],
            'tag': option['status'] ?? 'AVAILABLE',
            'title': option['type'] ?? 'Transport type not provided',
            'provider': option['provider'] ?? 'Provider not provided',
            'guests': option['capacity'],
            'bags': null,
            'amenities':
                '${option['routeFrom'] ?? 'Origin not provided'} → ${option['routeTo'] ?? 'Destination not provided'}',
            'price': option['price'],
            'currency': option['currency'],
            'isBestMatch': false,
            'buttonLabel': 'Select',
            'image':
                option['imageUrl'] != null &&
                    option['imageUrl'].toString().isNotEmpty
                ? ApiService.resolveMediaUrl(option['imageUrl'])
                : '',
          },
        )
        .toList();
    final vehicles = _selectedCategory == 'Booked'
        ? _bookedOptions
        : availableVehicles;

    if (vehicles.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Transport')),
        body: Column(
          children: [
            _categorySelector(Theme.of(context)),
            Expanded(
              child: Center(
                child: Text(
                  _selectedCategory == 'Booked'
                      ? 'No paid transport bookings yet.'
                      : 'No transport options available.',
                ),
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3D36)
                              : AppColors.figmaCardBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Transport',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Compare verified island travel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF9EABA4)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Help Icon Button
                  GestureDetector(
                    onTap: () {
                      _showTransportHelp(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3D36)
                              : AppColors.figmaCardBorder,
                        ),
                      ),
                      child: Icon(
                        Icons.help_outline,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Category Pills Filter Row ──
              _categorySelector(theme),

              const SizedBox(height: 18),

              // ── Route Summary Banner ──
              if (_selectedCategory != 'Booked')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.figmaDarkGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR ROUTE · 12 OCTOBER',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.figmaGold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // CMB
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CMB',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Colombo Airport',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            color: AppColors.figmaGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          // SIG
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'SIG',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Sigiriya · 3h 40m',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // ── Vehicle Cards List ──
              ...vehicles.map((vehicle) {
                final isBestMatch = vehicle['isBestMatch'] as bool;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBestMatch
                          ? AppColors.figmaGold
                          : (isDark
                                ? const Color(0xFF2E3D36)
                                : AppColors.figmaCardBorder),
                      width: isBestMatch ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row with Photo & Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppNetworkImage(
                              imageUrl: vehicle['image'] as String,
                              width: 100,
                              height: 75,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (vehicle['tag'] as String).toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.figmaGold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vehicle['title'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vehicle['provider'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF9EABA4)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 14,
                                      color: isDark
                                          ? const Color(0xFF9EABA4)
                                          : const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${vehicle['guests']} guests',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFC7D0CB)
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.luggage_outlined,
                                      size: 14,
                                      color: isDark
                                          ? const Color(0xFF9EABA4)
                                          : const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${vehicle['bags']} bags',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFFC7D0CB)
                                            : const Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Amenities text
                      Text(
                        vehicle['amenities'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.leaf400
                              : const Color(0xFF0F766E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF2E3D36)
                              : AppColors.figmaCardBorder,
                        ),
                      ),

                      // Price & Book Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatMoney(
                                    vehicle['price'],
                                    vehicle['currency']?.toString() ??
                                        currencyNotifier.value,
                                  ),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.leaf400
                                        : AppColors.figmaDarkGreen,
                                  ),
                                ),
                                Text(
                                  'total · all inclusive',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    color: isDark
                                        ? const Color(0xFF9EABA4)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: vehicle['booked'] == true
                                ? null
                                : () {
                                    TripSelectionService.selectedTransport =
                                        vehicle;
                                    // A catalogue choice has no payable booking ID.
                                    // Review the itinerary and use its approved checkout.
                                    Navigator.pushNamed(context, '/itinerary');
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E3A2F)
                                  : AppColors.figmaDarkGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              vehicle['buttonLabel'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              if (_selectedCategory != 'Booked' && _hasMore) ...[
                if (_moreError != null) Text(_moreError!),
                OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(
                    _loadingMore ? 'Loading transport…' : 'Load more transport',
                  ),
                ),
              ],
              const SizedBox(height: 6),

              // ── Scenic Train Tip Card ──
              if (_selectedCategory != 'Booked')
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = 'Train';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF221F18)
                          : const Color(0xFFF6EED8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.train_outlined,
                          color: AppColors.figmaGold,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ella leg? Reserved scenic train seats are available from \$24.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE5D7B5)
                                  : AppColors.figmaDarkGreen,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: isDark
                              ? const Color(0xFFE5D7B5)
                              : AppColors.figmaDarkGreen,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categorySelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = category),
              selectedColor: isDark
                  ? AppColors.leaf400
                  : AppColors.figmaDarkGreen,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? const Color(0xFF0F1713) : Colors.white)
                    : theme.colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTransportHelp(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Transport in Sri Lanka',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'All private vehicles include dedicated air-conditioned comfort, luggage space, certified English-speaking chauffeur-guide, toll fees, and island fuel.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark ? const Color(0xFFE4E7E2) : const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Understood',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
