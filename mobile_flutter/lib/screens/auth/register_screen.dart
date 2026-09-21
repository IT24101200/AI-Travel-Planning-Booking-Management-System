import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Serendib Trails registration screen with scenic backdrop and modern customer signup card.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.register(
        fullName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (result['statusCode'] == 201) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final errors = result['errors'];
        if (errors != null && errors is List) {
          setState(() => _error = errors.join('\n'));
        } else {
          setState(
            () => _error =
                result['message'] ?? 'Registration failed. Please try again.',
          );
        }
      }
    } catch (e) {
      setState(
        () => _error = 'Connection error. Check backend server on port 5138.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Scenic Background Image ──
          Image.asset(
            AppDestinations.featured[1].imageUrl, // Ella mountain viaduct
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: AppColors.jungle900),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.jungle900.withValues(alpha: 0.55),
                  AppColors.jungle900.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),

          // ── Register Form Card ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        size: 36,
                        color: AppColors.sand400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'START YOUR JOURNEY',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your Serendib customer account',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.sand200,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Plan, customize and book trips with AI assistance',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.ink3,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Error banner
                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.coral500.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.coral500.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.coral500,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: AppColors.coral500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Full Name
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Full name is required'
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Email
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Phone
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number (10 digits)',
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: AppColors.jungle600,
                                ),
                                hintText: '0771234567',
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Phone number is required';
                                }
                                if (v.length != 10) {
                                  return 'Must be exactly 10 digits';
                                }
                                if (!RegExp(r'^\d{10}$').hasMatch(v)) {
                                  return 'Only digits allowed';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Password
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: AppColors.jungle600,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.ink3,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.jungle600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Create Serendib Account',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Already have account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already registered? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.ink2,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.jungle600,
                                  ),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
