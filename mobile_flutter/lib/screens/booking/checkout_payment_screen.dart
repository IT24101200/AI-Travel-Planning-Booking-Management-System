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
    final destination = _booking!['destination'] ?? '7-Day Sri Lanka Grand Explorer';
    final dates = _booking!['dates'] ?? 'Oct 14 – Oct 20';
    final travelers = _booking!['travellerCount'] ?? 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Step Bar & Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.jungle600,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Final Step',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.jungle700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sand100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Step 3 of 3',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sand700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 5,
                    backgroundColor: AppColors.line,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.jungle600),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Order Summary Card with Thumbnail Ribbon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                                'CONFIRMED ITINERARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.sand600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destination,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.leaf50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, size: 20, color: AppColors.jungle600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Thumbnail Ribbon
                      Container(
                        height: 90,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              AppNetworkImage(
                                imageUrl: AppDestinations.getImageForDestination('Sigiriya'),
                                width: double.infinity,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.jungle900.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                bottom: 8,
                                left: 10,
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: AppColors.sand400),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cultural Triangle, Kandy, Ella & Southern Coast',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Compact Breakdown Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildChipPill(Icons.calendar_today, dates),
                          _buildChipPill(Icons.group, '$travelers Travelers'),
                          _buildChipPill(Icons.directions_transit, 'Private Driver & Train'),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(color: AppColors.line, height: 1),
                      const SizedBox(height: 10),

                      const Text(
                        'Package Inclusions',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.inkTertiary),
                      ),
                      const SizedBox(height: 8),

                      _buildInclusionRow(Icons.tour, 'Sigiriya & Ella Multi-Day Tour Package', 540.0),
                      _buildInclusionRow(Icons.hotel, '6 Nights Boutique Eco-Villas & Resorts', 420.0),
                      _buildInclusionRow(Icons.airport_shuttle, 'Private AC Van & Scenic Train Tickets', 160.0),
                      _buildInclusionRow(Icons.confirmation_number, 'Local Park Permits & Heritage Fees', 60.0),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Fare Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fare Summary',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 10),
                      _buildFareRow('Subtotal', '\$${total.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('Service & AI Planning Fee', style: TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
                              SizedBox(width: 4),
                              Icon(Icons.auto_awesome, size: 14, color: AppColors.sand500),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.leaf50, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Free (\$0.00)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.leaf400)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildFareRow('Tourism Development Levy (TDL 1%)', '\$${(total * 0.01).toStringAsFixed(2)}'),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.line, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.inkTertiary)),
                              Text(
                                '\$${(total * 1.01).toStringAsFixed(2)} $currency',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.jungle700),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.sand100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 12, color: AppColors.sand700),
                                SizedBox(width: 4),
                                Text(
                                  'Guaranteed Best Rate',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.sand700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Payment Method Selector & Stripe Form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Card Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          Row(
                            children: [
                              Icon(Icons.lock, size: 14, color: AppColors.jungle600),
                              SizedBox(width: 4),
                              Text('End-to-End Encrypted', style: TextStyle(fontSize: 11, color: AppColors.jungle600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cardholder Name
                      const Text('Cardholder Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: 'Kasun Perera',
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, size: 18, color: AppColors.inkTertiary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.jungle600)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Card Number
                      const Text('Card Number', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: '•••• •••• •••• 4242',
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.credit_card, size: 18, color: AppColors.inkTertiary),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.leaf50, borderRadius: BorderRadius.circular(4)),
                            child: const Text('VISA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.jungle700)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.jungle600)),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Expiry and CVV
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Expiry Date (MM/YY)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: '08/28',
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.calendar_month, size: 18, color: AppColors.inkTertiary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.jungle600)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CVV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                                const SizedBox(height: 4),
                                TextFormField(
                                  initialValue: '882',
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock, size: 18, color: AppColors.inkTertiary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.jungle600)),
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

                const SizedBox(height: 16),

                // Error or Success Banner
                if (_paymentMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _paymentMessage!.contains('authorized')
                          ? AppColors.leaf50
                          : AppColors.coral500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _paymentMessage!.contains('authorized')
                            ? AppColors.jungle600
                            : AppColors.coral500,
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

                // Pay Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _paying ? null : _pay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.jungle600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _paying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Authorize Payment (\$${(total * 1.01).toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ],
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

  Widget _buildChipPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.leaf50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.jungle600),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.inkSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInclusionRow(IconData icon, String title, double cost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.jungle600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '\$${cost.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ],
    );
  }
}
