import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Checkout and payment screen matching Figma Dev Mode (11 · Checkout & Payment).
class CheckoutPaymentScreen extends StatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  Map<String, dynamic>? _booking;
  bool _paying = false;
  int _selectedMethod = 0; // 0: Card, 1: Wallet
  bool _saveCard = true;

  final _cardholderCtrl = TextEditingController(text: 'MAYA FERNANDO');
  final _cardNumberCtrl = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryCtrl = TextEditingController(text: '10 / 29');
  final _cvvCtrl = TextEditingController(text: '883');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _booking = args;
    }
  }

  @override
  void dispose() {
    _cardholderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() {
      _paying = true;
    });

    try {
      if (_booking != null && _booking!['id'] != null) {
        await ApiService.createPayment({
          'bookingId': _booking!['id'],
          'amount': 1712,
          'currency': 'USD',
          'stripeToken': 'tok_visa',
        });
      }
    } catch (_) {
      // Continue to confirmation in demo / offline mode
    }

    if (!mounted) return;
    setState(() => _paying = false);

    Navigator.pushReplacementNamed(
      context,
      '/trip-confirmation',
      arguments: _booking ?? {
        'id': 284619,
        'bookingReference': 'ST-284619',
        'title': 'Sri Lanka Discovery',
        'dates': '12–18 October 2026',
        'duration': '7 days / 6 nights',
        'travelers': 'Maya Fernando + 1 guest',
        'hotel': 'Heritance Kandalama + 2 stays',
        'transport': 'Private car + reserved train',
        'destinations': 'Sigiriya · Kandy · Ella · Mirissa',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back, color: Color(0xFF1E1E1E), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checkout',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Secure payment · Step 3 of 3',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEDECE4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.lock_outline, color: Color(0xFF1E1E1E), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Checkout Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trip Summary Invoice Card
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEDECE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // 4-Image Grid Collage Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: GridView.count(
                                    crossAxisCount: 2,
                                    physics: const NeverScrollableScrollPhysics(),
                                    children: [
                                      Image.asset(AppDestinations.heroSigiriya, fit: BoxFit.cover),
                                      Image.asset(AppDestinations.featured[0].imageUrl, fit: BoxFit.cover),
                                      Image.asset(AppDestinations.featured[1].imageUrl, fit: BoxFit.cover),
                                      Image.asset(AppDestinations.featured[2].imageUrl, fit: BoxFit.cover),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sri Lanka Discovery',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF08201A),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '12–18 Oct 2026 · 2 travelers',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF8A9E96),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Sigiriya · Kandy · Ella · Mirissa',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1B6B5D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(height: 1, color: const Color(0xFFEDECE4)),
                          const SizedBox(height: 12),

                          _buildCostRow('6-night accommodation', '\$1,116'),
                          const SizedBox(height: 8),
                          _buildCostRow('Sigiriya & Kandy tours', '\$218'),
                          const SizedBox(height: 8),
                          _buildCostRow('Private transfers + train', '\$284'),
                          const SizedBox(height: 8),
                          _buildCostRow('Taxes & partner fees', '\$94'),

                          const SizedBox(height: 14),
                          Container(height: 1, color: const Color(0xFFEDECE4)),
                          const SizedBox(height: 12),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF08201A),
                                    ),
                                  ),
                                  Text(
                                    'USD · taxes included',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF8A9E96),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '\$1,712',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0E382C),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment Method Section Title
                    const Text(
                      'Payment method',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2 Options: Card and Wallet
                    Row(
                      children: [
                        // Card Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMethod = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedMethod == 0 ? const Color(0xFFEEFAF4) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedMethod == 0 ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                  width: _selectedMethod == 0 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedMethod == 0 ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                        width: _selectedMethod == 0 ? 4.5 : 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.credit_card, size: 18, color: Color(0xFF0E382C)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Card',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF08201A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Wallet Option
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedMethod = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedMethod == 1 ? const Color(0xFFEEFAF4) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedMethod == 1 ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                  width: _selectedMethod == 1 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedMethod == 1 ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                        width: _selectedMethod == 1 ? 4.5 : 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Wallet',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF08201A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Cardholder Name
                    const Text(
                      'CARDHOLDER NAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _cardholderCtrl,
                      icon: Icons.person_outline,
                      hint: 'MAYA FERNANDO',
                    ),

                    const SizedBox(height: 14),

                    // Card Number
                    const Text(
                      'CARD NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _cardNumberCtrl,
                      icon: Icons.credit_card_outlined,
                      hint: '4242 4242 4242 4242',
                    ),

                    const SizedBox(height: 14),

                    // Expiry & CVV
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'EXPIRY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInputField(
                                controller: _expiryCtrl,
                                hint: '10 / 29',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CVV',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInputField(
                                controller: _cvvCtrl,
                                hint: '•••',
                                obscureText: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Save Card Checkbox
                    GestureDetector(
                      onTap: () => setState(() => _saveCard = !_saveCard),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _saveCard ? const Color(0xFF0E382C) : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _saveCard ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                                width: 1.5,
                              ),
                            ),
                            child: _saveCard
                                ? const Center(
                                    child: Icon(Icons.check, size: 14, color: Colors.white),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Save this card securely for future bookings',
                            style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Shield Info Banner (Soft sand)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EED8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFFB27D26), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Protected payment. Free cancellation on eligible items until 8 October.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF08201A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm & Pay Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _paying ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E382C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _paying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline, size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm & Pay \$1,712',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String title, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF08201A),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    IconData? icon,
    required String hint,
    bool obscureText = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDECE4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFF8A9E96), size: 19),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF08201A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
