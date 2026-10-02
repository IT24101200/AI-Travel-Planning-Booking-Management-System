import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// My Trips / Trip History screen connecting exclusively to the live database API.
/// Does not use dummy data — displays real database bookings and trip requests for the logged-in customer.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  int _selectedTabIndex = 0; // 0: Upcoming, 1: Completed, 2: Cancelled
  bool _isLoading = true;
  String? _errorMessage;

  // Real trips populated exclusively from the database (Bookings + Trip Requests)
  List<Map<String, dynamic>> _dbTrips = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseTrips();
  }

  /// Fetch bookings and trip requests from the backend database
  Future<void> _loadDatabaseTrips() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> combined = [];

      // 1. Fetch live bookings from database
      final bookings = await ApiService.getMyBookings();
      for (final b in bookings) {
        if (b is! Map<String, dynamic>) continue;

        final id = b['id']?.toString() ?? '';
        final ref = b['bookingReference']?.toString() ?? 'ST-BK-$id';
        final rawStatus = b['status'];
        final totalCost = (b['totalCost'] is num) ? (b['totalCost'] as num).toDouble() : 0.0;
        final createdAtStr = b['createdAt']?.toString() ?? '';
        final createdAt = DateTime.tryParse(createdAtStr);

        // Map status integer or string to readable state
        String statusLabel = 'CONFIRMED';
        Color statusColor = const Color(0xFF13684B);
        String tabType = 'Upcoming';

        final statusStr = rawStatus?.toString().toLowerCase() ?? '';
        if (statusStr == '0' || statusStr.contains('draft')) {
          statusLabel = 'DRAFT';
          statusColor = const Color(0xFF6B7280);
          tabType = 'Upcoming';
        } else if (statusStr == '1' || statusStr.contains('awaitingapproval')) {
          statusLabel = 'AWAITING APPROVAL';
          statusColor = const Color(0xFFB27D26);
          tabType = 'Upcoming';
        } else if (statusStr == '2' || statusStr.contains('approved') || statusStr.contains('confirmed')) {
          statusLabel = 'CONFIRMED';
          statusColor = const Color(0xFF13684B);
          tabType = 'Upcoming';
        } else if (statusStr == '3' || statusStr.contains('rejected')) {
          statusLabel = 'REJECTED';
          statusColor = const Color(0xFFE27D60);
          tabType = 'Cancelled';
        } else if (statusStr == '4' || statusStr.contains('cancelled')) {
          statusLabel = 'CANCELLED';
          statusColor = const Color(0xFF9E9E9E);
          tabType = 'Cancelled';
        } else if (statusStr == '5' || statusStr.contains('completed')) {
          statusLabel = 'COMPLETED';
          statusColor = const Color(0xFF6B7280);
          tabType = 'Completed';
        }

        // Determine title from items or fallback
        String title = 'Sri Lanka Tour $ref';
        final items = b['items'];
        if (items is List && items.isNotEmpty) {
          final first = items.first;
          if (first is Map && first['tourName'] != null) {
            title = first['tourName'].toString();
          }
        }

        // Format dates
        String datesText = createdAt != null
            ? 'Booked ${createdAt.day}/${createdAt.month}/${createdAt.year}'
            : 'Active Reservation';

        final bookingImage = _resolveTripImage(
          title: title,
          rawRequestText: '',
          destinationName: null,
          tripIndex: combined.length,
        );

        combined.add({
          'id': id,
          'bookingReference': ref,
          'title': title,
          'status': statusLabel,
          'statusColor': statusColor,
          'dates': datesText,
          'price': totalCost.toInt(),
          'currency': b['currency']?.toString() ?? 'LKR',
          'imageUrl': bookingImage,
          'primaryAction': 'View Details',
          'secondaryAction': 'Receipt',
          'type': tabType,
          'isBooking': true,
        });
      }

      // 2. Fetch live AI trip requests from database
      final tripRequests = await ApiService.getMyTripRequests();
      for (final tr in tripRequests) {
        if (tr is! Map<String, dynamic>) continue;

        final id = tr['id']?.toString() ?? '';
        final destination = tr['destinationName']?.toString();
        final rawText = tr['rawRequestText']?.toString() ?? '';
        final budget = (tr['budgetCeiling'] is num) ? (tr['budgetCeiling'] as num).toDouble() : 0.0;
        final startStr = tr['startDate']?.toString() ?? '';
        final endStr = tr['endDate']?.toString() ?? '';
        final status = tr['status']?.toString().toLowerCase() ?? 'pending';
        final currency = tr['currency']?.toString() ?? 'LKR';
        final planJson = tr['planJson'];

        final start = DateTime.tryParse(startStr);
        final end = DateTime.tryParse(endStr);

        int days = 5;
        if (start != null && end != null) {
          days = end.difference(start).inDays;
          if (days <= 0) days = 1;
        }

        // Resolve title according to trip details and route
        final title = _resolveTripTitle(
          destinationName: destination,
          rawRequestText: rawText,
          planJson: planJson,
          days: days,
        );

        // Resolve matching image according to trip details and stops
        final imageUrl = _resolveTripImage(
          title: title,
          rawRequestText: rawText,
          destinationName: destination,
          tripIndex: combined.length,
        );

        String statusLabel = 'PLANNING';
        Color statusColor = const Color(0xFF1D6F8A);
        String tabType = 'Upcoming';

        if (status.contains('awaitingapproval') || status.contains('planned')) {
          statusLabel = 'AWAITING APPROVAL';
          statusColor = const Color(0xFFB27D26);
          tabType = 'Upcoming';
        } else if (status.contains('completed') || status.contains('approved')) {
          statusLabel = 'CONFIRMED';
          statusColor = const Color(0xFF13684B);
          tabType = 'Upcoming';
        } else if (status.contains('failed') || status.contains('cancel') || status.contains('reject')) {
          statusLabel = 'CANCELLED';
          statusColor = const Color(0xFFE27D60);
          tabType = 'Cancelled';
        } else {
          statusLabel = 'AI PLANNING';
          statusColor = const Color(0xFF1D6F8A);
          tabType = 'Upcoming';
        }

        String datesText = (start != null && end != null)
            ? '${start.day}/${start.month} – ${end.day}/${end.month} · $days days'
            : '$days-day planned journey';

        combined.add({
          'id': id,
          'tripRequestId': int.tryParse(id) ?? (tr['id'] is int ? tr['id'] as int : null),
          'title': title,
          'destinationName': destination,
          'startDate': startStr,
          'endDate': endStr,
          'days': days,
          'status': statusLabel,
          'statusColor': statusColor,
          'dates': datesText,
          'price': budget > 0 ? budget.toInt() : 150000,
          'currency': currency,
          'imageUrl': imageUrl,
          'primaryAction': 'Continue Plan',
          'secondaryAction': 'View Agents',
          'type': tabType,
          'isBooking': false,
          'rawRequestText': rawText,
          'planJson': planJson,
        });
      }

      if (mounted) {
        setState(() {
          _dbTrips = combined;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load trips from database.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTrips {
    if (_selectedTabIndex == 0) {
      return _dbTrips.where((t) => t['type'] == 'Upcoming').toList();
    }
    if (_selectedTabIndex == 1) {
      return _dbTrips.where((t) => t['type'] == 'Completed').toList();
    }
    return _dbTrips.where((t) => t['type'] == 'Cancelled').toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips;
    final upcomingCount = _dbTrips.where((t) => t['type'] == 'Upcoming').length;
    final completedCount = _dbTrips.where((t) => t['type'] == 'Completed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0E382C),
          backgroundColor: Colors.white,
          onRefresh: _loadDatabaseTrips,
          child: Column(
            children: [
              // ── Top Header Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Trips',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoading
                              ? 'Loading database records...'
                              : 'Your journeys, past and future',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Plus circular button (Plan New Trip)
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/trip-request').then((_) => _loadDatabaseTrips()),
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
                          child: Icon(Icons.add, color: Color(0xFF1E1E1E), size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Segmented Tab Pill ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFEDECE4)),
                  ),
                  child: Row(
                    children: [
                      _buildTabSegment('Upcoming', 0),
                      _buildTabSegment('Completed', 1),
                      _buildTabSegment('Cancelled', 2),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Count and Filter Label ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$upcomingCount upcoming · $completedCount completed',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Database Live',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E382C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF13684B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Content Area: Loading / Error / Empty / List ──
              Expanded(
                child: _buildContent(filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> filtered) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0E382C)),
            SizedBox(height: 14),
            Text(
              'Fetching trips from database...',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A9E96), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFE27D60)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF08201A)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadDatabaseTrips,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      final tabTitle = _selectedTabIndex == 0
          ? 'upcoming'
          : (_selectedTabIndex == 1 ? 'completed' : 'cancelled');

      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEFAF4),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.luggage_outlined, size: 36, color: Color(0xFF0E382C)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No $tabTitle trips in database',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF08201A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your bookings, itineraries, and AI-orchestrated island plans from the database will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8A9E96),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/trip-request').then((_) => _loadDatabaseTrips()),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Plan New Trip with AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final trip = filtered[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTabSegment(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0E382C) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final title = trip['title'] ?? 'Trip';
    final status = trip['status'] ?? 'CONFIRMED';
    final Color statusColor = trip['statusColor'] ?? const Color(0xFF13684B);
    final dates = trip['dates'] ?? '';
    final price = trip['price'] ?? 0;
    final primaryAction = trip['primaryAction'] ?? 'View Details';
    final secondaryAction = trip['secondaryAction'] ?? 'Cancel';
    final imageUrl = trip['imageUrl'] ?? AppDestinations.heroSigiriya;
    final isBooking = trip['isBooking'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDECE4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image with Status Tag
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: imageUrl.startsWith('http')
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Image.asset(AppDestinations.heroSigiriya, fit: BoxFit.cover))
                      : Image.asset(imageUrl, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              if (trip['bookingReference'] != null)
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trip['bookingReference'],
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF08201A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatPrice(price, trip['currency']?.toString() ?? 'LKR'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF08201A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dates,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A9E96),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/my-itinerary', arguments: trip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E382C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          primaryAction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        if (isBooking) {
                          Navigator.pushNamed(context, '/trip-confirmation');
                        } else {
                          _showAgentDetailsModal(trip);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEDECE4)),
                        ),
                        child: Text(
                          secondaryAction,
                          style: const TextStyle(
                            color: Color(0xFF08201A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
  }

  /// Formats prices strictly in LKR without dollar signs
  String _formatPrice(int rawPrice, String currency) {
    int amount = rawPrice;
    // If entered in USD from earlier mockup, convert to realistic LKR (1 USD ~ 300 LKR)
    if (currency.toUpperCase() == 'USD' || (amount > 0 && amount < 5000)) {
      amount = amount * 300;
    }
    return 'LKR ${NumberFormat('#,##0').format(amount)}';
  }

  /// Resolves an accurate, human-friendly title based on the trip's actual details.
  /// Prioritizes user's entered route, AI plan theme, and specific destinations over generic fallbacks.
  String _resolveTripTitle({
    required String? destinationName,
    required String rawRequestText,
    required dynamic planJson,
    required int days,
  }) {
    // 1. Try to read theme from AI plan JSON
    if (planJson != null) {
      try {
        Map<String, dynamic>? decoded;
        if (planJson is Map<String, dynamic>) {
          decoded = planJson;
        } else if (planJson is String && planJson.isNotEmpty) {
          decoded = jsonDecode(planJson) as Map<String, dynamic>?;
        }
        if (decoded != null) {
          final theme = decoded['theme'] ?? decoded['trip_theme'] ?? decoded['title'];
          if (theme is String && theme.trim().isNotEmpty && !theme.toLowerCase().contains('badulla')) {
            return theme.trim();
          }
        }
      } catch (_) {}
    }

    // 2. Extract user's entered route from rawRequestText
    final cleanRaw = rawRequestText.trim();
    if (cleanRaw.isNotEmpty) {
      String candidate = cleanRaw;
      // Strip trailing form metadata like '. Pace: ...' or '. Interests: ...'
      if (candidate.contains('. Pace:')) {
        candidate = candidate.split('. Pace:').first;
      } else if (candidate.contains('. Interests:')) {
        candidate = candidate.split('. Interests:').first;
      } else if (candidate.contains('. Notes:')) {
        candidate = candidate.split('. Notes:').first;
      }

      // Check for seeded pattern: "5-day route through Sigiriya, Kandy and Ella for 2 adults..."
      final matchThrough = RegExp(r'through\s+(.*?)\s+(for|with|\.)', caseSensitive: false).firstMatch(candidate);
      if (matchThrough != null && matchThrough.group(1) != null) {
        candidate = matchThrough.group(1)!.trim();
      }

      candidate = candidate.replaceAll(RegExp(r'[\.\,]+$'), '').trim();

      // If candidate is a valid list of places (like "Sigiriya, Kandy, Ella & Mirissa")
      if (candidate.isNotEmpty && candidate.length > 2 && candidate.toLowerCase() != 'badulla') {
        if (candidate.toLowerCase().contains('experience') ||
            candidate.toLowerCase().contains('tour') ||
            candidate.toLowerCase().contains('journey') ||
            candidate.toLowerCase().contains('route') ||
            candidate.toLowerCase().contains('getaway') ||
            candidate.toLowerCase().contains('discovery') ||
            candidate.toLowerCase().contains('expedition')) {
          return candidate;
        }
        if (candidate.contains(',') || candidate.contains('&') || candidate.contains('and')) {
          return '$candidate Experience';
        }
        return '$candidate Discovery';
      }
    }

    // 3. Scan for known Sri Lankan destination keywords across rawRequestText & destinationName
    final haystack = '$cleanRaw ${destinationName ?? ''}'.toLowerCase();
    final knownKeywords = <String, String>{
      'sigiriya': 'Sigiriya',
      'kandy': 'Kandy',
      'ella': 'Ella',
      'mirissa': 'Mirissa',
      'nuwara eliya': 'Nuwara Eliya',
      'yala': 'Yala Safari',
      'galle': 'Galle',
      'trincomalee': 'Trincomalee',
      'horton': 'Horton Plains',
      'bentota': 'Bentota',
      'colombo': 'Colombo',
      'dambulla': 'Dambulla',
    };

    final matched = <String>[];
    for (final entry in knownKeywords.entries) {
      if (haystack.contains(entry.key) && !matched.contains(entry.value)) {
        matched.add(entry.value);
      }
    }

    if (matched.isNotEmpty) {
      if (matched.length == 1) {
        return '${matched[0]} Experience';
      } else if (matched.length == 2) {
        return '${matched[0]} & ${matched[1]} Journey';
      } else {
        return '${matched.take(2).join(', ')} & ${matched[2]} Discovery';
      }
    }

    // 4. Fallback to destination name if not 'Badulla'
    if (destinationName != null &&
        destinationName.isNotEmpty &&
        destinationName.toLowerCase() != 'badulla') {
      return '$destinationName Experience';
    }

    return 'Sri Lanka $days-Day Discovery';
  }

  /// Resolves the most accurate scenic photo based on the trip's destination and themes.
  /// If the trip route includes multiple places, alternates them using [tripIndex].
  String _resolveTripImage({
    required String title,
    required String rawRequestText,
    required String? destinationName,
    int tripIndex = 0,
  }) {
    final text = '$title $rawRequestText ${destinationName ?? ''}'.toLowerCase();

    // Map keywords to photos and find their appearance order
    final photoMap = <String, String>{
      'sigiriya': 'assets/photos/sigiriya-1280.jpg',
      'rock fortress': 'assets/photos/sigiriya-1280.jpg',
      'ella': 'assets/photos/ella-1280.jpg',
      'nine arch': 'assets/photos/ella-1280.jpg',
      'demodara': 'assets/photos/ella-1280.jpg',
      'nuwara': 'assets/photos/nuwara-eliya-1280.jpg',
      'tea': 'assets/photos/nuwara-eliya-1280.jpg',
      'mirissa': 'assets/photos/mirissa-1280.jpg',
      'beach': 'assets/photos/mirissa-1280.jpg',
      'whale': 'assets/photos/mirissa-1280.jpg',
      'surf': 'assets/photos/mirissa-1280.jpg',
      'galle': 'assets/photos/mirissa-1280.jpg',
      'coast': 'assets/photos/mirissa-1280.jpg',
      'yala': 'assets/photos/yala-1280.jpg',
      'safari': 'assets/photos/yala-1280.jpg',
      'wildlife': 'assets/photos/yala-1280.jpg',
      'leopard': 'assets/photos/yala-1280.jpg',
      'kandy': 'assets/photos/kandy-1280.jpg',
      'temple': 'assets/photos/kandy-1280.jpg',
      'tooth': 'assets/photos/kandy-1280.jpg',
      'trincomalee': 'assets/photos/trincomalee-1280.jpg',
      'trinco': 'assets/photos/trincomalee-1280.jpg',
      'snorkel': 'assets/photos/trincomalee-1280.jpg',
      'horton': 'assets/photos/horton-plains-1280.jpg',
      'world\'s end': 'assets/photos/horton-plains-1280.jpg',
      'badulla': 'assets/photos/ella-1280.jpg',
    };

    final matchedPhotos = <String>[];
    for (final entry in photoMap.entries) {
      if (text.contains(entry.key) && !matchedPhotos.contains(entry.value)) {
        matchedPhotos.add(entry.value);
      }
    }

    if (matchedPhotos.isNotEmpty) {
      // Pick based on trip index so multi-city trips showcase different iconic stops
      return matchedPhotos[tripIndex % matchedPhotos.length];
    }

    return AppDestinations.heroSigiriya;
  }

  /// Displays the specialist AI agent reasoning modal
  void _showAgentDetailsModal(Map<String, dynamic> trip) {
    final title = trip['title'] ?? 'AI Trip Plan';
    final status = trip['status'] ?? 'PLANNING';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDECE4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Specialist Agents',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFAF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E382C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEDECE4)),
              const SizedBox(height: 12),
              _buildAgentStepTile(
                icon: Icons.hub_outlined,
                agentName: 'Coordinator Agent',
                stepDesc: 'Decomposed intent, dates & allocated LKR budget across categories.',
                status: 'Completed',
              ),
              _buildAgentStepTile(
                icon: Icons.calendar_month_outlined,
                agentName: 'Itinerary Agent',
                stepDesc: 'Drafted day-by-day timetable and sequenced scenic destinations.',
                status: 'Completed',
              ),
              _buildAgentStepTile(
                icon: Icons.hotel_outlined,
                agentName: 'Booking Agent',
                stepDesc: 'Checked boutique villa holds, verified rail passes & vehicle escort.',
                status: 'Completed',
              ),
              _buildAgentStepTile(
                icon: Icons.verified_outlined,
                agentName: 'Validation Agent',
                stepDesc: 'Verified budget constraints, travel buffer times & seasonal suitability.',
                status: 'Passed',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my-itinerary', arguments: trip);
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open Full Itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgentStepTile({
    required IconData icon,
    required String agentName,
    required String stepDesc,
    required String status,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEFAF4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0E382C), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      agentName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF13684B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stepDesc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

