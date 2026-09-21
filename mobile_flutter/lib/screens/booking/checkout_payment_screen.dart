import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Checkout and payment screen with booking summary, Stripe sandbox, and secure confirmation.
class CheckoutPaymentScreen extends StatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  Map<String, dynamic>? _booking;
  bool _loading = true;
  bool _paying = false;
  String? _error;
  String? _paymentMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && _booking == null) {
      _loadBooking(args);
    } else if (args is Map<String, dynamic> && _booking == null) {
      setState(() {
        _booking = args;
        _loading = false;
      });
    } else if (_booking == null) {
      setState(() {
        _booking = {
          'id': 101,
          'bookingReference': 'ST-2026-98214',
          'destination': 'Sigiriya & Ella Highlights',
          'dates': 'Oct 12 – Oct 16, 2026',
          'travellerCount': 2,
          'totalCost': 485.0,
          'currency': 'USD',
          'items': [
            {'name': 'Sigiriya Rock Fortress Excursion', 'type': 'Tour', 'price': 185.0},
            {'name': 'Heritance Kandalama (Superior Room)', 'type': 'Room', 'price': 210.0},
            {'name': 'Scenic Odyssey Train Transfer', 'type': 'Transport', 'price': 90.0},
          ],
        };
        _loading = false;
        _error = null;
      });
    }
  }

  /// Load booking details by ID
  Future<void> _loadBooking(int id) async {
    setState(() => _loading = true);
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
          _error = 'Failed to load booking details';
          _loading = false;
        });
      }
    }
  }

  /// Process payment using Stripe sandbox
  Future<void> _pay() async {
    if (_booking == null) return;
    setState(() {
      _paying = true;
      _paymentMessage = null;
    });

    try {
      final result = await ApiService.createPayment({
        'bookingId': _booking!['id'],
        'amount':
            _booking!['totalCost'] ?? _booking!['totalEstimatedCost'] ?? 0,
        'currency': _booking!['currency'] ?? 'USD',
        'stripeToken': 'tok_visa', // Stripe sandbox test token
      });

      if (!mounted) return;

      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        setState(() {
          _paymentMessage = 'Payment authorized! Your travel pass is ready.';
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/trip-confirmation',
              arguments: _booking,
            );
          }
        });
      } else {
        setState(() {
          _paymentMessage =
              result['message'] ?? 'Payment authorization declined. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        _paymentMessage = 'Network error processing payment with Stripe.';
      });
    }
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commercial Checkout')),
        body: const LoadingIndicator(message: 'Preparing checkout invoice...'),
      );
    }

    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commercial Checkout')),
        body: ErrorMessage(message: _error ?? 'No checkout data found'),
      );
    }

    final total =
        (_booking!['totalCost'] ?? _booking!['totalEstimatedCost'] ?? 0)
            .toDouble();
    final currency = _booking!['currency'] ?? 'USD';
    final bookingRef =
        _booking!['bookingReference'] ?? 'ITIN-#${_booking!['id']}';

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Booking & Pay')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Reference Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.leaf50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.leaf100),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.jungle600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Serendib Verified Itinerary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.jungle900,
                          ),
                        ),
                        Text(
                          'Reference: $bookingRef',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Itemized Breakdown
            const Text(
              'Trip Inclusions Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),

            if (_booking!['bookingItems'] != null) ...[
              ...((_booking!['bookingItems'] as List).map<Widget>(
                (item) => _buildItemTile(item),
              )),
            ] else if (_booking!['items'] != null) ...[
              ...((_booking!['items'] as List).map<Widget>((item) {
                return _buildItineraryItemTile(item);
              })),
            ] else ...[
              // Fallback inclusive card
              _buildStandardInclusionTile(total, currency),
            ],

            const SizedBox(height: 16),

            // Total Cost Highlight Card
            Container(
              padding: const EdgeInsets.all(18),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Payable',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.ink3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Includes taxes & agent approval fees',
                        style: TextStyle(fontSize: 10, color: AppColors.ink3),
                      ),
                    ],
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)} $currency',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.jungle600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stripe Sandbox Payment Card
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF635BFF), // Stripe purple
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'stripe',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Visa • Sandbox Gateway',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '•••• •••• •••• 4242',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.jungle600,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: AppColors.ink3),
                      SizedBox(width: 6),
                      Text(
                        'Encrypted sandbox transaction for SE3090 evaluation',
                        style: TextStyle(fontSize: 11, color: AppColors.ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Error or Success Banner
            if (_paymentMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _paymentMessage!.contains('authorized')
                      ? AppColors.leaf50
                      : AppColors.coral500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _paymentMessage!.contains('authorized')
                        ? AppColors.jungle600.withValues(alpha: 0.3)
                        : AppColors.coral500.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _paymentMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _paymentMessage!.contains('authorized')
                        ? AppColors.jungle700
                        : AppColors.coral500,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _paying ? null : _pay,
                icon: _paying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.lock, size: 18),
                label: Text(
                  _paying
                      ? 'Processing Authorization...'
                      : 'Authorize Payment (\$${total.toStringAsFixed(0)})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.tour_outlined, color: AppColors.jungle600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item['tourName'] ?? 'Experience Package',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '\$${(item['subtotal'] ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.jungle600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryItemTile(Map<String, dynamic> item) {
    final tourName = item['tourName'] ?? 'Guided Tour Activity';
    final price = (item['priceAtSelection'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.explore_outlined,
            color: AppColors.ocean500,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tourName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Day ${item['dayNumber'] ?? 1}',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                ),
              ],
            ),
          ),
          Text(
            '\$${price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.jungle600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInclusionTile(double total, String currency) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.luggage_outlined,
            color: AppColors.jungle600,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Coordinated Tours, Boutique Rooms & Scheduled Transit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '\$${total.toStringAsFixed(0)} $currency',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.jungle600,
            ),
          ),
        ],
      ),
    );
  }
}
