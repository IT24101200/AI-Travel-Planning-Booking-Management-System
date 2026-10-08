import 'dart:convert';
import 'dart:typed_data';

/// Pure-Dart service to generate valid, lightweight PDF tickets for trip bookings.
/// Does not depend on heavy platform-specific binaries.
class TicketPdfService {
  /// Generates a valid PDF 1.4 document containing booking confirmation details.
  static Uint8List generateTicketPdf({
    required String bookingReference,
    String customerName = 'Customer unavailable',
    String destination = 'Trip details unavailable',
    String dates = 'Dates unavailable',
    String stops = 'Destinations unavailable',
    String hotelName = 'Accommodation details unavailable',
    String transportTitle = 'Transport details unavailable',
    double totalCost = 0.0,
    String currency = '',
    Map<String, dynamic>? booking,
    Map<String, dynamic>? hotel,
    Map<String, dynamic>? transport,
  }) {
    final effectiveRef = booking?['bookingReference']?.toString() ??
        (booking?['id'] != null ? 'ST-2026-${booking!['id']}' : bookingReference);
    final effectiveCustomer = booking?['customerName']?.toString() ?? customerName;
    final orderedDestinations = booking?['orderedDestinations'];
    final destinationList = orderedDestinations is List
        ? orderedDestinations
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList()
        : const <String>[];
    final effectiveDestination = booking?['tripTitle']?.toString() ??
        booking?['destinationName']?.toString() ??
        booking?['destination']?.toString() ??
        (destinationList.isEmpty ? destination : destinationList.join(' - '));
    final effectiveDates = booking?['dates']?.toString() ??
        _formatBookingDates(booking) ??
        dates;
    final effectiveStops = booking?['stops']?.toString() ??
        (destinationList.isEmpty ? stops : destinationList.join(', '));
    final effectiveHotel = hotel?['name']?.toString() ??
        booking?['hotelName']?.toString() ??
        hotelName;
    final effectiveTransport = transport != null
        ? '${transport['name'] ?? transport['type']} (${transport['route'] ?? 'Private'})'
        : (booking?['transportName']?.toString() ?? transportTitle);
    final effectiveCost = (booking?['totalCost'] ?? totalCost)
        .toDouble();
    final effectiveCurrency = booking?['currency']?.toString() ?? currency;
    final buffer = StringBuffer();

    // Helper to sanitize strings for PDF literals
    String escape(String text) => text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('–', '-')
        .replaceAll('·', '*');

    final lines = [
      'SERENDIB TRAILS - DIGITAL TRAVEL TICKET',
      '====================================================',
      'Booking Reference : ${escape(effectiveRef)}',
      'Status            : CONFIRMED & PAID',
      'Issue Date        : ${DateTime.now().toIso8601String().substring(0, 10)}',
      '',
      'PASSENGER DETAILS',
      '----------------------------------------------------',
      'Lead Passenger    : ${escape(effectiveCustomer)}',
      '',
      'TRIP SUMMARY',
      '----------------------------------------------------',
      'Destination       : ${escape(effectiveDestination)}',
      'Dates             : ${escape(effectiveDates)}',
      'Route Stops       : ${escape(effectiveStops)}',
      '',
      'ACCOMMODATION & TRANSPORT',
      '----------------------------------------------------',
      'Hotel / Stay      : ${escape(effectiveHotel)}',
      'Vehicle Transfer  : ${escape(effectiveTransport)}',
      '',
      'PAYMENT SUMMARY',
      '----------------------------------------------------',
      'Total Amount Paid : $effectiveCurrency ${effectiveCost.toStringAsFixed(2)}',
      'Method            : Credit Card (Stripe Verified)',
      '',
      '====================================================',
      'Thank you for planning with Serendib Trails!',
      'Present this ticket or QR code at each destination.',
    ];

    final streamContent = StringBuffer();
    streamContent.writeln('BT');
    streamContent.writeln('/F1 11 Tf');
    streamContent.writeln('50 720 Td');
    streamContent.writeln('16 TL');
    for (final line in lines) {
      if (line.startsWith('SERENDIB') ||
          line.startsWith('PASSENGER') ||
          line.startsWith('TRIP') ||
          line.startsWith('ACCOMMODATION') ||
          line.startsWith('PAYMENT')) {
        streamContent.writeln('/F2 12 Tf');
        streamContent.writeln('(${escape(line)}) Tj T*');
        streamContent.writeln('/F1 11 Tf');
      } else {
        streamContent.writeln('(${escape(line)}) Tj T*');
      }
    }
    streamContent.writeln('ET');
    final streamBytes = utf8.encode(streamContent.toString());

    buffer.write('%PDF-1.4\n');
    final offsets = <int>[];

    void writeObj(int num, String content) {
      offsets.add(buffer.length);
      buffer.write('$num 0 obj\n$content\nendobj\n');
    }

    writeObj(1, '<< /Type /Catalog /Pages 2 0 R >>');
    writeObj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    writeObj(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>',
    );

    offsets.add(buffer.length);
    buffer.write('4 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
    buffer.write(streamContent.toString());
    buffer.write('endstream\nendobj\n');

    writeObj(5, '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>');
    writeObj(6, '<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold >>');

    final xrefOffset = buffer.length;
    buffer.write('xref\n0 7\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    );

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String? _formatBookingDates(Map<String, dynamic>? booking) {
    if (booking == null) return null;
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    if (start == null || end == null) return null;
    return '${start.toIso8601String().substring(0, 10)} - ${end.toIso8601String().substring(0, 10)}';
  }
}
