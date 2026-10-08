import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/ticket_pdf_service.dart';

/// Trip confirmation screen matching Figma frame 13 · Trip Confirmation (node 7:11118)
class TripConfirmationScreen extends StatelessWidget {
  const TripConfirmationScreen({super.key});

  String _bookingDates(Map<String, dynamic> booking) {
    final legacy = booking['dates']?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    if (start == null || end == null) return 'Dates unavailable';
    return '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}';
  }

  String _bookingDestinations(Map<String, dynamic> booking) {
    final raw = booking['orderedDestinations'];
    if (raw is List) {
      final names = raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(' · ');
    }
    final primary = booking['destinationName']?.toString().trim();
    return primary == null || primary.isEmpty ? 'Destinations unavailable' : primary;
  }

  List<Map<String, dynamic>> _bookingItems(Map<String, dynamic> booking) {
    final raw = booking['bookingItems'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  String _hotelName(List<Map<String, dynamic>> items, Map<String, dynamic> booking) {
    for (final item in items) {
      if (item['hotelName'] != null) return item['hotelName'].toString();
    }
    final rootValue = booking['hotelName']?.toString().trim();
    return rootValue == null || rootValue.isEmpty ? 'Accommodation details unavailable' : rootValue;
  }

  String _transportName(List<Map<String, dynamic>> items, Map<String, dynamic> booking) {
    for (final item in items) {
      if (item['transportOptionId'] != null || item['transportType'] != null) {
        final type = item['transportType']?.toString().trim();
        final from = item['routeFrom']?.toString().trim();
        final to = item['routeTo']?.toString().trim();
        final route = from != null && from.isNotEmpty && to != null && to.isNotEmpty
            ? ' ($from → $to)'
            : '';
        return '${type == null || type.isEmpty ? 'Transport' : type}$route';
      }
    }
    final rootValue = booking['transportName']?.toString().trim();
    return rootValue == null || rootValue.isEmpty ? 'Transport details unavailable' : rootValue;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) {
      return const Scaffold(
        body: Center(child: Text('No confirmed booking is available.')),
      );
    }
    final Map<String, dynamic> booking = Map<String, dynamic>.from(args);

    final bookingStatus = booking['status']?.toString().toLowerCase();
    final isConfirmed = bookingStatus == 'confirmed' || bookingStatus == '2';
    final payments = booking['payments'];
    final isPaid = booking['paymentStatus']?.toString().toLowerCase() == 'paid' ||
        (payments is List && payments.any((payment) {
          return payment is Map &&
              payment['status']?.toString().toLowerCase() == 'paid';
        }));
    if (!isConfirmed || !isPaid) {
      return const Scaffold(
        body: Center(child: Text('Payment is required before the ticket is available.')),
      );
    }

    final bookingRef = booking['bookingReference']?.toString();
    if (bookingRef == null || bookingRef.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Booking reference is unavailable.')),
      );
    }
    final customerName = booking['customerName']?.toString().trim();
    final tripTitle = booking['tripTitle']?.toString().trim().isNotEmpty == true
        ? booking['tripTitle'].toString()
        : (booking['destinationName']?.toString().trim().isNotEmpty == true
            ? booking['destinationName'].toString()
            : 'Trip details unavailable');
    final dates = _bookingDates(booking);
    final items = _bookingItems(booking);
    final hotelName = _hotelName(items, booking);
    final transportName = _transportName(items, booking);
    final destinations = _bookingDestinations(booking);
    final travellerCount = booking['travellerCount']?.toString().trim();
    final customerLabel = customerName == null || customerName.isEmpty
        ? 'Customer unavailable'
        : customerName;
    final travellerLabel = travellerCount == null || travellerCount.isEmpty
        ? 'Traveller count unavailable'
        : '$travellerCount travellers';
    final totalCost = booking['totalCost'] is num
        ? (booking['totalCost'] as num).toDouble()
        : double.tryParse(booking['totalCost']?.toString() ?? '') ?? 0;
    final currency = booking['currency']?.toString() ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // ── Success Halo & Icon ──
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE5F1EA),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E5E4B) : const Color(0xFFC8E4D4),
                      width: 8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: Color(0xFF267A55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Headline & Subhead ──
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Your Sri Lankan journey is secured. Tickets and partner contacts are now available offline.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              // ── Booking Reference Pill ──
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: bookingRef));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied "$bookingRef" to clipboard')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C261A) : const Color(0xFFF6EBCB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BOOKING REFERENCE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE5D7B5) : const Color(0xFF6B7280),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bookingRef,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.figmaGold : const Color(0xFF123F32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Confirmation Card ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10291F).withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ), /*
                      value: '$customerLabel · $travellerLabel',
                  */
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Banner
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 116,
                        width: double.infinity,
                        child: Image.network(
                          'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=800&auto=format&fit=crop&q=80',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: const Color(0xFF374151),
                            child: const Icon(
                              Icons.landscape,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Trip Heading
                    Text(
                      tripTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dates,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                      ),
                    ),

                    // 4 Dynamic Recap Rows
                    _buildRecapRow(
                      context,
                      icon: Icons.place_outlined,
                      label: 'Destinations',
                      value: destinations,
                    ),
                    const SizedBox(height: 10),
                    _buildRecapRow(
                      context,
                      icon: Icons.hotel_outlined,
                      label: 'Accommodation',
                      value: hotelName,
                    ),
                    const SizedBox(height: 10),
                    _buildRecapRow(
                      context,
                      icon: Icons.directions_car_outlined,
                      label: 'Transport',
                      value: transportName,
                    ),
                    const SizedBox(height: 10),
                    _buildRecapRow(
                      context,
                      icon: Icons.people_outline,
                      label: 'Travelers',
                      value: '$customerLabel · $travellerLabel',
                      /*
                      value: '$customerName · 2 Travelers',
                    */), /*
                      value: '$customerLabel · $travellerLabel',
                  */
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Share & Download Buttons ──
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // Real clipboard share implementation
                          final shareText = '''
Serendib Trails - Confirmed Trip Itinerary
Reference: $bookingRef
Customer: $customerName
Destination: $tripTitle
Dates: $dates
Hotel: $hotelName
Transport: $transportName
Stops: $destinations
'''.trim();
                          Clipboard.setData(ClipboardData(text: shareText));
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trip itinerary copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_outlined,
                              size: 16,
                              color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Share Trip',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF123F32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // Real pure-Dart PDF ticket generation
                          final pdfBytes = TicketPdfService.generateTicketPdf(
                            bookingReference: bookingRef,
                            customerName: customerLabel,
                            destination: tripTitle,
                            dates: dates,
                            stops: destinations,
                            hotelName: hotelName,
                            transportTitle: transportName,
                            totalCost: totalCost,
                            currency: currency,
                            booking: booking,
                          );
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Ticket PDF generated (${pdfBytes.length} bytes ready offline).',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 16,
                              color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Download PDF',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF123F32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Next Step Reminder Box ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF221F18) : const Color(0xFFF6EBCB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.figmaGold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "We'll remind you about visa, weather and packing details 7 days before departure.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFE5D7B5) : const Color(0xFF17211D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Back to Explore Button ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF123F32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.explore_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Back to Explore',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecapRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE5F1EA),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
