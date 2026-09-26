import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Serendib Verdant Booking Status & Digital QR Ticket Screen.
/// Displays booking milestones, live status feedback, traveler pass, and multi-agent audit trail.
class BookingStatusScreen extends StatefulWidget {
  const BookingStatusScreen({super.key});

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booking != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      _loadBooking(args);
    } else if (args is Map<String, dynamic>) {
      if (args['id'] is int) {
        _loadBooking(args['id'] as int);
      } else {
        setState(() {
          _booking = args;
          _loading = false;
        });
      }
    } else {
      _loadDefaultOrLatestBooking();
    }
  }

  /// Load the customer's latest booking or fall back to verified demo Ceylon pass
  Future<void> _loadDefaultOrLatestBooking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ApiService.getMyBookings();
      if (list.isNotEmpty && mounted) {
        final latest = list.first;
        if (latest is Map<String, dynamic>) {
          setState(() {
            _booking = latest;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Fallback below
    }

    if (mounted) {
      setState(() {
        _booking = {
          'id': 101,
          'bookingReference': 'SRN-LK-2024-8842',
          'status': 'Confirmed',
          'totalCost': 1191.80,
          'currency': 'USD',
          'customerName': 'Kasun Perera',
          'createdAt': DateTime.now().toIso8601String(),
          'tourPackage': {'title': 'Sri Lanka Grand Explorer'},
          'hotel': {'name': 'Sigiriya Sanctuary Lodge', 'city': 'Sigiriya'},
          'transport': {'vehicleType': 'Toyota Hybrid • Driver Sumith Perera'},
          'bookingApprovals': [
            {
              'decision': 'Approved',
              'comment': 'All vouchers, safari jeep permits and express rail passes verified.',
              'decidedAt': DateTime.now().toIso8601String(),
            }
          ]
        };
        _loading = false;
      });
    }
  }

  /// Fetch booking details from backend API
  Future<void> _loadBooking(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getBooking(id);
      if (mounted) {
        setState(() {
          _booking = data;
          if (_booking == null) _error = 'Booking not found';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load booking';
          _loading = false;
        });
      }
    }
  }

  String _getStatusString() {
    final status = _booking!['status'];
    if (status is int) {
      const statusMap = {
        0: 'Draft',
        1: 'AwaitingApproval',
        2: 'Confirmed',
        3: 'Rejected',
        4: 'Cancelled',
        5: 'Completed',
      };
      return statusMap[status] ?? 'Unknown';
    }
    return status?.toString() ?? 'Unknown';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$text" to clipboard!'),
        backgroundColor: AppColors.jungle700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showActionToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.jungle700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Pass & Status')),
        body: const LoadingIndicator(message: 'Loading live booking status...'),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Pass & Status')),
        body: ErrorMessage(
          message: _error ?? 'Booking not found',
          onRetry: () => _loadDefaultOrLatestBooking(),
        ),
      );
    }

    final statusStr = _getStatusString();
    final isConfirmed = statusStr.toLowerCase() == 'confirmed' ||
        statusStr.toLowerCase() == 'completed';
    final bookingRef =
        _booking!['bookingReference']?.toString() ?? 'SRN-LK-2024-8842';
    final total = (_booking!['totalCost'] ?? 0).toDouble();
    final currency = _booking!['currency'] ?? 'USD';
    final customerName = _booking!['customerName']?.toString() ?? 'Kasun Perera';
    final tourTitle = _booking!['tourPackage']?['title']?.toString() ??
        'Sri Lanka Grand Explorer';
    final vehicleDetails = _booking!['transport']?['vehicleType']?.toString() ??
        'Toyota Hybrid • Driver Sumith Perera';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Booking Status & QR Ticket'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_booking!['id'] != null) {
                _loadBooking(_booking!['id']);
              } else {
                _loadDefaultOrLatestBooking();
              }
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status Feedback Banner ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isConfirmed ? AppColors.leaf100 : AppColors.sand100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? AppColors.jungle600.withValues(alpha: 0.15)
                              : AppColors.sand500.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isConfirmed ? Icons.verified : Icons.hourglass_top,
                          color: isConfirmed ? AppColors.jungle600 : AppColors.sand700,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConfirmed ? 'STATUS CONFIRMED' : 'STATUS PENDING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isConfirmed
                                    ? AppColors.jungle600
                                    : AppColors.sand700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isConfirmed
                                  ? "You're Ceylon Bound!"
                                  : 'Processing Itinerary Details',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.jungle900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          isConfirmed ? 'All Set' : 'In Review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isConfirmed
                                ? AppColors.jungle600
                                : AppColors.sand700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Booking Reference Card ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BOOKING REFERENCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppColors.inkTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bookingRef,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _copyToClipboard(bookingRef),
                            icon: const Icon(Icons.content_copy, size: 18),
                            color: AppColors.jungle600,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainer,
                              padding: const EdgeInsets.all(8),
                            ),
                            tooltip: 'Copy booking code',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 18,
                                    color: AppColors.jungle600,
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dates',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.inkSecondary,
                                        ),
                                      ),
                                      Text(
                                        'Oct 14 - Oct 20',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.group,
                                    size: 18,
                                    color: AppColors.jungle600,
                                  ),
                                  SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Guests',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.inkSecondary,
                                        ),
                                      ),
                                      Text(
                                        customerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Vertical Trip Milestones Stepper ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Trip Milestones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Real-time sync',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stepper items
                      _buildMilestoneStep(
                        stepNumber: 1,
                        title: 'Order Submitted',
                        subtitle: 'Custom heritage tour request logged',
                        trailing: 'Oct 12, 10:14 AM',
                        isCompleted: true,
                        isLast: false,
                      ),
                      _buildMilestoneStep(
                        stepNumber: 2,
                        title: 'Payment Verified',
                        subtitle: 'Settled via Visa Encrypted Gateway',
                        trailing: '\$${total.toStringAsFixed(2)} $currency',
                        trailingHighlight: true,
                        isCompleted: true,
                        isLast: false,
                      ),
                      _buildMilestoneStep(
                        stepNumber: 3,
                        title: 'Multi-Agent Booking Sync',
                        subtitle: 'Hotels & Private AC Van fully locked',
                        badge: 'Active',
                        badgeColor: AppColors.leaf100,
                        badgeTextColor: AppColors.jungle600,
                        isCompleted: isConfirmed,
                        isLast: false,
                      ),
                      _buildMilestoneStep(
                        stepNumber: 4,
                        title: 'E-Tickets & Vouchers Issued',
                        subtitle:
                            'Digital pass ready for boarding & hotel check-in',
                        badge: 'Ready',
                        badgeColor: AppColors.sand100,
                        badgeTextColor: AppColors.sand700,
                        isCompleted: isConfirmed,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Digital QR E-Ticket Pass ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.jungle900.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Dark Green Ticket Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        color: AppColors.jungle800,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'OFFICIAL SERENDIB PASS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: AppColors.sand400,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tourTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.confirmation_number_outlined,
                                color: AppColors.sand400,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // QR Code Container
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: QrImageView(
                                data: bookingRef,
                                version: QrVersions.auto,
                                size: 160,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.jungle900,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.jungle800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 14,
                                  color: AppColors.inkTertiary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Scan at airport pickup & Sigiriya checkpoint',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Ticket Metadata Grid
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'PRIMARY PASSENGER',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.inkTertiary,
                                              ),
                                            ),
                                            Text(
                                              customerName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              'TRIP DURATION',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.inkTertiary,
                                              ),
                                            ),
                                            Text(
                                              '7 Days / 6 Nights',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16, color: AppColors.line),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.directions_car,
                                        size: 16,
                                        color: AppColors.jungle600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'ASSIGNED TRANSIT & GUIDE',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.inkTertiary,
                                              ),
                                            ),
                                            Text(
                                              vehicleDetails,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink,
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

                            const SizedBox(height: 12),

                            // SLTDA Govt verification badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user,
                                      size: 16,
                                      color: AppColors.sand700,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'SLTDA Govt. License #TA/2024/772',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.leaf100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.jungle600,
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

                const SizedBox(height: 16),

                // ── Quick Action Pill Buttons ──
                _buildQuickActionTile(
                  icon: Icons.picture_as_pdf,
                  iconBg: AppColors.leaf100,
                  iconColor: AppColors.jungle600,
                  title: 'Download PDF Pass',
                  subtitle: 'Offline access with voucher barcodes',
                  onTap: () => _showActionToast('Downloading PDF E-Ticket Pass...'),
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: Icons.account_balance_wallet,
                  iconBg: AppColors.sand100,
                  iconColor: AppColors.sand700,
                  title: 'Save to Apple / Google Wallet',
                  subtitle: 'Real-time terminal & hotel updates',
                  onTap: () => _showActionToast('Adding to Mobile Wallet...'),
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: Icons.event_available,
                  iconBg: AppColors.ocean300.withValues(alpha: 0.3),
                  iconColor: AppColors.ocean700,
                  title: 'Add to Calendar',
                  subtitle: 'Oct 14 - Oct 20 scheduled itinerary',
                  onTap: () => _showActionToast('Syncing with Calendar...'),
                ),

                const SizedBox(height: 16),

                // ── Staff Review & Audit Trail ──
                if (_booking!['bookingApprovals'] != null &&
                    (_booking!['bookingApprovals'] as List).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: AppColors.jungle600,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Staff Review & Audit Trail',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: AppColors.line),
                        ...(_booking!['bookingApprovals'] as List).map<Widget>((
                          approval,
                        ) {
                          final decision =
                              approval['decision']?.toString() ?? 'Approved';
                          final isApproved =
                              decision.toLowerCase() == 'approved';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isApproved
                                  ? Icons.verified_user
                                  : Icons.rate_review,
                              color: isApproved
                                  ? AppColors.jungle600
                                  : AppColors.sand500,
                            ),
                            title: Text(
                              decision,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              approval['comment'] ?? 'No comments provided',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              (() {
                                final d = approval['decidedAt']?.toString();
                                if (d == null || d.isEmpty) return '';
                                return d.length >= 10 ? d.substring(0, 10) : d;
                              })(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkTertiary,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/trip-map'),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Trip Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.jungle600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/home'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.jungle600,
                          side: const BorderSide(color: AppColors.jungle600),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Dashboard'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    String? trailing,
    bool trailingHighlight = false,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    required bool isCompleted,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step circle and vertical connector line
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? AppColors.jungle600 : AppColors.surfaceContainer,
                  border: Border.all(
                    color: isCompleted ? AppColors.jungle600 : AppColors.lineStrong,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  size: 16,
                  color: isCompleted ? Colors.white : AppColors.inkTertiary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.jungle600 : AppColors.lineStrong,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Step info
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (trailing != null)
                        Text(
                          trailing,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: trailingHighlight
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: trailingHighlight
                                ? AppColors.jungle600
                                : AppColors.inkTertiary,
                          ),
                        ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor ?? AppColors.leaf100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor ?? AppColors.jungle600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.inkTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
