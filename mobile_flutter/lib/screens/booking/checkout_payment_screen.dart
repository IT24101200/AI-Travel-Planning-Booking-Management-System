import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../services/trip_selection_service.dart';
import '../../widgets/common_widgets.dart';

/// Checkout and payment screen matching Figma frame 11 · Checkout & Payment (node 7:10956)
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

  final TextEditingController _nameController =
      TextEditingController(text: 'MAYA FERNANDO');
  final TextEditingController _cardNumberController =
      TextEditingController(text: '4242 4242 4242 4242');
  final TextEditingController _expiryController =
      TextEditingController(text: '10 / 29');
  final TextEditingController _cvvController =
      TextEditingController(text: '742');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booking != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      _loadBooking(args);
    } else if (args is Map) {
      setState(() {
        _booking = Map<String, dynamic>.from(args);
        _loading = false;
      });
    } else if (TripSelectionService.activeBookingId != null) {
      _loadBooking(TripSelectionService.activeBookingId!);
    } else {
      setState(() {
        _error = 'No booking is available yet. Wait for the travel agent to prepare the proposal.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  /// Normalizes status into numeric enum (0=Draft, 1=AwaitingApproval, 2=Confirmed, 3=Rejected, 4=Cancelled, 5=Completed)
  int _normalizeStatus(dynamic status) {
    if (status is int) return status;
    final s = status.toString().toLowerCase();
    if (s.contains('completed')) return 5;
    if (s.contains('confirmed') || s.contains('approved')) return 2;
    if (s.contains('cancel')) return 4;
    if (s.contains('reject')) return 3;
    if (s.contains('awaiting') || s.contains('pending')) return 1;
    return 0; // Draft
  }

  /// Load booking details by ID
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
          if (_booking == null) {
            _error = 'Booking #$id not found';
          }
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

  /// Validate user-entered card details
  String? _validateCardForm() {
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter the cardholder name.';
    }
    final cleanCard = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    if (cleanCard.length < 15 || !RegExp(r'^\d+$').hasMatch(cleanCard)) {
      return 'Please enter a valid 16-digit card number.';
    }
    final expiry = _expiryController.text.trim();
    if (!RegExp(r'^\d{1,2}\s*/\s*\d{2}$').hasMatch(expiry)) {
      return 'Please enter expiry in MM / YY format.';
    }
    final cvv = _cvvController.text.trim();
    if (cvv.length < 3 || cvv.length > 4 || !RegExp(r'^\d+$').hasMatch(cvv)) {
      return 'Please enter a valid 3 or 4 digit CVV.';
    }
    return null;
  }

  /// Process payment through the backend Stripe TEST Mode PaymentIntent flow.
  Future<void> _pay() async {
    if (_booking == null) return;

    // Validate form fields
    final validationError = _validateCardForm();
    if (validationError != null) {
      setState(() {
        _paymentMessage = validationError;
      });
      return;
    }

    // Backend rule: payment can only be processed if booking status is Confirmed (2)
    final currentStatus = _normalizeStatus(_booking!['status'] ?? _booking!['bookingStatus']);
    if (currentStatus != 2) {
      setState(() {
        _paymentMessage =
            'Payment cannot be processed. Booking status must be Confirmed (currently awaiting agent approval).';
      });
      return;
    }

    setState(() {
      _paying = true;
      _paymentMessage = null;
    });

    try {
      // These are Stripe's documented TEST-mode PaymentMethod fixtures. The
      // card number itself is never sent to the backend.
      final cleanCard = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
      final paymentMethodId = cleanCard.endsWith('0002')
          ? 'pm_card_chargeDeclined'
          : 'pm_card_visa';

      final result = await ApiService.createPayment({
        'bookingId': _booking!['id'] ?? 101,
        'paymentMethodId': paymentMethodId,
      });

      if (!mounted) return;

      final statusCode = result['statusCode'] ?? 0;
      final paymentStatus = result['status']?.toString().toLowerCase();
      final isSuccess = (statusCode == 200 || statusCode == 201) &&
          paymentStatus == 'paid' &&
          (result['stripeReference']?.toString().isNotEmpty ?? false);

      if (isSuccess) {
        // Carry only the server's successful payment result into confirmation.
        final updatedBooking = Map<String, dynamic>.from(_booking!);
        updatedBooking['paymentId'] = result['id'];
        updatedBooking['paymentStatus'] = result['status'];
        updatedBooking['stripeReference'] = result['stripeReference'];
        updatedBooking['customerName'] = _nameController.text.trim();

        Navigator.pushReplacementNamed(
          context,
          '/trip-confirmation',
          arguments: updatedBooking,
        );
      } else {
        // Payment failed or declined: STAY on checkout screen with clear error
        setState(() {
          _paymentMessage = result['failureReason'] ?? result['message'] ??
              'Stripe did not confirm the payment. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paymentMessage = 'Payment processing error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_error != null && _booking == null) {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Checkout',
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ErrorMessage(message: _error!),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final total = (_booking!['totalCost'] ??
            _booking!['totalEstimatedCost'] ??
            1712)
        .toDouble();
    final accommodationCost =
        (_booking!['accommodationCost'] ?? 1116).toDouble();
    final toursCost = (_booking!['toursCost'] ?? 218).toDouble();
    final transfersCost = (_booking!['transfersCost'] ?? 284).toDouble();
    final taxesCost = (_booking!['taxesCost'] ?? 94).toDouble();
    final tripTitle = _booking!['destination'] ?? 'Sri Lanka Discovery';
    final dates = _booking!['dates'] ?? '12–18 Oct 2026 · 2 travelers';
    final stops = _booking!['stops'] ?? 'Sigiriya · Kandy · Ella · Mirissa';

    final int status = _normalizeStatus(_booking!['status'] ?? _booking!['bookingStatus']);
    final bool isConfirmed = status == 2;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.colorScheme.onSurface,
                        size: 20,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Checkout',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Secure payment · Step 3 of 3',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF9EABA4)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Awaiting Approval Warning Banner ──
              if (!isConfirmed)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2415) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Awaiting Agent Approval',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your booking is currently pending review by a travel coordinator. Payment is unlocked once the booking is Confirmed.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/booking-status',
                                  arguments: _booking!['id'] ?? 101,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD97706)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Check Status',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // ── Trip Summary Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E3D36)
                        : AppColors.figmaCardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row with 4-grid collage thumbnail
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: GridView.count(
                              crossAxisCount: 2,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                Image.network(
                                  'https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1546708973-b339540b5162?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1588598198321-9735fd52455b?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tripTitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dates,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF9EABA4)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stops,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.leaf400
                                      : const Color(0xFF0F766E),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2E3D36)
                            : AppColors.figmaCardBorder,
                      ),
                    ),

                    // Cost breakdown items with selected hotel & transport awareness
                    _buildCostItem(
                      TripSelectionService.selectedHotel != null
                          ? 'Accommodation: ${TripSelectionService.selectedHotel!['name']}'
                          : '6-night accommodation',
                      accommodationCost,
                    ),
                    const SizedBox(height: 8),
                    _buildCostItem('Sigiriya & Kandy guided tours', toursCost),
                    const SizedBox(height: 8),
                    _buildCostItem(
                      TripSelectionService.selectedTransport != null
                          ? 'Transport: ${TripSelectionService.selectedTransport!['name'] ?? TripSelectionService.selectedTransport!['type']}'
                          : 'Private transfers + scenic train',
                      transfersCost,
                    ),
                    const SizedBox(height: 8),
                    _buildCostItem('Taxes & partner service fees', taxesCost),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF2E3D36)
                            : AppColors.figmaCardBorder,
                      ),
                    ),

                    // Total Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'USD · all taxes included',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF9EABA4)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.leaf400
                                : AppColors.figmaDarkGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Payment Method Header (Clean single card gateway) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment method',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE5F1EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stripe TEST Mode',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Clean Single Card Selector Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFEAF2EC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credit or Debit Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Visa, Mastercard, Amex supported',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                      size: 18,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── CARDHOLDER NAME ──
              _buildInputLabel('CARDHOLDER NAME'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _nameController,
                icon: Icons.person_outline,
                hintText: 'e.g. Maya Fernando',
              ),

              const SizedBox(height: 14),

              // ── CARD NUMBER ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInputLabel('CARD NUMBER'),
                  Text(
                    'Ends with 0002 to test decline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _cardNumberController,
                icon: Icons.credit_card_outlined,
                keyboardType: TextInputType.number,
                hintText: '4242 4242 4242 4242',
              ),

              const SizedBox(height: 14),

              // ── EXPIRY & CVV ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('EXPIRY'),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _expiryController,
                          icon: null,
                          hintText: 'MM / YY',
                          keyboardType: TextInputType.datetime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('CVV'),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _cvvController,
                          icon: null,
                          isPassword: true,
                          hintText: '123',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Security Guarantee Box ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF221F18)
                      : const Color(0xFFF6EED8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.figmaGold,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Protected payment. Free cancellation on eligible items up to 72h before departure.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFE5D7B5)
                              : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Payment message / Error alert
              if (_paymentMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C1616) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _paymentMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Confirm & Pay Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (!isConfirmed || _paying) ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.figmaDarkGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark
                        ? const Color(0xFF1D2B25)
                        : const Color(0xFFD1D5DB),
                    disabledForegroundColor: isDark
                        ? const Color(0xFF637C70)
                        : const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isConfirmed ? Icons.lock_outline : Icons.lock_clock,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isConfirmed
                                  ? 'Confirm & Pay \$${total.toStringAsFixed(0)}'
                                  : 'Payment Locked (Awaiting Approval)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
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

  Widget _buildCostItem(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9EABA4)
                  : const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '\$${amount.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.leaf400
                : AppColors.figmaDarkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF9EABA4)
            : const Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    IconData? icon,
    bool isPassword = false,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF637C70) : const Color(0xFF9CA3AF),
            fontSize: 13,
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: isDark
                      ? const Color(0xFF9EABA4)
                      : const Color(0xFF6B7280),
                  size: 18,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
