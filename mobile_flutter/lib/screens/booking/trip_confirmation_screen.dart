import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_constants.dart';
import '../../widgets/common_widgets.dart';

/// Serendib Verdant Trip Confirmation Screen.
/// Displays celebratory confirmation badge, verified booking reference,
/// confirmed route stepper, travel highlights, traveler details, and next steps checklist.
class TripConfirmationScreen extends StatelessWidget {
  const TripConfirmationScreen({super.key});

  void _copyBookingRef(BuildContext context, String refCode) {
    Clipboard.setData(ClipboardData(text: refCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$refCode" to clipboard!'),
        backgroundColor: AppColors.jungle700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showActionToast(BuildContext context, String message) {
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
    final booking =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bookingRef =
        booking?['bookingReference']?.toString() ?? '#SRN-LK-2024-8842';
    final total = (booking?['totalCost'] ?? booking?['totalEstimatedCost'] ?? 1191.80)
        .toDouble();
    final currency = booking?['currency']?.toString() ?? 'USD';
    final customerName =
        booking?['customerName']?.toString() ?? 'Kasun Perera';
    final tourTitle =
        booking?['tourPackage']?['title']?.toString() ?? 'Sri Lanka Grand Explorer';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trip Confirmation'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
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
                // ── Celebratory Status Badge & Headline ──
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // Animated checkmark container with golden sparkle
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.leaf200.withValues(alpha: 0.6),
                            ),
                          ),
                          Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.jungle600,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33166B4F),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const Positioned(
                            top: 0,
                            right: 4,
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppColors.sand500,
                              size: 20,
                            ),
                          ),
                          const Positioned(
                            bottom: 2,
                            left: 4,
                            child: Icon(
                              Icons.star,
                              color: AppColors.sand400,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'BOOKING VERIFIED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.jungle600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ayubowan! Your Ceylon Journey is Confirmed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your 7-day Sri Lanka adventure is fully secured and prepared by our autonomous agents.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Booking Reference & Trust Card ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
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
                              Row(
                                children: [
                                  Text(
                                    bookingRef,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () =>
                                        _copyBookingRef(context, bookingRef),
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.content_copy,
                                        size: 16,
                                        color: AppColors.inkTertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'TOTAL PAID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppColors.inkTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${total.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // SLTDA Certification Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.leaf50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.verified_user,
                              size: 20,
                              color: AppColors.jungle600,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SLTDA Licensed & Fully Insured',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.jungle900,
                                    ),
                                  ),
                                  Text(
                                    'Sri Lanka Tourism Development Authority Ref #TA-9042',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Trip Highlights Snapshot Card ──
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
                          Row(
                            children: [
                              const Icon(
                                Icons.explore,
                                color: AppColors.jungle600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tourTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.leaf100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '7 Days / 6 Nights',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.jungle700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Confirmed Route Stepper
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONFIRMED ROUTE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.inkTertiary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRouteStop('Colombo', isPrimary: true),
                                _buildRouteConnector(),
                                _buildRouteStop('Sigiriya'),
                                _buildRouteConnector(),
                                _buildRouteStop('Kandy'),
                                _buildRouteConnector(),
                                _buildRouteStop('Ella'),
                                _buildRouteConnector(),
                                _buildRouteStop('Galle', isPrimary: true),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Travel Details List
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        title: 'Travel Dates',
                        value: 'Oct 14 – Oct 20, 2024',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.hotel,
                        title: 'Eco-Stays & Heritage Lodges',
                        value:
                            "Sigiriya Eco-Lodge, Earl's Regency Kandy, 98 Acres Ella",
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        icon: Icons.directions_car,
                        title: 'Transfers & Scenic Transit',
                        value:
                            'Dedicated Chauffeur Van + Scenic Kandy-Ella Train 1st Class',
                      ),

                      const SizedBox(height: 14),

                      // Curated Vignette Previews
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppNetworkImage(
                                    imageUrl:
                                        AppDestinations.getImageForDestination(
                                            'Sigiriya'),
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.jungle900
                                              .withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      'Sigiriya Sanctuary',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AppNetworkImage(
                                    imageUrl:
                                        AppDestinations.getImageForDestination(
                                            'Ella'),
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.jungle900
                                              .withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      'Highland Scenic Rail',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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

                // ── Traveler Information Card ──
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
                          Icon(Icons.badge, size: 20, color: AppColors.jungle600),
                          SizedBox(width: 8),
                          Text(
                            'Traveler Information',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LEAD TRAVELER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PARTY SIZE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkTertiary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '2 Adults',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.sand100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 18,
                              color: AppColors.sand700,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Special Dietary Preference',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.sand700,
                                    ),
                                  ),
                                  Text(
                                    'Organic local breakfast noted for all heritage stays.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── What Happens Next Checklist ──
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
                            Icons.checklist,
                            size: 20,
                            color: AppColors.jungle600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'What Happens Next',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildNextStep(
                        stepNumber: 1,
                        text:
                            'Check your email for the complete PDF itinerary, tax invoices, and confirmed hotel vouchers.',
                        subtext: 'Sent to registered guest email',
                      ),
                      const SizedBox(height: 12),
                      _buildNextStep(
                        stepNumber: 2,
                        text:
                            'Your dedicated chauffeur, Sumith Perera, will connect via WhatsApp 24 hours prior to Colombo pickup.',
                        subtext: 'Vehicle: Toyota Commuter Luxury AC Van',
                      ),
                      const SizedBox(height: 12),
                      _buildNextStep(
                        stepNumber: 3,
                        text:
                            'Download offline maps and audio-guides for the Central Highlands trail segments.',
                        subtext: 'Offline pack ready (42 MB)',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Action Buttons ──
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/booking-status',
                        arguments: booking);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('View Live Booking Pass & QR Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.jungle600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _showActionToast(
                      context, 'Itinerary share link copied to clipboard!'),
                  icon: const Icon(Icons.share, color: AppColors.jungle600),
                  label: const Text('Share Itinerary with Co-Travelers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.jungle600,
                    side: const BorderSide(color: AppColors.lineStrong),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Return to Home Explore',
                    style: TextStyle(
                      color: AppColors.inkTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteStop(String city, {bool isPrimary = false}) {
    return Column(
      children: [
        Container(
          width: isPrimary ? 10 : 8,
          height: isPrimary ? 10 : 8,
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.jungle600 : AppColors.jungle500,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteConnector() {
    return Expanded(
      child: Container(
        height: 2,
        color: AppColors.leaf200,
        margin: const EdgeInsets.only(bottom: 14),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.leaf50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.jungle600, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.inkTertiary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStep({
    required int stepNumber,
    required String text,
    required String subtext,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.leaf100,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.jungle700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.inkTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
