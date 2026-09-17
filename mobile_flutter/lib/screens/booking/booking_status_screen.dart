import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Booking status screen with status timeline, QR code ticket, and agent approval audit trail.
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
    final bookingId = ModalRoute.of(context)?.settings.arguments as int?;
    if (bookingId != null && _booking == null) {
      _loadBooking(bookingId);
    }
  }

  /// Fetch booking details from backend
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
        body: ErrorMessage(message: _error ?? 'Booking not found'),
      );
    }

    final statusStr = _getStatusString();
    final isConfirmed = statusStr.toLowerCase() == 'confirmed' || statusStr.toLowerCase() == 'completed';
    final bookingRef = _booking!['bookingReference'] ?? 'SERENDIB-#${_booking!['id']}';
    final total = (_booking!['totalCost'] ?? 0).toDouble();
    final currency = _booking!['currency'] ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Pass & Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_booking!['id'] != null) _loadBooking(_booking!['id']);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isConfirmed ? AppColors.leaf50 : AppColors.sand100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConfirmed ? Icons.check_circle : Icons.hourglass_top,
                    size: 16,
                    color: isConfirmed ? AppColors.jungle600 : AppColors.sand600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusStr.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: isConfirmed ? AppColors.jungle700 : AppColors.sand700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bookingRef,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 24),

            // Visual Status Stepper
            _buildStatusTimeline(),

            const SizedBox(height: 24),

            // ── Boarding Pass / QR Ticket (If confirmed) ──
            if (isConfirmed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.leaf400.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.jungle900.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.travel_explore, color: AppColors.jungle600, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'SERENDIB TRAILS PASS',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.jungle900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.leaf100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CONFIRMED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.jungle700),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.line),
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: QrImageView(
                        data: bookingRef,
                        version: QrVersions.auto,
                        size: 170,
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
                    const SizedBox(height: 12),
                    const Text(
                      'Present this QR ticket at hotels, tour pickups, and rail gates',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Booking Summary Card ──
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
                  const Text(
                    'Commercial Summary',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const Divider(height: 20, color: AppColors.line),
                  _detailRow('Total Invoiced', '\$${total.toStringAsFixed(2)} $currency'),
                  _detailRow('Created Date', _booking!['createdAt']?.toString().substring(0, 10) ?? 'N/A'),
                  _detailRow('Status Phase', statusStr),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Human-in-the-loop Agent Approvals Trail ──
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
                        Icon(Icons.shield_outlined, size: 18, color: AppColors.jungle600),
                        SizedBox(width: 8),
                        Text(
                          'Staff Review & Audit Trail',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.line),
                    ...(_booking!['bookingApprovals'] as List).map<Widget>((approval) {
                      final decision = approval['decision']?.toString() ?? 'Approved';
                      final isApproved = decision.toLowerCase() == 'approved';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isApproved ? Icons.verified_user : Icons.rate_review,
                          color: isApproved ? AppColors.jungle600 : AppColors.sand500,
                        ),
                        title: Text(decision, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(approval['comment'] ?? 'No comments provided', style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          approval['decidedAt']?.toString().substring(0, 10) ?? '',
                          style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Back to Home
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.jungle600,
                  side: const BorderSide(color: AppColors.jungle600),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home Dashboard'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final currentStatus = _getStatusString().toLowerCase();
    final steps = ['Draft', 'Staff Review', 'Confirmed'];

    int currentStep = 0;
    if (currentStatus == 'awaitingapproval' || currentStatus == 'awaiting approval') {
      currentStep = 1;
    } else if (currentStatus == 'confirmed' || currentStatus == 'completed') {
      currentStep = 2;
    }

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 3,
              color: stepIndex < currentStep ? AppColors.jungle600 : AppColors.lineStrong,
            ),
          );
        }
        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex <= currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.jungle600 : Colors.white,
                border: Border.all(
                  color: isCompleted ? AppColors.jungle600 : AppColors.lineStrong,
                  width: isCurrent ? 3 : 1.5,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: 16,
                color: isCompleted ? Colors.white : AppColors.ink3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCompleted ? AppColors.jungle700 : AppColors.ink3,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.ink3, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
        ],
      ),
    );
  }
}
