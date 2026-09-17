import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Checkout and payment screen with booking summary and pay button.
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
      // Itinerary passed directly from itinerary screen
      setState(() {
        _booking = args;
        _loading = false;
      });
    } else if (_booking == null) {
      setState(() { _loading = false; _error = 'No booking data provided'; });
    }
  }

  /// Load booking details by ID
  Future<void> _loadBooking(int id) async {
    setState(() { _loading = true; });
    try {
      _booking = await ApiService.getBooking(id);
      if (_booking == null) _error = 'Booking not found';
    } catch (e) {
      _error = 'Failed to load booking';
    }
    if (mounted) setState(() { _loading = false; });
  }

  /// Process payment using Stripe sandbox
  Future<void> _pay() async {
    if (_booking == null) return;
    setState(() { _paying = true; _paymentMessage = null; });

    try {
      final result = await ApiService.createPayment({
        'bookingId': _booking!['id'],
        'amount': _booking!['totalCost'] ?? _booking!['totalEstimatedCost'] ?? 0,
        'currency': _booking!['currency'] ?? 'USD',
        'stripeToken': 'tok_visa', // Stripe sandbox test token
      });

      if (!mounted) return;

      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        setState(() { _paymentMessage = 'Payment successful!'; });
        // Navigate to confirmation after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/trip-confirmation', arguments: _booking);
          }
        });
      } else {
        setState(() { _paymentMessage = result['message'] ?? 'Payment failed'; });
      }
    } catch (e) {
      setState(() { _paymentMessage = 'Payment error. Please try again.'; });
    }
    if (mounted) setState(() { _paying = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading booking...')
          : _error != null
              ? ErrorMessage(message: _error!)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking summary header
                      const Text(
                        'Booking Summary',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Booking items
                      if (_booking!['bookingItems'] != null) ...[
                        ...((_booking!['bookingItems'] as List).map<Widget>((item) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                _getItemIcon(item['itemType']?.toString() ?? ''),
                                color: const Color(0xFF0D9488),
                              ),
                              title: Text(item['tourName'] ?? 'Item'),
                              subtitle: Text('Qty: ${item['quantity'] ?? 1}'),
                              trailing: Text(
                                '\$${(item['subtotal'] ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        })),
                      ] else if (_booking!['items'] != null) ...[
                        // Itinerary items fallback
                        ...((_booking!['items'] as List).map<Widget>((item) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.tour, color: Color(0xFF0D9488)),
                              title: Text(item['tourName'] ?? 'Tour'),
                              subtitle: Text('Day ${item['dayNumber'] ?? 1}'),
                              trailing: Text(
                                '\$${(item['priceAtSelection'] ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        })),
                      ],

                      const Divider(height: 32),

                      // Total cost
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${(_booking!['totalCost'] ?? _booking!['totalEstimatedCost'] ?? 0).toStringAsFixed(2)} ${_booking!['currency'] ?? 'USD'}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Payment method card
                      Card(
                        color: Colors.grey.shade50,
                        child: const ListTile(
                          leading: Icon(Icons.credit_card, color: Color(0xFF7C5CFC)),
                          title: Text('Stripe Test Card'),
                          subtitle: Text('•••• •••• •••• 4242'),
                          trailing: Icon(Icons.check_circle, color: Colors.green),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Payment status message
                      if (_paymentMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _paymentMessage!.contains('successful')
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _paymentMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _paymentMessage!.contains('successful')
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _paying ? null : _pay,
                          icon: _paying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.payment),
                          label: Text(
                            _paying ? 'Processing...' : 'Pay Now',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  /// Get icon for booking item type
  IconData _getItemIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tour':
      case '0':
        return Icons.landscape;
      case 'room':
      case '1':
        return Icons.hotel;
      case 'transport':
      case '2':
        return Icons.commute;
      default:
        return Icons.receipt;
    }
  }
}
