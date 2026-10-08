import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../services/date_time_contract.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/agent_workflow_card.dart';
import 'package:intl/intl.dart';

/// Trip history screen matching Figma frame 16 · Trip History / My Trips (node 7:11390)
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  String? _error;
  bool _loading = true;
  String _activeTab = 'Upcoming';
  String _selectedYear = 'All years';

  static const _historyStatuses = {
    'Planning',
    'AwaitingApproval',
    'Confirmed',
    'Completed',
    'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? _status(dynamic value, {required bool booking}) {
    const bookingStatuses = [
      'Draft',
      'AwaitingApproval',
      'Confirmed',
      'Rejected',
      'Cancelled',
      'Completed',
    ];
    const requestStatuses = [
      'Pending',
      'Planning',
      'Planned',
      'Failed',
      'Cancelled',
      'AwaitingApproval',
      'Approved',
      'Rejected',
    ];
    final statuses = booking ? bookingStatuses : requestStatuses;
    final index = int.tryParse(value?.toString() ?? '');
    final raw = index != null && index >= 0 && index < statuses.length
        ? statuses[index]
        : value?.toString() ?? 'Unknown';
    final normalized = raw.replaceAll(' ', '').toLowerCase();
    switch (normalized) {
      case 'draft':
      case 'pending':
      case 'planning':
      case 'planned':
        return 'Planning';
      case 'awaitingapproval':
        return 'AwaitingApproval';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return null;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getMyBookings(),
        ApiService.getMyTripRequests(),
      ]);
      final bookings = results[0]
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final requests = results[1]
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final requestsById = {
        for (final request in requests) request['id'].toString(): request,
      };
      final bookedRequestIds = bookings
          .map((booking) => booking['tripRequestId']?.toString())
          .toSet();
      final records = <Map<String, dynamic>>[];
      for (final booking in bookings) {
        final record = _tripCard(
          booking,
          requestsById[booking['tripRequestId']?.toString()],
          booking: true,
        );
        if (_historyStatuses.contains(record['status'])) records.add(record);
      }
      for (final request in requests) {
        if (!bookedRequestIds.contains(request['id'].toString())) {
          final record = _tripCard(request, request, booking: false);
          if (_historyStatuses.contains(record['status'])) records.add(record);
        }
      }
      if (mounted) setState(() => _trips = records);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Resolves the human-readable destination title from user request prompt or booking
  String _parseTripTitle(
    Map<String, dynamic> record,
    Map<String, dynamic>? request,
    bool booking,
  ) {
    final structuredDestinations =
        request?['destinations'] ?? record['destinations'];
    if (structuredDestinations is List) {
      final names = structuredDestinations
          .whereType<Map>()
          .map((item) => item['name'] ?? item['destinationName'])
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }

    final destinationNames =
        request?['destinationNames'] ?? record['destinationNames'];
    if (destinationNames is List) {
      final names = destinationNames
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }

    final raw =
        (request?['rawRequestText'] ?? record['rawRequestText'])?.toString() ??
        '';
    if (raw.isNotEmpty) {
      // 1. Match 'Destination: <destinations>.'
      final destMatch = RegExp(
        r'Destination:\s*([^.]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (destMatch != null && destMatch.group(1)?.trim().isNotEmpty == true) {
        return destMatch.group(1)!.trim();
      }
      // 2. Match 'through <destinations> for'
      final throughMatch = RegExp(
        r'through\s+([A-Za-z,\s&]+?)(?:\s+for|\s+with|\.|$)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (throughMatch != null &&
          throughMatch.group(1)?.trim().isNotEmpty == true) {
        return throughMatch.group(1)!.trim();
      }
    }

    // 3. Tour names from booking
    final items = record['bookingItems'];
    final tourNames = items is List
        ? items
              .whereType<Map>()
              .map((item) => item['tourName'])
              .whereType<String>()
              .toList()
        : <String>[];
    if (tourNames.isNotEmpty) return tourNames.join(', ');

    // 4. Destination name from relation (if not Badulla or if no other clues exist)
    final destName = request?['destinationName']?.toString();
    if (destName != null &&
        destName.isNotEmpty &&
        destName.toLowerCase() != 'badulla') {
      return destName;
    }

    if (raw.isNotEmpty) {
      final firstPart = raw.split('.').first.trim();
      if (firstPart.length <= 45 &&
          !firstPart.toLowerCase().contains('badulla')) {
        return firstPart;
      }
    }

    if (destName != null && destName.isNotEmpty) return destName;
    return booking
        ? 'Booking ${record['bookingReference'] ?? record['id']}'
        : 'Trip request #${record['id']}';
  }

  /// Extracts interest tags from raw prompt text
  List<String> _parseInterests(
    Map<String, dynamic> record,
    Map<String, dynamic>? request,
  ) {
    final raw =
        (request?['rawRequestText'] ?? record['rawRequestText'])?.toString() ??
        '';
    if (raw.isNotEmpty) {
      final match = RegExp(
        r'Interests:\s*([^.]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null && match.group(1)?.trim().isNotEmpty == true) {
        return match
            .group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  /// Extracts preferences and notes from raw prompt text
  String? _parsePreferences(
    Map<String, dynamic> record,
    Map<String, dynamic>? request,
  ) {
    final raw =
        (request?['rawRequestText'] ?? record['rawRequestText'])?.toString() ??
        '';
    if (raw.isNotEmpty) {
      final match = RegExp(
        r'(?:Preferences|Notes):\s*([^.]+)',
        caseSensitive: false,
      ).firstMatch(raw);
      if (match != null && match.group(1)?.trim().isNotEmpty == true) {
        return match.group(1)!.trim();
      }
    }
    return null;
  }

  Map<String, dynamic> _tripCard(
    Map<String, dynamic> record,
    Map<String, dynamic>? request, {
    required bool booking,
  }) {
    final status = _status(record['status'], booking: booking);
    final title = _parseTripTitle(record, request, booking);
    final start = parseDateOnly(request?['startDate']);
    final end = parseDateOnly(request?['endDate']);
    final created = parseInstant(record['createdAt']);
    final nights = start != null && end != null
        ? end.difference(start).inDays
        : null;
    final dates = start != null && end != null
        ? '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}${nights != null && nights > 0 ? " ($nights nights)" : ""}'
        : created != null
        ? 'Created ${DateFormat.yMMMd().format(created)}'
        : 'Dates unavailable';
    final amount = booking ? record['totalCost'] : record['budgetCeiling'];
    final currency = record['currency']?.toString() ?? '';
    final travellers = request?['travellerCount'] ?? record['travellerCount'];
    final interests = _parseInterests(record, request);
    final preferences = _parsePreferences(record, request);
    final bookingItems = record['bookingItems'] is List
        ? (record['bookingItems'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final hotelItems = bookingItems.where(_isHotelItem).toList();
    final transportItems = bookingItems.where(_isTransportItem).toList();

    return {
      ...record,
      'isBooking': booking,
      'source': record,
      'title': title,
      'dates': dates,
      'year': (start ?? created)?.year.toString(),
      'priceLabel': amount is num
          ? '${booking ? '' : 'Budget '}$currency ${NumberFormat('#,##0.##').format(amount)}'
                .trim()
          : 'Cost unavailable',
      'status': status,
      'statusColor':
          status == 'Cancelled' || status == 'Rejected' || status == 'Failed'
          ? const Color(0xFFDC2626)
          : status == 'Confirmed' || status == 'Completed'
          ? const Color(0xFF267A55)
          : const Color(0xFFB36A16),
      'image': AppDestinations.getImageForDestination(title),
      'travellers': travellers,
      'interests': interests,
      'preferences': preferences,
      'nights': nights,
      'hotelItems': hotelItems,
      'transportItems': transportItems,
      'hasBookedInventory': hotelItems.isNotEmpty || transportItems.isNotEmpty,
    };
  }

  bool _isHotelItem(Map<String, dynamic> item) {
    final type = item['itemType'];
    final normalized = type?.toString().toLowerCase() ?? '';
    return type == 1 ||
        normalized == 'room' ||
        normalized == 'hotel' ||
        item['hotelName'] != null;
  }

  bool _isTransportItem(Map<String, dynamic> item) {
    final type = item['itemType'];
    final normalized = type?.toString().toLowerCase() ?? '';
    return type == 2 ||
        normalized == 'transport' ||
        item['transportType'] != null;
  }

  bool _inTab(Map<String, dynamic> trip, String tab) {
    final status = trip['status'];
    if (tab == 'Booked') {
      return trip['isBooking'] == true && status == 'Confirmed';
    }
    if (tab == 'Completed') return status == 'Completed';
    if (tab == 'Cancelled') return status == 'Cancelled';
    return status == 'Planning' || status == 'AwaitingApproval';
  }

  String _itemPrice(Map<String, dynamic> item) {
    final amount = item['subtotal'] ?? item['unitPrice'];
    if (amount is! num) return '';
    final currency = item['currency']?.toString() ?? 'LKR';
    return '$currency ${NumberFormat('#,##0.##').format(amount)}';
  }

  String _dateLabel(dynamic value) {
    final date = parseLocalSchedule(value);
    return date == null ? '' : DateFormat.yMMMd().format(date);
  }

  Widget _buildBookedInventory(Map<String, dynamic> trip, bool isDark) {
    final hotelItems =
        (trip['hotelItems'] as List<Map<String, dynamic>>?) ?? [];
    final transportItems =
        (trip['transportItems'] as List<Map<String, dynamic>>?) ?? [];
    final cards = <Widget>[
      ...hotelItems.map(
        (item) => _buildInventoryCard(
          icon: Icons.hotel_outlined,
          category: 'HOTEL STAY',
          title: item['hotelName']?.toString() ?? 'Reserved hotel',
          details: [
            [
                  item['roomType']?.toString(),
                  item['roomCapacity'] != null
                      ? 'Up to ${item['roomCapacity']} guests'
                      : null,
                ]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
            [
              _dateLabel(item['checkInDate']),
              _dateLabel(item['checkOutDate']),
            ].where((value) => value.isNotEmpty).join(' → '),
            item['hotelAddress']?.toString() ?? '',
          ],
          price: _itemPrice(item),
          isDark: isDark,
        ),
      ),
      ...transportItems.map(
        (item) => _buildInventoryCard(
          icon: Icons.directions_transit_outlined,
          category: 'TRANSIT',
          title: [item['transportType'], item['transportProvider']]
              .whereType<Object>()
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .join(' · '),
          details: [
            [item['routeFrom'], item['routeTo']]
                .whereType<Object>()
                .map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .join(' → '),
            _dateLabel(item['departureTime']),
          ],
          price: _itemPrice(item),
          isDark: isDark,
        ),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF122E25) : const Color(0xFFF2FAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF285241) : const Color(0xFFCDE8DA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Color(0xFF2F9B70),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'BOOKED BY THE 4 AI AGENTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFF81C7A7)
                        : const Color(0xFF13684B),
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 8) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cards
                    .map((card) => SizedBox(width: cardWidth, child: card))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard({
    required IconData icon,
    required String category,
    required String title,
    required List<String> details,
    required String price,
    required bool isDark,
  }) {
    final visibleDetails = details.where((value) => value.isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A382E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF285241) : const Color(0xFFE2F3EA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF267A55)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2F9B70),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title.isEmpty ? category : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF123F32),
                  ),
                ),
                ...visibleDetails.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        color: isDark
                            ? const Color(0xFFB7C5BE)
                            : const Color(0xFF6E7772),
                      ),
                    ),
                  ),
                ),
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.leaf400
                          : const Color(0xFF267A55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripImage(String imagePath) {
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: const Color(0xFF1E3A2F),
          alignment: Alignment.center,
          child: const Icon(Icons.landscape, color: Colors.white54),
        ),
      );
    }
    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFF1E3A2F),
        alignment: Alignment.center,
        child: const Icon(Icons.landscape, color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: ErrorMessage(message: _error!, onRetry: _loadData),
        ),
      );
    }
    final currentList = _trips
        .where((trip) => _inTab(trip, _activeTab))
        .toList();
    final filteredList = currentList
        .where(
          (trip) =>
              _selectedYear == 'All years' || trip['year'] == _selectedYear,
        )
        .toList();
    final upcomingCount = _trips
        .where((trip) => _inTab(trip, 'Upcoming'))
        .length;
    final bookedCount = _trips.where((trip) => _inTab(trip, 'Booked')).length;
    final completedCount = _trips
        .where((trip) => _inTab(trip, 'Completed'))
        .length;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Trips',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Your journeys, past and future',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF6E7772),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.add,
                        color: isDark ? Colors.white : AppColors.figmaDarkGreen,
                        size: 20,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/trip-request');
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/itinerary'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3D36)
                            : const Color(0xFFE4E7E2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A2F)
                                : const Color(0xFFEAF2EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            color: isDark
                                ? AppColors.leaf400
                                : AppColors.figmaDarkGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'My Itineraries',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: isDark
                              ? Colors.white70
                              : AppColors.figmaDarkGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Segmented Tabs Pill ──
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E3D36)
                        : const Color(0xFFE4E7E2),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabItem('Upcoming'),
                    _buildTabItem('Booked'),
                    _buildTabItem('Completed'),
                    _buildTabItem('Cancelled'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Trips Summary Row ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$upcomingCount upcoming · $bookedCount booked · $completedCount completed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    initialValue: _selectedYear,
                    onSelected: (val) => setState(() => _selectedYear = val),
                    child: Row(
                      children: [
                        Text(
                          _selectedYear,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2F7057),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: Color(0xFF2F7057),
                        ),
                      ],
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'All years',
                        child: Text('All years'),
                      ),
                      ...(_trips
                              .map((trip) => trip['year'])
                              .whereType<String>()
                              .toSet()
                              .toList()
                            ..sort((a, b) => b.compareTo(a)))
                          .map(
                            (year) =>
                                PopupMenuItem(value: year, child: Text(year)),
                          ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Trip Cards ──
              if (filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 36,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D36)
                          : const Color(0xFFE4E7E2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.luggage_outlined,
                          size: 28,
                          color: Color(0xFF6E7772),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ${_activeTab.toLowerCase()} trips found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse our handpicked tours across Sri Lanka to start planning.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF6E7772),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/tour-search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF123F32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Explore Tours',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filteredList.map((trip) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF10291F,
                          ).withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Image Top Half
                        Stack(
                          children: [
                            SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: _buildTripImage(trip['image'] as String),
                            ),
                            // Tint overlay
                            Positioned.fill(
                              child: Container(
                                color: const Color(
                                  0xFF08271E,
                                ).withValues(alpha: 0.18),
                              ),
                            ),
                            // Status Badge
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  trip['status'] as String,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: trip['statusColor'] as Color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Details Bottom Half
                        Padding(
                          padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trip['title'] as String,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 11,
                                              color: isDark
                                                  ? const Color(0xFF9EABA4)
                                                  : const Color(0xFF6E7772),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                trip['dates'] as String,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 9.5,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF9EABA4,
                                                            )
                                                          : const Color(
                                                              0xFF6E7772,
                                                            ),
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (trip['travellers'] != null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people_outline,
                                                size: 11,
                                                color: isDark
                                                    ? const Color(0xFF9EABA4)
                                                    : const Color(0xFF6E7772),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${trip['travellers']} travellers',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 9.5,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF9EABA4,
                                                            )
                                                          : const Color(
                                                              0xFF6E7772,
                                                            ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    trip['priceLabel'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? AppColors.leaf400
                                          : const Color(0xFF123F32),
                                    ),
                                  ),
                                ],
                              ),
                              if ((trip['interests'] as List<String>?)
                                      ?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: (trip['interests'] as List<String>)
                                      .map((interest) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E3A2F)
                                                : const Color(0xFFEEFAF4),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF2E4D3E)
                                                  : const Color(0xFFD0EAE0),
                                            ),
                                          ),
                                          child: Text(
                                            interest,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? const Color(0xFF81C784)
                                                  : const Color(0xFF13684B),
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
                                ),
                              ],
                              if (trip['preferences'] != null &&
                                  (trip['preferences'] as String)
                                      .isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.notes,
                                      size: 11,
                                      color: isDark
                                          ? const Color(0xFF9EABA4)
                                          : const Color(0xFF8A9E96),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip['preferences'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          fontStyle: FontStyle.italic,
                                          color: isDark
                                              ? const Color(0xFF9EABA4)
                                              : const Color(0xFF6E7772),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_activeTab == 'Booked' &&
                                  trip['hasBookedInventory'] == true)
                                _buildBookedInventory(trip, isDark),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // View Itinerary Button
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/itinerary',
                                            arguments: trip['isBooking'] == true
                                                ? {
                                                    'itineraryId':
                                                        trip['itineraryId'],
                                                  }
                                                : {'tripRequestId': trip['id']},
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF123F32,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'View Itinerary',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Manage Details Button
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          if (trip['isBooking'] == true) {
                                            Navigator.pushNamed(
                                              context,
                                              '/booking-status',
                                              arguments: trip['source'],
                                            );
                                          } else {
                                            _showTripDetailsSheet(trip);
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? const Color(0xFF1E2824)
                                              : Colors.white,
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3E4D46)
                                                : const Color(0xFFE4E7E2),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          trip['isBooking'] == true
                                              ? 'Manage Pass'
                                              : 'Trip Details',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF123F32),
                                          ),
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
                  );
                }),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String tab) {
    final isSelected = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF123F32) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            tab,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF6E7772),
            ),
          ),
        ),
      ),
    );
  }

  void _showTripDetailsSheet(Map<String, dynamic> trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final interests = (trip['interests'] as List<String>?) ?? [];
    final preferences = trip['preferences'] as String?;
    final travellers = trip['travellers']?.toString() ?? '2';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trip['title'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: trip['statusColor'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trip['status'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDetailRow(
                Icons.confirmation_number_outlined,
                'Reference',
                'Trip Request #${trip['id']}',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.calendar_today_outlined,
                'Dates',
                trip['dates'] as String,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.people_outline,
                'Travelers',
                '$travellers Guests',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.account_balance_wallet_outlined,
                'Budget Ceiling',
                trip['priceLabel'] as String,
              ),
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'TRAVEL INTERESTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF9EABA4)
                        : const Color(0xFF6E7772),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: interests.map((interest) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A2F)
                            : const Color(0xFFEEFAF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        interest,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : const Color(0xFF13684B),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (preferences != null && preferences.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'PREFERENCES & NOTES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF9EABA4)
                        : const Color(0xFF6E7772),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preferences,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
              if ((trip['isBooking'] == true
                          ? trip['tripRequestId']
                          : trip['id'])
                      is int &&
                  ((trip['isBooking'] == true
                              ? trip['tripRequestId']
                              : trip['id'])
                          as int) >
                      0) ...[
                const SizedBox(height: 16),
                AgentWorkflowCard(
                  tripRequestId:
                      (trip['isBooking'] == true
                              ? trip['tripRequestId']
                              : trip['id'])
                          as int,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(
                      context,
                      '/itinerary',
                      arguments: trip['isBooking'] == true
                          ? {'itineraryId': trip['itineraryId']}
                          : {'tripRequestId': trip['id']},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF123F32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Open Itinerary'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6E7772),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
