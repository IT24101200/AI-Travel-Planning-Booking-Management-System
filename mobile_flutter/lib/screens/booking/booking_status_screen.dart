import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Booking status screen matching Figma frame 12 · Booking Status (node 7:11041)
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
    } else if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      if (map['id'] is int && map['bookingReference'] == null) {
        _loadBooking(map['id'] as int);
      } else {
        setState(() {
          _booking = map;
          _loading = false;
        });
      }
    } else {
      _loadDefaultOrLatestBooking();
    }
  }

  String _normalizeBookingStatus(dynamic status) {
    if (status == 0 || status == '0' || status == 'Draft' || status == 'draft') return 'Draft';
    if (status == 1 || status == '1' || status == 'AwaitingApproval' || status == 'awaiting_approval') return 'AwaitingApproval';
    if (status == 2 || status == '2' || status == 'Confirmed' || status == 'confirmed') return 'Confirmed';
    if (status == 3 || status == '3' || status == 'Rejected' || status == 'rejected') return 'Rejected';
    if (status == 4 || status == '4' || status == 'Cancelled' || status == 'cancelled') return 'Cancelled';
    if (status == 5 || status == '5' || status == 'Completed' || status == 'completed') return 'Completed';
    return status?.toString() ?? 'Draft';
  }

  /// Load latest booking
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
      // Fall through to error
    }

    if (mounted) {
      setState(() {
        _booking = null;
        _error = 'No bookings found. Please plan and request a trip first.';
        _loading = false;
      });
    }
  }

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

  Future<void> _cancelBooking() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Booking Cancellation',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.figmaDarkGreen,
          ),
        ),
        content: Text(
          'To cancel this booking or request a refund, please contact your assigned travel agent at support@serendibtrails.com or call +94 11 234 5678.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.figmaDarkGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Understood'),
          ),
        ],
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

    if (_error != null && _booking == null) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Booking status',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ErrorMessage(
          message: _error!,
          onRetry: _loadDefaultOrLatestBooking,
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reference = _booking!['bookingReference'] ?? 'ST-284619';
    final total = (_booking!['totalCost'] ??
            _booking!['totalEstimatedCost'] ??
            1712)
        .toDouble();
    final tripTitle = _booking!['destination'] ?? 'Sri Lanka Discovery';
    final dates = _booking!['dates'] ?? '12–18 Oct · 2 travelers';
    final stops =
        _booking!['stops'] ?? 'Sigiriya · Kandy · Ella · Mirissa';

    final statusKey = _normalizeBookingStatus(_booking!['status']);
    final payments = _booking!['payments'];
    final isPaid = _booking!['paymentStatus'] == 'Paid' ||
        (payments is List && payments.any((payment) {
          return payment is Map &&
              payment['status']?.toString().toLowerCase() == 'paid';
        }));
    final isQrEligible =
        (statusKey == 'Confirmed' || statusKey == 'Completed') && isPaid;

    String statusBadgeText;
    Color statusBadgeColor;
    Color statusBadgeBg;
    IconData statusHeroIcon;

    switch (statusKey) {
      case 'Draft':
        statusBadgeText = 'DRAFT BOOKING';
        statusBadgeColor = const Color(0xFF6B7280);
        statusBadgeBg = const Color(0xFFF3F4F6);
        statusHeroIcon = Icons.edit_note_outlined;
        break;
      case 'AwaitingApproval':
        statusBadgeText = 'AWAITING AGENT APPROVAL';
        statusBadgeColor = const Color(0xFFD97706);
        statusBadgeBg = const Color(0xFFFEF3C7);
        statusHeroIcon = Icons.hourglass_top_outlined;
        break;
      case 'Confirmed':
        statusBadgeText = 'BOOKING CONFIRMED';
        statusBadgeColor = const Color(0xFF059669);
        statusBadgeBg = const Color(0xFFE2F4EB);
        statusHeroIcon = Icons.check_circle_outline;
        break;
      case 'Completed':
        statusBadgeText = 'TRIP COMPLETED';
        statusBadgeColor = const Color(0xFF059669);
        statusBadgeBg = const Color(0xFFE2F4EB);
        statusHeroIcon = Icons.verified_outlined;
        break;
      case 'Cancelled':
        statusBadgeText = 'BOOKING CANCELLED';
        statusBadgeColor = const Color(0xFFDC2626);
        statusBadgeBg = const Color(0xFFFEE2E2);
        statusHeroIcon = Icons.cancel_outlined;
        break;
      case 'Rejected':
        statusBadgeText = 'BOOKING REJECTED';
        statusBadgeColor = const Color(0xFFDC2626);
        statusBadgeBg = const Color(0xFFFEE2E2);
        statusHeroIcon = Icons.highlight_off_outlined;
        break;
      default:
        statusBadgeText = statusKey.toUpperCase();
        statusBadgeColor = const Color(0xFF6B7280);
        statusBadgeBg = const Color(0xFFF3F4F6);
        statusHeroIcon = Icons.info_outline;
    }

    final isDraft = statusKey == 'Draft';
    final isAwaiting = statusKey == 'AwaitingApproval';
    final isConfirmed = statusKey == 'Confirmed';
    final isCompleted = statusKey == 'Completed';

    final s1Completed = isAwaiting || isConfirmed || isCompleted;
    final s1Active = isDraft;

    final s2Completed = isConfirmed || isCompleted;
    final s2Active = isAwaiting;
    final s2Pending = isDraft;

    final s3Completed = isCompleted;
    final s3Active = isConfirmed;
    final s3Pending = isDraft || isAwaiting;

    final s4Completed = isCompleted;
    final s4Active = false;
    final s4Pending = !isCompleted;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Booking status',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reference $reference',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_horiz,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Status Hero Section ──
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusBadgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusHeroIcon,
                  color: statusBadgeColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBadgeBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusBadgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusBadgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reference,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isQrEligible
                    ? 'All services confirmed · Digital ticket ready'
                    : 'Awaiting travel desk approval · Updates in real time',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ── 4-Step Vertical Stepper Card ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      icon: s1Completed ? Icons.check : null,
                      isCompleted: s1Completed,
                      isActive: s1Active,
                      isPending: false,
                      title: 'Submitted',
                      subtitle: 'Trip request submitted',
                      time: 'Step 1',
                      showLine: true,
                      lineColor: s2Completed || s2Active ? const Color(0xFF059669) : const Color(0xFFD1D5DB),
                    ),
                    _buildStepRow(
                      icon: s2Completed ? Icons.check : null,
                      isCompleted: s2Completed,
                      isActive: s2Active,
                      isPending: s2Pending,
                      title: 'Agent Review',
                      subtitle: isAwaiting
                          ? 'Awaiting agent approval'
                          : (s2Completed ? 'Approval granted' : 'Pending review'),
                      time: 'Step 2',
                      showLine: true,
                      lineColor: s3Completed || s3Active ? const Color(0xFF059669) : const Color(0xFFD1D5DB),
                    ),
                    _buildStepRow(
                      icon: s3Completed ? Icons.check : null,
                      isCompleted: s3Completed,
                      isActive: s3Active,
                      isPending: s3Pending,
                      title: 'Confirmed',
                      subtitle: isConfirmed
                          ? 'Services secured & confirmed'
                          : (s3Completed ? 'Confirmed' : 'Pending confirmation'),
                      time: 'Step 3',
                      showLine: true,
                      lineColor: s4Completed ? const Color(0xFF059669) : const Color(0xFFD1D5DB),
                    ),
                    _buildStepRow(
                      icon: s4Completed ? Icons.check : null,
                      isCompleted: s4Completed,
                      isActive: s4Active,
                      isPending: s4Pending,
                      title: 'Ready',
                      subtitle: s4Completed ? 'Tickets issued' : 'Ticket issued upon confirmation',
                      time: 'Step 4',
                      showLine: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Digital Ticket Card (Shown ONLY when Confirmed or Completed) ──
              if (isQrEligible) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.figmaDarkGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // QR Code Box
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: reference,
                          version: QrVersions.auto,
                          size: 60,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.figmaDarkGreen,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.figmaDarkGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR DIGITAL TICKET',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaGold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tripTitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dates,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stops,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paid · \$${total.toStringAsFixed(0)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Ticket Pending Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2822) : const Color(0xFFF3F7F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFD4E2DA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C261A) : const Color(0xFFFBF4E4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pending_actions_outlined,
                          color: AppColors.figmaGold,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DIGITAL TICKET PENDING',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.figmaGold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Awaiting Agent Approval',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your digital QR boarding pass will appear here once approved by our travel desk.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ── Payment Action: If booking is approved by agent but unpaid ──
              if (isConfirmed && !isPaid) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/checkout',
                        arguments: _booking,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.figmaGold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Pay Now with Stripe',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Primary Action: View Confirmation or Review Itinerary ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (isQrEligible) {
                      Navigator.pushNamed(
                        context,
                        '/trip-confirmation',
                        arguments: _booking,
                      );
                    } else {
                      Navigator.pushNamed(context, '/my-itinerary');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.figmaDarkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isQrEligible
                            ? Icons.confirmation_number_outlined
                            : Icons.map_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isQrEligible ? 'View Confirmation' : 'Review Itinerary',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Secondary Action: Cancel Booking ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    foregroundColor: isDark ? Colors.white : AppColors.figmaDarkGreen,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: isDark ? Colors.white70 : AppColors.figmaDarkGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cancel Booking',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.figmaDarkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Subtext
              Text(
                'Eligible items can be cancelled without charge until 8 October.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required IconData? icon,
    required bool isCompleted,
    required bool isActive,
    required bool isPending,
    required String title,
    required String subtitle,
    required String time,
    required bool showLine,
    Color lineColor = const Color(0xFFD1D5DB),
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Indicator Column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (isCompleted)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  )
                else if (isActive)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.figmaGold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: lineColor,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Step Texts
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF9EABA4)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    time,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9EABA4)
                          : const Color(0xFF9CA3AF),
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
}
