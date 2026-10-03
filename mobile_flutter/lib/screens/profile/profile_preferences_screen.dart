import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Profile & Preferences screen matching Figma frame 14 · Profile & Preferences (node 7:11179)
class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  bool _loading = true;

  // Profile fields
  final _nameCtrl = TextEditingController(text: 'Maya Fernando');
  final _emailCtrl = TextEditingController(text: 'maya@serendib.com');
  final _phoneCtrl = TextEditingController(text: '+94 77 123 4567');
  final String _homeCountry = 'Sri Lanka';

  // Notification toggle
  bool _tripNotifications = true;

  // Travel interests
  final Set<String> _selectedInterests = {
    'Culture',
    'Wildlife',
    'Food',
    'Beaches',
  };

  final List<Map<String, dynamic>> _interestOptions = [
    {'label': 'Culture', 'icon': Icons.account_balance_outlined},
    {'label': 'Wildlife', 'icon': Icons.pets_outlined},
    {'label': 'Hiking', 'icon': Icons.terrain_outlined},
    {'label': 'Food', 'icon': Icons.restaurant_outlined},
    {'label': 'Beaches', 'icon': Icons.waves_outlined},
    {'label': 'Wellness', 'icon': Icons.spa_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// Load profile and preferences from backend
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    try {
      final profile = await ApiService.getProfile();
      if (profile['statusCode'] == 200) {
        if ((profile['fullName'] ?? '').toString().isNotEmpty) {
          _nameCtrl.text = profile['fullName'];
        }
        if ((profile['email'] ?? '').toString().isNotEmpty) {
          _emailCtrl.text = profile['email'];
        }
        if ((profile['phone'] ?? '').toString().isNotEmpty) {
          _phoneCtrl.text = profile['phone'];
        }
      }

      final prefResponse = await ApiService.getPreferences();
      if (prefResponse.statusCode == 200) {
        final pref = jsonDecode(prefResponse.body);
        final acts = pref['preferredActivities']?.toString() ?? '';
        if (acts.isNotEmpty) {
          final parts = acts.split(',').map((e) => e.trim()).toSet();
          if (parts.isNotEmpty) {
            _selectedInterests.clear();
            _selectedInterests.addAll(parts);
          }
        }
      }
    } catch (_) {
      // Fallback to sample data on connection failure
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Save profile changes
  Future<void> _saveProfile() async {
    try {
      final res = await ApiService.updateProfile({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (res['statusCode'] == 200 || res['statusCode'] == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      }
    } catch (_) {}
  }

  /// Log out the user
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.figmaDarkGreen,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your Serendib account?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.figmaDarkGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.figmaSurface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.figmaDarkGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.figmaSurface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Deep Green Profile Header Banner ──
            Container(
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 10,
                18,
                20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF123F32),
              ),
              child: Column(
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Identity Row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.figmaGold,
                            width: 3,
                          ),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text
                                  : 'Maya Fernando',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _emailCtrl.text.isNotEmpty
                                  ? _emailCtrl.text
                                  : 'maya@serendib.com',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Gold Member Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.figmaGold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'TRAIL MEMBER · 6 TRIPS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF123F32),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit Button
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          onPressed: _showEditProfileModal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Main Content Area ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Details Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Account details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17211D),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showEditProfileModal,
                        child: Text(
                          'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2F7057),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Account Fields Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E7E2)),
                    ),
                    child: Column(
                      children: [
                        _buildAccountField(
                          icon: Icons.person_outline,
                          label: 'Full name',
                          value: _nameCtrl.text,
                        ),
                        const Divider(height: 16, color: Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: _emailCtrl.text,
                        ),
                        const Divider(height: 16, color: Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.phone_outlined,
                          label: 'Mobile',
                          value: _phoneCtrl.text,
                        ),
                        const Divider(height: 16, color: Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.public_outlined,
                          label: 'Home country',
                          value: _homeCountry,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Travel Interests Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Travel interests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17211D),
                        ),
                      ),
                      Text(
                        'Choose up to 6',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2F7057),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Interest Chips Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestOptions.map((opt) {
                      final label = opt['label'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = _selectedInterests.contains(label);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedInterests.remove(label);
                            } else {
                              _selectedInterests.add(label);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF123F32)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF123F32)
                                  : const Color(0xFFE4E7E2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF17211D),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF17211D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Notification Setting Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE4E7E2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6EBCB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.figmaGold,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trip notifications',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF17211D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Booking, weather and departure updates',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _tripNotifications,
                          onChanged: (val) {
                            setState(() => _tripNotifications = val);
                          },
                          activeTrackColor: const Color(0xFF123F32),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Log Out Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE4E7E2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_outlined,
                            size: 18,
                            color: Color(0xFF123F32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF123F32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F1EA),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF123F32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF17211D),
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
      ],
    );
  }


  void _showEditProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Account Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.figmaDarkGreen,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.figmaDarkGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
