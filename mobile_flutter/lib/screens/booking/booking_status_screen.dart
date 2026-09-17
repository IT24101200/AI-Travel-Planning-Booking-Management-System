import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Booking status screen with status timeline and QR code for confirmed bookings.
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
    setState(() { _loading = true; _error = null; });
    try {
      _booking = await ApiService.getBooking(id);
      if (_booking == null) _error = 'Booking not found';
    } catch (e) {
      _error = 'Failed to load booking';
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Status')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading booking...')
          : _error != null
              ? ErrorMessage(message: _error!)
              : _booking == null
                  ? const EmptyState(message: 'Booking not found')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Booking reference
                          Text(
                            _booking!['bookingReference'] ?? 'N/A',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          StatusBadge(status: _getStatusString()),
                          const SizedBox(height: 24),

                          // Status timeline
                          _buildStatusTimeline(),
                          const SizedBox(height: 24),

                          // QR Code (only for confirmed bookings)
                          if (_getStatusString().toLowerCase() == 'confirmed' ||
                              _getStatusString().toLowerCase() == 'completed') ...[
                            const Text(
                              'Your QR Ticket',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: QrImageView(
                                data: _booking!['bookingReference'] ?? 'NOREF',
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Booking details card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Booking Details',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const Divider(),
                                  _detailRow('Reference', _booking!['bookingReference'] ?? 'N/A'),
                                  _detailRow('Total Cost',
                                      '\$${(_booking!['totalCost'] ?? 0).toStringAsFixed(2)} ${_booking!['currency'] ?? 'USD'}'),
                                  _detailRow('Created', _booking!['createdAt']?.toString().substring(0, 10) ?? 'N/A'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Approval history
                          if (_booking!['bookingApprovals'] != null &&
                              (_booking!['bookingApprovals'] as List).isNotEmpty) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Approval History',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    const Divider(),
                                    ...(_booking!['bookingApprovals'] as List).map<Widget>((approval) {
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          approval['decision']?.toString() == 'Approved'
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          color: approval['decision']?.toString() == 'Approved'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        title: Text(approval['decision']?.toString() ?? ''),
                                        subtitle: Text(approval['comment'] ?? ''),
                                        trailing: Text(
                                          approval['decidedAt']?.toString().substring(0, 10) ?? '',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  String _getStatusString() {
    final status = _booking!['status'];
    if (status is int) {
      // Map enum integer values to strings
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

  /// Build status timeline visualization
  Widget _buildStatusTimeline() {
    final currentStatus = _getStatusString().toLowerCase();
    final steps = ['Draft', 'Awaiting Approval', 'Confirmed'];

    int currentStep = 0;
    if (currentStatus == 'awaitingapproval' || currentStatus == 'awaiting approval') {
      currentStep = 1;
    } else if (currentStatus == 'confirmed' || currentStatus == 'completed') {
      currentStep = 2;
    } else if (currentStatus == 'rejected' || currentStatus == 'cancelled') {
      currentStep = -1; // Special case
    }

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 3,
              color: stepIndex < currentStep ? const Color(0xFF0D9488) : Colors.grey.shade300,
            ),
          );
        }
        // Step circle
        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex <= currentStep && currentStep >= 0;
        final isCurrent = stepIndex == currentStep;

        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? const Color(0xFF0D9488) : Colors.grey.shade300,
                border: isCurrent ? Border.all(color: const Color(0xFF0D9488), width: 3) : null,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: 18,
                color: isCompleted ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? const Color(0xFF0D9488) : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Build a detail row
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
