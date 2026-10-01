import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Profile & Preferences screen with cards, travel settings, and secure logout.
class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  bool _loading = true;
  String? _error;
  String? _successMsg;

  // Profile fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Preference fields
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _activitiesCtrl = TextEditingController();
  final _dietaryCtrl = TextEditingController();
  final _accessibilityCtrl = TextEditingController();
  final String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load profile and preferences from backend
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load profile
      final profile = await ApiService.getProfile();
      if (profile['statusCode'] == 200) {
        _nameCtrl.text = profile['fullName'] ?? '';
        _emailCtrl.text = profile['email'] ?? '';
        _phoneCtrl.text = profile['phone'] ?? '';
      }

      // Load preferences
      final prefResponse = await ApiService.getPreferences();
      if (prefResponse.statusCode == 200) {
        final pref = jsonDecode(prefResponse.body);
        _budgetMinCtrl.text = (pref['budgetMin'] ?? 200).toString();
        _budgetMaxCtrl.text = (pref['budgetMax'] ?? 2000).toString();
        _activitiesCtrl.text =
            pref['preferredActivities'] ?? 'Hiking, Wildlife, UNESCO Heritage';
        _dietaryCtrl.text = pref['dietaryNotes'] ?? '';
        _accessibilityCtrl.text = pref['accessibilityNotes'] ?? '';
      }
    } catch (e) {
      _error = 'Failed to load profile data';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Save profile changes
  Future<void> _saveProfile() async {
    setState(() => _successMsg = null);
    try {
      final res = await ApiService.updateProfile({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (res['statusCode'] == 200 || res['statusCode'] == 204) {
        setState(() => _successMsg = 'Profile updated successfully!');
      } else {
        setState(() => _error = 'Failed to update profile');
      }
    } catch (_) {
      setState(() => _error = 'Connection error updating profile');
    }
  }

  /// Save preference changes
  Future<void> _savePreferences() async {
    setState(() => _successMsg = null);
    try {
      final res = await ApiService.updatePreferences({
        'budgetMin': double.tryParse(_budgetMinCtrl.text) ?? 0,
        'budgetMax': double.tryParse(_budgetMaxCtrl.text) ?? 0,
        'currency': _currency,
        'preferredActivities': _activitiesCtrl.text.trim(),
        'dietaryNotes': _dietaryCtrl.text.trim(),
        'accessibilityNotes': _accessibilityCtrl.text.trim(),
      });
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() => _successMsg = 'Travel preferences updated!');
      } else {
        setState(() => _error = 'Failed to save preferences');
      }
    } catch (_) {
      setState(() => _error = 'Connection error saving preferences');
    }
  }

  /// Logout and clear token
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text(
          'Are you sure you want to log out of Serendib Trails?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coral500,
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/landing',
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _activitiesCtrl.dispose();
    _dietaryCtrl.dispose();
    _accessibilityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'ST';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading your preferences...')
          : _error != null
          ? ErrorMessage(message: _error!, onRetry: _loadData)
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Profile Header Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.jungle800,
                      image: DecorationImage(
                        image: const AssetImage(AppDestinations.heroSigiriya),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          AppColors.jungle900.withValues(alpha: 0.85),
                          BlendMode.srcOver,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.sand500,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.jungle900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nameCtrl.text.isNotEmpty
                              ? _nameCtrl.text
                              : 'Travel Enthusiast',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _emailCtrl.text,
                          style: const TextStyle(
                            color: AppColors.sand200,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Serendib Customer • Verified',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Success message
                  if (_successMsg != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.leaf50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.jungle600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.jungle600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMsg!,
                              style: const TextStyle(
                                color: AppColors.jungle700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Personal Info Card ──
                        _buildSectionCard(
                          title: 'Personal Information',
                          icon: Icons.person_outline,
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Email Address (Identity)',
                                prefixIcon: Icon(
                                  Icons.mail_outline,
                                  color: AppColors.ink3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 15,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: AppColors.jungle600,
                                ),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.jungle600,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Save Profile Details'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Travel Preferences Card ──
                        _buildSectionCard(
                          title: 'AI Travel Preferences',
                          icon: Icons.tune,
                          children: [
                            const Text(
                              'Budget Range Per Trip (USD)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _budgetMinCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Min Budget',
                                      prefixText: '\$ ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _budgetMaxCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Max Budget',
                                      prefixText: '\$ ',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _activitiesCtrl,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Preferred Activity Types',
                                hintText:
                                    'Hiking, Wildlife, Beach, Scenic Rail',
                                prefixIcon: Icon(
                                  Icons.sports_handball_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _dietaryCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Dietary Preferences',
                                hintText:
                                    'e.g., Vegetarian, Halal, Gluten-Free',
                                prefixIcon: Icon(
                                  Icons.restaurant_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _accessibilityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Accessibility Notes',
                                hintText:
                                    'e.g., Ground-floor rooms, easy stairs',
                                prefixIcon: Icon(
                                  Icons.accessible_outlined,
                                  color: AppColors.jungle600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _savePreferences,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.ocean500,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Save Travel Preferences'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── View Landing Page ──
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/landing'),
                            icon: const Icon(
                              Icons.travel_explore,
                              color: AppColors.jungle600,
                              size: 20,
                            ),
                            label: const Text(
                              'Explore Welcome Landing Page',
                              style: TextStyle(
                                color: AppColors.jungle600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Logout Action ──
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(
                              Icons.logout,
                              color: AppColors.coral500,
                            ),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppColors.coral500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.coral500),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(icon, color: AppColors.jungle600, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.line),
          ...children,
        ],
      ),
    );
  }
}
