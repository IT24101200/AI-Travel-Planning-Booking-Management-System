import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Serendib Trails login screen with scenic backdrop and modern authentication card.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _submitted = false;

  Future<void> _login() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result = await ApiService.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (result['statusCode'] == 200) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          final serverMsg = result['message']?.toString() ?? '';
          if (result['statusCode'] == 401 || result['statusCode'] == 404) {
            _error = serverMsg.isNotEmpty && !serverMsg.toLowerCase().contains('validation failed')
                ? serverMsg
                : 'Invalid email or password. No account found matching these credentials.';
          } else if (serverMsg.isNotEmpty) {
            _error = serverMsg;
          } else {
            _error = 'Login failed. Please check your credentials or register a new account.';
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to connect to the server. Please check your network connection.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A120E) : AppColors.figmaDarkGreen,
      body: Stack(
        children: [
          // ── Hero Background Image & Branding ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppDestinations.heroSigiriya,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: AppColors.figmaDarkGreen),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        (isDark ? const Color(0xFF0A120E) : AppColors.figmaDarkGreen).withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: AppColors.figmaGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Serendib Trails',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'AI JOURNEYS · SRI LANKA',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'YOUR ISLAND AWAITS',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.figmaGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Welcome\nback,\ntraveller',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Curved Content Sheet ──
          Positioned.fill(
            top: 230,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141F1B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Access your saved journeys, bookings and AI itineraries.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message banner if any
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C1616) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/register'),
                                      child: Text(
                                        'New to Serendib? Create an account here →',
                                        style: TextStyle(
                                          color: isDark ? AppColors.figmaGold : const Color(0xFFB45309),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Email field
                      Text(
                        'Email address',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE0EDE6) : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1D2B25) : const Color(0xFFF9FAFB),
                          prefixIcon: Icon(
                            Icons.mail_outline,
                            color: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          hintText: 'maya@serendib.com',
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF637C70) : const Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your email address';
                          }
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(val.trim())) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Password field
                      Text(
                        'Password',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE0EDE6) : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        cursorColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1D2B25) : const Color(0xFFF9FAFB),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF637C70) : const Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFEF4444),
                              width: 1.2,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 1.5,
                            ),
                          ),
                          errorStyle: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (val.length < 6) {
                            return 'Password must contain at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: isDark
                                    ? const Color(0xFF1D2B25)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.lock_reset,
                                      color: AppColors.figmaGold,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Password Recovery',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'Password reset is managed through Serendib Support. Please contact support@serendibtrails.lk or your travel coordinator for credential recovery.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: Text(
                                      'Understood',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.leaf400
                                            : AppColors.figmaDarkGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.leaf400 : const Color(0xFF166B4F),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                            foregroundColor: isDark ? const Color(0xFF06231B) : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _loading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? const Color(0xFF06231B) : Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 18,
                                      color: isDark ? const Color(0xFF06231B) : Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sign In',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF06231B) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Create Account row
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/register');
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF4B5563),
                              ),
                              children: [
                                const TextSpan(text: 'New to Serendib? '),
                                TextSpan(
                                  text: 'Create an account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.leaf400 : const Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Security reassurance box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF192520) : const Color(0xFFE8F3EE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFD1E7DD),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: isDark ? AppColors.leaf400 : const Color(0xFF166B4F),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Secure sign-in protects your preferences, tickets and payment details.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFC7D0CB) : const Color(0xFF2D4B3E),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
