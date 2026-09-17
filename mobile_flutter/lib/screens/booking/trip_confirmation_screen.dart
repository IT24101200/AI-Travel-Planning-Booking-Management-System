import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app_constants.dart';

/// Trip confirmation screen showing final booking pass, QR ticket, and success celebration.
class TripConfirmationScreen extends StatelessWidget {
  const TripConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bookingRef = booking?['bookingReference'] ?? 'SERENDIB-CONFIRMED';
    final total = (booking?['totalCost'] ?? booking?['totalEstimatedCost'] ?? 0).toDouble();
    final currency = booking?['currency'] ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Confirmed'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Success Icon Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.leaf50,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.leaf200, width: 2),
              ),
              child: const Icon(Icons.check_circle, size: 54, color: AppColors.jungle600),
            ),
            const SizedBox(height: 16),

            const Text(
              'Journey Confirmed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your payment was authorized and commercial booking finalized.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink3, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // ── Travel Pass / Voucher Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.leaf400.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                            'SERENDIB PASS',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.jungle900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.leaf100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'READY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.jungle700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.line),

                  Text(
                    bookingRef,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.jungle700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

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
                      size: 180,
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
                    'Instant check-in token for transport, hotels & tour checkpoints',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.ink3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Summary Details ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  _row('Total Paid', '\$${total.toStringAsFixed(2)} $currency'),
                  _row('Gateway', 'Stripe Sandbox (tok_visa)'),
                  _row('Confirmation Date', booking?['createdAt']?.toString().substring(0, 10) ?? 'Today'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                icon: const Icon(Icons.explore),
                label: const Text('Return to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.jungle600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/trip-history');
                },
                icon: const Icon(Icons.card_travel, color: AppColors.jungle600),
                label: const Text('View All Bookings', style: TextStyle(color: AppColors.jungle600, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.jungle600),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
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
