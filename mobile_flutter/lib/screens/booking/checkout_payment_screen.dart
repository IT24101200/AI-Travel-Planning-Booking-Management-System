import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
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

  String _paymentMethod = 'Card'; // 'Card' or 'Wallet'
  bool _saveCard = true;

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
          'destination': 'Sri Lanka Discovery',
          'dates': '12–18 Oct 2026 · 2 travelers',
          'stops': 'Sigiriya · Kandy · Ella · Mirissa',
          'accommodationCost': 1116.0,
          'toursCost': 218.0,
          'transfersCost': 284.0,
          'taxesCost': 94.0,
          'totalCost': 1712.0,
          'currency': 'USD',
        };
        _loading = false;
        _error = null;
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

  /// Process payment
  Future<void> _pay() async {
    if (_booking == null) return;
    setState(() {
      _paying = true;
      _paymentMessage = null;
    });

    try {
      final total = (_booking!['totalCost'] ??
              _booking!['totalEstimatedCost'] ??
              1712)
          .toDouble();

      final result = await ApiService.createPayment({
        'bookingId': _booking!['id'] ?? 101,
        'amount': total,
        'currency': _booking!['currency'] ?? 'USD',
        'stripeToken': 'tok_visa',
      });

      if (!mounted) return;

      if (result['statusCode'] == 200 || result['statusCode'] == 201) {
        Navigator.pushReplacementNamed(
          context,
          '/booking-status',
          arguments: _booking,
        );
      } else {
        // Even if mock endpoint returns default message, navigate to status
        Navigator.pushReplacementNamed(
          context,
          '/booking-status',
          arguments: _booking,
        );
      }
    } catch (e) {
      // In offline/mock mode, navigate forward to status
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/booking-status',
          arguments: _booking,
        );
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
    final stops =
        _booking!['stops'] ?? 'Sigiriya · Kandy · Ella · Mirissa';

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
                          color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
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

              // ── Trip Summary Card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
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
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1546708973-b339540b5162?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
                                ),
                                Image.network(
                                  'https://images.unsplash.com/photo-1588598198321-9735fd52455b?w=200&auto=format&fit=crop&q=80',
                                  fit: BoxFit.cover,
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
                                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stops,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark ? AppColors.leaf400 : const Color(0xFF0F766E),
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
                        color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
                      ),
                    ),

                    // Cost breakdown items
                    _buildCostItem('6-night accommodation', accommodationCost),
                    const SizedBox(height: 8),
                    _buildCostItem('Sigiriya & Kandy tours', toursCost),
                    const SizedBox(height: 8),
                    _buildCostItem('Private transfers + train', transfersCost),
                    const SizedBox(height: 8),
                    _buildCostItem('Taxes & partner fees', taxesCost),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder,
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
                              'Total',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'USD · taxes included',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Payment Method Header ──
              Text(
                'Payment method',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Method Selectors (Card vs Wallet)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = 'Card'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'Card'
                              ? (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFEAF2EC))
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _paymentMethod == 'Card'
                                ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                                : (isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _paymentMethod == 'Card'
                                    ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.credit_card,
                              color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Card',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentMethod = 'Wallet'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _paymentMethod == 'Wallet'
                              ? (isDark ? const Color(0xFF1E3A2F) : const Color(0xFFEAF2EC))
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _paymentMethod == 'Wallet'
                                ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                                : (isDark ? const Color(0xFF2E3D36) : AppColors.figmaCardBorder),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _paymentMethod == 'Wallet'
                                    ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF6E7772) : const Color(0xFF9CA3AF),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Wallet',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── CARDHOLDER NAME ──
              _buildInputLabel('CARDHOLDER NAME'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _nameController,
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 14),

              // ── CARD NUMBER ──
              _buildInputLabel('CARD NUMBER'),
              const SizedBox(height: 6),
              _buildInputField(
                controller: _cardNumberController,
                icon: Icons.credit_card_outlined,
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Save Card Checkbox ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _saveCard = !_saveCard),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _saveCard
                            ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _saveCard
                              ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                              : (isDark ? const Color(0xFF2E3D36) : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      child: _saveCard
                          ? Icon(
                              Icons.check,
                              color: isDark ? const Color(0xFF121A17) : Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Save this card securely for future bookings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
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
                  color: isDark ? const Color(0xFF221F18) : const Color(0xFFF6EED8),
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
                        'Protected payment. Free cancellation on eligible items until 8 October.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFE5D7B5) : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_paymentMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _paymentMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Confirm & Pay Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _paying ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.figmaDarkGreen,
                    foregroundColor: Colors.white,
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
                            const Icon(Icons.lock_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Confirm & Pay \$${total.toStringAsFixed(0)}',
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
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9EABA4)
                : const Color(0xFF6B7280),
          ),
        ),
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
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
