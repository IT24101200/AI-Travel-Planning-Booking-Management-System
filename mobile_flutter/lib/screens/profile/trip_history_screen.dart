import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
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
  String _activeTab = 'Upcoming'; // 'Upcoming', 'Completed', 'Cancelled'
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
    const bookingStatuses = ['Draft', 'AwaitingApproval', 'Confirmed', 'Rejected', 'Cancelled', 'Completed'];
    const requestStatuses = ['Pending', 'Planning', 'Planned', 'Failed', 'Cancelled', 'AwaitingApproval', 'Approved', 'Rejected'];
    final statuses = booking ? bookingStatuses : requestStatuses;
    final index = int.tryParse(value?.toString() ?? '');
    final raw = index != null && index >= 0 && index < statuses.length
        ? statuses[index] : value?.toString() ?? 'Unknown';
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
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([ApiService.getMyBookings(), ApiService.getMyTripRequests()]);
      final bookings = results[0].map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final requests = results[1].map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final requestsById = {for (final request in requests) request['id'].toString(): request};
      final bookedRequestIds = bookings.map((booking) => booking['tripRequestId']?.toString()).toSet();
      final records = <Map<String, dynamic>>[];
      for (final booking in bookings) {
        final record = _tripCard(booking, requestsById[booking['tripRequestId']?.toString()], booking: true);
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

  Map<String, dynamic> _tripCard(Map<String, dynamic> record, Map<String, dynamic>? request, {required bool booking}) {
    final status = _status(record['status'], booking: booking);
    final items = record['bookingItems'];
    final tourNames = items is List ? items.whereType<Map>().map((item) => item['tourName']).whereType<String>().toList() : <String>[];
    final title = request?['destinationName']?.toString() ??
        (tourNames.isNotEmpty ? tourNames.join(', ') : booking ? 'Booking ${record['bookingReference'] ?? record['id']}' : 'Trip request #${record['id']}');
    final start = DateTime.tryParse(request?['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(request?['endDate']?.toString() ?? '');
    final created = DateTime.tryParse(record['createdAt']?.toString() ?? '');
    final dates = start != null && end != null
        ? '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}'
        : created != null ? 'Created ${DateFormat.yMMMd().format(created)}' : 'Dates unavailable';
    final amount = booking ? record['totalCost'] : record['budgetCeiling'];
    final currency = record['currency']?.toString() ?? '';
    return {
      ...record,
      'isBooking': booking,
      'source': record,
      'title': title,
      'dates': dates,
      'year': (start ?? created)?.year.toString(),
      'priceLabel': amount is num ? '${booking ? '' : 'Budget '}$currency ${NumberFormat('#,##0.##').format(amount)}'.trim() : 'Cost unavailable',
      'status': status,
      'statusColor': status == 'Cancelled' || status == 'Rejected' || status == 'Failed'
          ? const Color(0xFFDC2626) : status == 'Confirmed' || status == 'Completed'
          ? const Color(0xFF267A55) : const Color(0xFFB36A16),
      'image': AppDestinations.getImageForDestination(title),
    };
  }

  bool _inTab(Map<String, dynamic> trip, String tab) {
    final status = trip['status'];
    if (tab == 'Completed') return status == 'Completed';
    if (tab == 'Cancelled') return status == 'Cancelled';
    return status == 'Planning' || status == 'AwaitingApproval' || status == 'Confirmed';
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
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Trips')),
        body: ErrorMessage(message: _error!, onRetry: _loadData),
      );
    }
    final currentList = _trips.where((trip) => _inTab(trip, _activeTab)).toList();
    final filteredList = currentList.where((trip) => _selectedYear == 'All years' || trip['year'] == _selectedYear).toList();
    final upcomingCount = _trips.where((trip) => _inTab(trip, 'Upcoming')).length;
    final completedCount = _trips.where((trip) => _inTab(trip, 'Completed')).length;
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
                  Column(
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
                      ),
                    ],
                  ),
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
                      border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFEAF2EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_month_outlined,
                            color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
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
                          color: isDark ? Colors.white70 : AppColors.figmaDarkGreen,
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
                  border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                ),
                child: Row(
                  children: [
                    _buildTabItem('Upcoming'),
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
                  Text(
                    '$upcomingCount upcoming · $completedCount completed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
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
                      ...(_trips.map((trip) => trip['year']).whereType<String>().toSet().toList()..sort((a, b) => b.compareTo(a)))
                          .map((year) => PopupMenuItem(value: year, child: Text(year))),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Trip Cards ──
              if (filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
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
                          color: const Color(0xFF10291F).withValues(alpha: 0.08),
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
                                color: const Color(0xFF08271E)
                                    .withValues(alpha: 0.18),
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
                                  Column(
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
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        trip['dates'] as String,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9,
                                          color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6E7772),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    trip['priceLabel'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
                                    ),
                                  ),
                                ],
                              ),
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
                                                ? {'itineraryId': trip['itineraryId']}
                                                : {'tripRequestId': trip['id']},
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF123F32),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
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
                                        onPressed: trip['isBooking'] != true ? null : () {
                                          Navigator.pushNamed(
                                            context,
                                            '/booking-status',
                                            arguments: trip['source'],
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: Color(0xFFE4E7E2),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          'Manage Pass',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF123F32),
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
}
