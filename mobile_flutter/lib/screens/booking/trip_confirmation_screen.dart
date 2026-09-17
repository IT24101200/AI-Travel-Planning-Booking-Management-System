import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Trip confirmation screen showing final booking summary with QR ticket.
class TripConfirmationScreen extends StatelessWidget {
  const TripConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final booking = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Confirmed!')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Success icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),

            const Text(
              'Booking Confirmed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your trip has been successfully booked',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Booking reference
            if (booking != null && booking['bookingReference'] != null) ...[
              Card(
                color: const Color(0xFF0D9488).withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Booking Reference',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        booking['bookingReference'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // QR Code ticket
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your QR Ticket',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: booking['bookingReference'] ?? 'NOREF',
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Show this at check-in',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Booking details
            if (booking != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trip Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Divider(),
                      _row('Total Cost',
                          '\$${(booking['totalCost'] ?? booking['totalEstimatedCost'] ?? 0).toStringAsFixed(2)}'),
                      _row('Currency', booking['currency'] ?? 'USD'),
                      _row('Date',
                          booking['createdAt']?.toString().substring(0, 10) ?? 'Today'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // View My Trips button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                },
                icon: const Icon(Icons.card_travel),
                label: const Text('View My Trips', style: TextStyle(fontSize: 16)),
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

  Widget _row(String label, String value) {
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
