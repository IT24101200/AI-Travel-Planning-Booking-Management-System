import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Trip history screen showing past trip requests & bookings with status badges and destination imagery.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _trips = [];
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load trip requests and bookings from backend
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await ApiService.getMyTripRequests();
      final bookings = await ApiService.getMyBookings();
      if (mounted) {
        setState(() {
          _trips = trips;
          _bookings = bookings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load trip history';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journeys & Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.sand400,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.leaf200,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long, size: 18),
              text: 'Bookings (${_bookings.length})',
            ),
            Tab(
              icon: const Icon(Icons.auto_awesome, size: 18),
              text: 'AI Requests (${_trips.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Retrieving your travel history...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadData)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Bookings Tab ──
                    _bookings.isEmpty
                        ? EmptyState(
                            icon: Icons.confirmation_number_outlined,
                            message: 'No commercial bookings yet.\nOnce an itinerary is approved, tickets appear here.',
                            actionLabel: 'Plan a New Trip',
                            onAction: () => Navigator.pushNamed(context, '/trip-request'),
                          )
                        : RefreshIndicator(
                            color: AppColors.jungle600,
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _bookings.length,
                              itemBuilder: (context, index) => _buildBookingCard(_bookings[index]),
                            ),
                          ),

                    // ── Trip Requests Tab ──
                    _trips.isEmpty
                        ? EmptyState(
                            icon: Icons.explore_outlined,
                            message: 'No active AI trip requests found.\nSubmit a prompt to start planning.',
                            actionLabel: 'Create Trip Request',
                            onAction: () => Navigator.pushNamed(context, '/trip-request'),
                          )
                        : RefreshIndicator(
                            color: AppColors.jungle600,
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _trips.length,
                              itemBuilder: (context, index) => _buildTripCard(_trips[index]),
                            ),
                          ),
                  ],
                ),
    );
  }

  /// Build an image-rich booking card
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    String status = booking['status']?.toString() ?? 'Unknown';
    if (booking['status'] is int) {
      const statusMap = {
        0: 'Draft',
        1: 'AwaitingApproval',
        2: 'Confirmed',
        3: 'Rejected',
        4: 'Cancelled',
        5: 'Completed'
      };
      status = statusMap[booking['status']] ?? 'Unknown';
    }

    final total = (booking['totalCost'] ?? 0).toDouble();
    final currency = booking['currency'] ?? 'USD';
    final ref = booking['bookingReference'] ?? 'REF-#${booking['id']}';
    final isConfirmed = status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/booking-status', arguments: booking['id']),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.leaf50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_2, color: AppColors.jungle600, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          booking['createdAt']?.toString().substring(0, 10) ?? 'Recent',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: status),
                ],
              ),
              const Divider(height: 20, color: AppColors.line),
              // Pricing and Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Commercial Cost', style: TextStyle(fontSize: 11, color: AppColors.ink3)),
                      Text(
                        '\$${total.toStringAsFixed(2)} $currency',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.jungle600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (isConfirmed) ...[
                        const Icon(Icons.verified, size: 16, color: AppColors.jungle600),
                        const SizedBox(width: 4),
                        const Text(
                          'Ticket Ready',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.jungle600,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'View Status →',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ocean500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a trip request card
  Widget _buildTripCard(Map<String, dynamic> trip) {
    final destName = trip['destinationName'] ?? 'Sri Lanka Discovery';
    final imageUrl = AppDestinations.getImageForDestination(destName);
    final status = trip['status'] ?? 'Planning';
    final travellers = trip['travellerCount'] ?? 1;
    final budget = (trip['budgetCeiling'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/itinerary'),
        child: Column(
          children: [
            // Top Image Bar
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AppNetworkImage(
                    imageUrl: imageUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: StatusBadge(status: status),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Text(
                    destName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            // Info Row
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range_outlined, size: 16, color: AppColors.jungle600),
                      const SizedBox(width: 6),
                      Text(
                        '${trip['startDate']?.toString().substring(0, 10) ?? ''}  →  ${trip['endDate']?.toString().substring(0, 10) ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.ink2, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.jungle600),
                      const SizedBox(width: 6),
                      Text(
                        '$travellers Guests',
                        style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                      ),
                      const Spacer(),
                      Text(
                        'Budget: \$${budget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.jungle700,
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
}
