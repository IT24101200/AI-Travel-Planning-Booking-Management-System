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

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _trips = [];
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  bool _handledInitialArgs = false;
  int? _pendingOpenTripId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handledInitialArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args['initialTab'] != null) {
          final idx = args['initialTab'] as int;
          if (idx >= 0 && idx < 2) _tabController.index = idx;
        }
        if (args['openTripId'] != null) {
          _pendingOpenTripId = args['openTripId'] is int
              ? args['openTripId']
              : int.tryParse(args['openTripId'].toString());
        }
      } else if (args is int && args >= 0 && args < 2) {
        _tabController.index = args;
      }
      _handledInitialArgs = true;
    }
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
          // If no bookings yet but has trip requests, auto-switch to AI Requests tab
          if (_bookings.isEmpty && _trips.isNotEmpty && _tabController.index == 0) {
            _tabController.index = 1;
          }
        });

        // If there was a requested trip to open
        if (_pendingOpenTripId != null) {
          final target = _trips.firstWhere(
            (t) => t['id'] == _pendingOpenTripId,
            orElse: () => null,
          );
          _pendingOpenTripId = null;
          if (target != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showAgentProgressModal(context, target);
            });
          }
        }
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
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
                        message:
                            'No commercial bookings yet.\nOnce an itinerary is approved, tickets appear here.',
                        actionLabel: 'Plan a New Trip',
                        onAction: () =>
                            Navigator.pushNamed(context, '/trip-request'),
                      )
                    : RefreshIndicator(
                        color: AppColors.jungle600,
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _bookings.length,
                          itemBuilder: (context, index) =>
                              _buildBookingCard(_bookings[index]),
                        ),
                      ),

                // ── Trip Requests Tab ──
                _trips.isEmpty
                    ? EmptyState(
                        icon: Icons.explore_outlined,
                        message:
                            'No active AI trip requests found.\nSubmit a prompt to start planning.',
                        actionLabel: 'Create Trip Request',
                        onAction: () =>
                            Navigator.pushNamed(context, '/trip-request'),
                      )
                    : RefreshIndicator(
                        color: AppColors.jungle600,
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _trips.length,
                          itemBuilder: (context, index) =>
                              _buildTripCard(_trips[index]),
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
        5: 'Completed',
      };
      status = statusMap[booking['status']] ?? 'Unknown';
    }

    final total = (booking['totalCost'] ?? 0).toDouble();
    final currency = booking['currency'] ?? 'USD';
    final ref = booking['bookingReference'] ?? 'REF-#${booking['id']}';
    final isConfirmed =
        status.toLowerCase() == 'confirmed' ||
        status.toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(
          context,
          '/booking-status',
          arguments: booking['id'],
        ),
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
                    child: const Icon(
                      Icons.qr_code_2,
                      color: AppColors.jungle600,
                      size: 24,
                    ),
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
                          (() {
                            final c = booking['createdAt']?.toString();
                            if (c == null || c.isEmpty) return 'Recent';
                            return c.length >= 10 ? c.substring(0, 10) : c;
                          })(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink3,
                          ),
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
                      const Text(
                        'Total Commercial Cost',
                        style: TextStyle(fontSize: 11, color: AppColors.ink3),
                      ),
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
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.jungle600,
                        ),
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

  /// Open bottom sheet showing real-time AI Agent progress and audit logs
  void _showAgentProgressModal(BuildContext context, Map<String, dynamic> trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AgentProgressBottomSheet(initialTrip: trip),
    );
  }

  /// Build a trip request card with clear AI agent progress indicator
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAgentProgressModal(context, trip),
        child: Column(
          children: [
            // Top Image Bar
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
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
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
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
                      const Icon(
                        Icons.date_range_outlined,
                        size: 16,
                        color: AppColors.jungle600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (() {
                          final s = trip['startDate']?.toString();
                          final e = trip['endDate']?.toString();
                          final sStr = s != null && s.length >= 10 ? s.substring(0, 10) : (s ?? '');
                          final eStr = e != null && e.length >= 10 ? e.substring(0, 10) : (e ?? '');
                          return '$sStr  →  $eStr';
                        })(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.ink2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_outlined,
                        size: 16,
                        color: AppColors.jungle600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$travellers Guests',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.ink2,
                        ),
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
            // Bottom Action Bar to view Agent Progress
            const Divider(height: 1, color: AppColors.line),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.mist.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.sand100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.jungle800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Agents Progress & Logs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.jungle700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sand600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.sand600,
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

/// Bottom sheet displaying the 4 AI Agents' live execution progress and reasoning logs
class _AgentProgressBottomSheet extends StatefulWidget {
  final Map<String, dynamic> initialTrip;

  const _AgentProgressBottomSheet({required this.initialTrip});

  @override
  State<_AgentProgressBottomSheet> createState() => _AgentProgressBottomSheetState();
}

class _AgentProgressBottomSheetState extends State<_AgentProgressBottomSheet> {
  late Map<String, dynamic> _trip;
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _trip = Map<String, dynamic>.from(widget.initialTrip);
    _fetchLogs();
  }

  /// Fetch execution logs and fresh trip request status
  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final tripId = _trip['id'] is int
        ? _trip['id'] as int
        : int.tryParse(_trip['id'].toString()) ?? 0;

    if (tripId == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final logs = await ApiService.getAgentLogs(tripId);
      final updated = await ApiService.getTripRequest(tripId);
      if (mounted) {
        setState(() {
          _logs = logs;
          if (updated != null) {
            _trip = updated;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Determines the status of an agent given its name keyword
  String _getAgentStatus(String keyword) {
    final status = (_trip['status'] ?? '').toString().toLowerCase();
    if (status == 'awaitingapproval' || status == 'planned' || status == 'completed') {
      return 'Completed';
    }

    final agentLogs = _logs.where((l) {
      final name = (l['agentName'] ?? '').toString().toLowerCase();
      return name.contains(keyword.toLowerCase());
    }).toList();

    if (agentLogs.isEmpty) {
      if (status == 'planning' && keyword == 'coordinator') {
        return 'Running';
      }
      return 'Waiting';
    }

    if (agentLogs.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'failed')) {
      return 'Failed';
    }
    if (agentLogs.any((l) => (l['status'] ?? '').toString().toLowerCase() == 'success')) {
      return 'Completed';
    }
    return 'Running';
  }

  Widget _buildAgentStepCard({
    required IconData icon,
    required String name,
    required String role,
    required String status,
  }) {
    Color iconColor;
    Color bgColor;
    Widget statusWidget;

    switch (status) {
      case 'Completed':
        iconColor = AppColors.jungle600;
        bgColor = AppColors.leaf50;
        statusWidget = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppColors.jungle600),
            SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.jungle600,
              ),
            ),
          ],
        );
        break;
      case 'Running':
        iconColor = AppColors.sand600;
        bgColor = AppColors.sand100.withValues(alpha: 0.5);
        statusWidget = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sand600),
            ),
            SizedBox(width: 4),
            Text(
              'Working...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sand600,
              ),
            ),
          ],
        );
        break;
      case 'Failed':
        iconColor = AppColors.coral500;
        bgColor = AppColors.coral500.withValues(alpha: 0.1);
        statusWidget = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 14, color: AppColors.coral500),
            SizedBox(width: 4),
            Text(
              'Failed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.coral500,
              ),
            ),
          ],
        );
        break;
      default:
        iconColor = AppColors.ink3;
        bgColor = AppColors.mist;
        statusWidget = const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 14, color: AppColors.ink3),
            SizedBox(width: 4),
            Text(
              'Queued',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.ink3,
              ),
            ),
          ],
        );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          statusWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destName = _trip['destinationName'] ?? 'Sri Lanka';
    final status = _trip['status'] ?? 'Planning';
    final planJson = _trip['planJson']?.toString();
    final hasPlan = planJson != null && planJson.isNotEmpty && planJson != '{}';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top Drag Indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.leaf50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.jungle600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Request #${_trip['id']} • Multi-Agent AI Planning',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: status),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh Logs',
                      onPressed: _fetchLogs,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.line),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── 4 AI Agents Pipeline ──
                    const Text(
                      'AI Multi-Agent Pipeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Four specialized agents collaborate autonomously to generate your itinerary.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildAgentStepCard(
                      icon: Icons.navigation_outlined,
                      name: 'Coordinator Agent',
                      role: 'Analyzes trip requirements & delegates tasks',
                      status: _getAgentStatus('coordinator'),
                    ),
                    _buildAgentStepCard(
                      icon: Icons.map_outlined,
                      name: 'Itinerary Agent',
                      role: 'Designs day-by-day sightseeing and activities',
                      status: _getAgentStatus('itinerary'),
                    ),
                    _buildAgentStepCard(
                      icon: Icons.hotel_outlined,
                      name: 'Booking Agent',
                      role: 'Identifies accommodation and transport options',
                      status: _getAgentStatus('booking'),
                    ),
                    _buildAgentStepCard(
                      icon: Icons.verified_outlined,
                      name: 'Validation Agent',
                      role: 'Verifies budget ceiling, timings & feasibility',
                      status: _getAgentStatus('validation'),
                    ),

                    const SizedBox(height: 16),

                    // ── Plan Ready Banner ──
                    if (hasPlan || status.toString().toLowerCase() == 'awaitingapproval') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.leaf50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.jungle600.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppColors.jungle600, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'AI Travel Itinerary Generated!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.jungle800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'The multi-agent system has finished drafting your schedule, hotel reservations, and transit.',
                              style: TextStyle(fontSize: 12, color: AppColors.ink2),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, '/itinerary');
                                },
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('View Full Generated Itinerary'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.jungle600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Live Audit Logs ──
                    Row(
                      children: [
                        const Text(
                          'Agent Execution Logs',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sand100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_logs.length} steps',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.jungle800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.jungle600),
                          ),
                        ),
                      )
                    else if (_logs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No agent execution logs recorded yet. If the plan was just submitted, the agents are running in the background. Tap refresh in a few seconds.',
                          style: TextStyle(fontSize: 12, color: AppColors.ink3),
                        ),
                      )
                    else
                      ...List.generate(_logs.length, (i) {
                        final log = _logs[i];
                        final agentName = log['agentName'] ?? 'Agent';
                        final stepName = log['stepName'] ?? 'Step';
                        final logStatus = log['status'] ?? 'Success';
                        final output = log['output']?.toString() ?? '';
                        final timeStr = (() {
                          final ts = log['timestamp']?.toString();
                          if (ts != null && ts.length >= 19) {
                            return ts.substring(11, 19);
                          }
                          return '';
                        })();

                        Color badgeColor = AppColors.jungle600;
                        if (agentName.toString().toLowerCase().contains('coordinator')) {
                          badgeColor = AppColors.ocean500;
                        } else if (agentName.toString().toLowerCase().contains('itinerary')) {
                          badgeColor = AppColors.jungle600;
                        } else if (agentName.toString().toLowerCase().contains('booking')) {
                          badgeColor = AppColors.sand600;
                        } else if (agentName.toString().toLowerCase().contains('validation')) {
                          badgeColor = Colors.purple;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      agentName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      stepName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty) ...[
                                    Text(
                                      '$logStatus · $timeStr',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.ink3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (output.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  output,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.ink2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

