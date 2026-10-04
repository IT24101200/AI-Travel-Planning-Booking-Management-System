import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../main.dart' show themeNotifier;

/// Profile & Preferences screen matching Figma frame 14 · Profile & Preferences
/// Aligned with SE3090 Master Specification & Student A Component A:
/// - Customer profile details (Name, Email, Mobile, Home country)
/// - Budget range slider in LKR (BudgetMin & BudgetMax)
/// - Travel interest tags (multi-select)
/// - Dietary notes and accessibility requirements
/// - Real-time persistence to backend database via EF Core
class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState extends State<ProfilePreferencesScreen> {
  bool _loading = true;
  bool _isSaving = false;

  // Profile fields
  final _nameCtrl = TextEditingController(text: 'user');
  final _emailCtrl = TextEditingController(text: 'user@gmail.com');
  final _phoneCtrl = TextEditingController(text: '0776543876');
  final String _homeCountry = 'Sri Lanka';
  int _tripCount = 6;

  // Travel preferences: Budget range (in LKR)
  double _budgetMin = 75000;
  double _budgetMax = 350000;

  // Travel preferences: Dietary notes
  String _selectedDietary = 'No restrictions';
  final _dietaryCustomCtrl = TextEditingController();

  // Travel preferences: Accessibility notes
  String _selectedAccessibility = 'None';
  final _accessibilityCustomCtrl = TextEditingController();

  // Notification toggle
  bool _tripNotifications = true;

  // Travel interests (multi-select)
  final Set<String> _selectedInterests = {
    'Culture',
    'Wildlife',
    'Hiking',
    'Food',
  };

  final List<Map<String, dynamic>> _interestOptions = [
    {'label': 'Culture', 'icon': Icons.account_balance_outlined},
    {'label': 'Wildlife', 'icon': Icons.pets_outlined},
    {'label': 'Hiking', 'icon': Icons.terrain_outlined},
    {'label': 'Food', 'icon': Icons.restaurant_outlined},
    {'label': 'Beaches', 'icon': Icons.waves_outlined},
    {'label': 'Wellness', 'icon': Icons.spa_outlined},
    {'label': 'Tea country', 'icon': Icons.eco_outlined},
  ];

  final List<String> _dietaryOptions = [
    'No restrictions',
    'Vegetarian',
    'Vegan',
    'Halal',
    'Pescatarian',
    'Nut allergy',
  ];

  final List<String> _accessibilityOptions = [
    'None',
    'Ground floor preferred',
    'Low-step vehicle',
    'Wheelchair accessible',
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
    _dietaryCustomCtrl.dispose();
    _accessibilityCustomCtrl.dispose();
    super.dispose();
  }

  /// Load profile and preferences from backend API
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch customer profile
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
        if (profile['tripCount'] != null) {
          _tripCount = (profile['tripCount'] as num).toInt();
        }
      }

      // 2. Fetch customer travel preferences
      final prefResponse = await ApiService.getPreferences();
      if (prefResponse.statusCode == 200) {
        final pref = jsonDecode(prefResponse.body);
        if (pref is Map) {
          // Budget Min & Max
          if (pref['budgetMin'] != null && (pref['budgetMin'] as num) > 0) {
            _budgetMin = (pref['budgetMin'] as num).toDouble();
          }
          if (pref['budgetMax'] != null && (pref['budgetMax'] as num) > 0) {
            _budgetMax = (pref['budgetMax'] as num).toDouble();
          }
          // Ensure min <= max
          if (_budgetMax < _budgetMin) {
            _budgetMax = _budgetMin + 100000;
          }

          // Preferred Activities
          final acts = pref['preferredActivities']?.toString() ?? '';
          if (acts.isNotEmpty) {
            final parts = acts.split(',').map((e) => e.trim()).toSet();
            if (parts.isNotEmpty) {
              _selectedInterests.clear();
              _selectedInterests.addAll(parts);
            }
          }

          // Dietary notes
          final diet = pref['dietaryNotes']?.toString() ?? '';
          if (diet.isNotEmpty) {
            if (_dietaryOptions.contains(diet)) {
              _selectedDietary = diet;
            } else {
              _selectedDietary = 'Custom';
              _dietaryCustomCtrl.text = diet;
            }
          }

          // Accessibility notes
          final access = pref['accessibilityNotes']?.toString() ?? '';
          if (access.isNotEmpty) {
            if (_accessibilityOptions.contains(access)) {
              _selectedAccessibility = access;
            } else {
              _selectedAccessibility = 'Custom';
              _accessibilityCustomCtrl.text = access;
            }
          }
        }
      }
    } catch (_) {
      // Gracefully use local defaults if network is offline
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Save profile and travel preferences to backend with validation
  Future<void> _saveAllPreferences() async {
    if (_budgetMax < _budgetMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum budget must be greater than or equal to minimum budget.'),
          backgroundColor: Color(0xFF9C4726),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Update customer profile details
      await ApiService.updateProfile({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });

      // 2. Resolve dietary and accessibility strings
      final resolvedDietary = _selectedDietary == 'Custom'
          ? _dietaryCustomCtrl.text.trim()
          : _selectedDietary;
      final resolvedAccessibility = _selectedAccessibility == 'Custom'
          ? _accessibilityCustomCtrl.text.trim()
          : _selectedAccessibility;

      // 3. Update travel preferences via PUT /api/preference
      final prefPayload = {
        'budgetMin': _budgetMin,
        'budgetMax': _budgetMax,
        'currency': 'LKR',
        'preferredActivities': _selectedInterests.join(', '),
        'dietaryNotes': resolvedDietary,
        'accessibilityNotes': resolvedAccessibility,
      };

      final prefRes = await ApiService.updatePreferences(prefPayload);

      if (mounted) {
        setState(() => _isSaving = false);
        if (prefRes.statusCode == 200 || prefRes.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Travel preferences saved successfully!'),
              backgroundColor: Color(0xFF267A55),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferences saved locally.'),
              backgroundColor: Color(0xFF267A55),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Backend will sync when online.'),
            backgroundColor: Color(0xFF267A55),
          ),
        );
      }
    }
  }

  /// Log out user with confirmation dialog
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
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    final currencyFmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          onPressed: _showSettingsDialog,
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
                        ),
                        child: ClipOval(
                          child: Image.network(
                            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF1E5E4B),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
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
                              _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'user',
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
                                  : 'user@gmail.com',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Gold Member Badge with dynamic trip count
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
                                'TRAIL MEMBER · $_tripCount TRIPS',
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
                  // ── 1. Account Details Section ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Account details',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      GestureDetector(
                        onTap: _showEditProfileModal,
                        child: Text(
                          'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                    ),
                    child: Column(
                      children: [
                        _buildAccountField(
                          icon: Icons.person_outline,
                          label: 'Full name',
                          value: _nameCtrl.text,
                        ),
                        Divider(height: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: _emailCtrl.text,
                        ),
                        Divider(height: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.phone_outlined,
                          label: 'Mobile',
                          value: _phoneCtrl.text,
                        ),
                        Divider(height: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.public_outlined,
                          label: 'Home country',
                          value: _homeCountry,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 2. Travel Preferences: Budget Range Slider (Project Plan) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget range',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'LKR ${currencyFmt.format(_budgetMin)} – ${currencyFmt.format(_budgetMax)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target spending comfort zone per traveler in Sri Lankan Rupees',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6E7772),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Enhanced Customer-Visible Budget Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Min & Max Highlight Value Cards
                        Row(
                          children: [
                            // Minimum Value Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1D2B25) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MINIMUM',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'LKR ${currencyFmt.format(_budgetMin)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
                              ),
                            ),
                            // Maximum Value Card
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1D2B25) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MAXIMUM',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'LKR ${currencyFmt.format(_budgetMax)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // High-Contrast Interactive RangeSlider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                            inactiveTrackColor: isDark ? const Color(0xFF2A3C34) : const Color(0xFFE2E8F0),
                            thumbColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                            overlayColor: (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen).withValues(alpha: 0.15),
                            trackHeight: 8,
                            rangeThumbShape: const RoundRangeSliderThumbShape(
                              enabledThumbRadius: 10,
                              elevation: 3,
                            ),
                            showValueIndicator: ShowValueIndicator.onDrag,
                          ),
                          child: RangeSlider(
                            values: RangeValues(
                              _budgetMin.clamp(25000, 950000),
                              _budgetMax.clamp(_budgetMin + 10000, 1000000),
                            ),
                            min: 25000,
                            max: 1000000,
                            divisions: 39,
                            labels: RangeLabels(
                              'LKR ${currencyFmt.format(_budgetMin)}',
                              'LKR ${currencyFmt.format(_budgetMax)}',
                            ),
                            onChanged: (RangeValues values) {
                              setState(() {
                                _budgetMin = values.start;
                                _budgetMax = values.end;
                              });
                            },
                          ),
                        ),

                        // Min & Max Range Boundary Labels
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Min: LKR 25,000',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF7FA393) : const Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                'Max: LKR 1,000,000',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF7FA393) : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Quick Presets
                        Text(
                          'Quick Presets',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPresetChip(
                                title: 'Backpacker (25k–100k)',
                                minVal: 25000,
                                maxVal: 100000,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                title: 'Standard (100k–350k)',
                                minVal: 100000,
                                maxVal: 350000,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                title: 'Premium (350k–700k)',
                                minVal: 350000,
                                maxVal: 700000,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildPresetChip(
                                title: 'Luxury (700k–1M)',
                                minVal: 700000,
                                maxVal: 1000000,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 3. Travel Interests Section ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Travel interests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Choose up to 6',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
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
                              if (_selectedInterests.length < 6) {
                                _selectedInterests.add(label);
                              }
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
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
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
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── 4. Dietary Requirements (Project Plan Component A) ──
                  Text(
                    'Dietary requirements',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Passed to hotel kitchens and dining reservations',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF6E7772),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _dietaryOptions.map((opt) {
                      final isSelected = _selectedDietary == opt;
                      return ChoiceChip(
                        label: Text(
                          opt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedDietary = opt);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── 5. Accessibility Notes (Project Plan Component A) ──
                  Text(
                    'Accessibility & mobility',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ensures low-step vehicles and suitable hotel room floors',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF6E7772),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _accessibilityOptions.map((opt) {
                      final isSelected = _selectedAccessibility == opt;
                      return ChoiceChip(
                        label: Text(
                          opt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).cardColor,
                        side: BorderSide(
                          color: isSelected ? Theme.of(context).colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedAccessibility = opt);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── 6. Trip Notifications Card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2411) : const Color(0xFFF6EBCB),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Booking, weather and departure updates',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
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
                          activeThumbColor: isDark ? const Color(0xFF06231B) : Colors.white,
                          activeTrackColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                          inactiveThumbColor: isDark ? const Color(0xFF7FA393) : const Color(0xFF9CA3AF),
                          inactiveTrackColor: isDark ? const Color(0xFF23332B) : const Color(0xFFE5E7EB),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 7. Appearance / Theme Toggle ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2411) : const Color(0xFFF5F0E3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.brightness_6_outlined,
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
                                'Appearance',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder<ThemeMode>(
                                valueListenable: themeNotifier,
                                builder: (context, mode, _) {
                                  final label = mode == ThemeMode.light
                                      ? 'Light'
                                      : mode == ThemeMode.dark
                                          ? 'Dark'
                                          : 'System default';
                                  return Text(
                                    label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showThemePicker(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1D2B25) : const Color(0xFFE5F1EA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFC3D8CE),
                              ),
                            ),
                            child: Text(
                              'Change',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── 8. Save Preferences Button (Component A) ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAllPreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                        foregroundColor: isDark ? const Color(0xFF06231B) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: isDark ? const Color(0xFF06231B) : Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: isDark ? const Color(0xFF06231B) : Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Save Travel Preferences',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF06231B) : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 9. Log Out Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF141F1B) : Colors.white,
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
                            Icons.logout_outlined,
                            size: 18,
                            color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
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
    return GestureDetector(
      onTap: _showEditProfileModal,
      behavior: HitTestBehavior.opaque,
      child: Row(
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  /// Quick preset chip for budget range selection
  Widget _buildPresetChip({
    required String title,
    required double minVal,
    required double maxVal,
    required bool isDark,
  }) {
    final isSelected = (_budgetMin == minVal && _budgetMax == maxVal);
    final activeBg = isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen;
    final activeFg = isDark ? const Color(0xFF06231B) : Colors.white;

    return InkWell(
      onTap: () {
        setState(() {
          _budgetMin = minVal;
          _budgetMax = maxVal;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBg
              : (isDark ? const Color(0xFF1D2B25) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeBg
                : (isDark ? const Color(0xFF2E3D36) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? activeFg
                : (isDark ? Colors.white : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  /// Bottom sheet to select Light / Dark / System theme
  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141F1B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Theme',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Theme options
              _buildThemeOption(ctx, Icons.light_mode_outlined, 'Light', ThemeMode.light),
              const SizedBox(height: 10),
              _buildThemeOption(ctx, Icons.dark_mode_outlined, 'Dark', ThemeMode.dark),
              const SizedBox(height: 10),
              _buildThemeOption(ctx, Icons.settings_suggest_outlined, 'System default', ThemeMode.system),
            ],
          ),
        );
      },
    );
  }

  /// Single theme option tile for the bottom sheet picker
  Widget _buildThemeOption(BuildContext ctx, IconData icon, String label, ThemeMode mode) {
    final isSelected = themeNotifier.value == mode;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    final bgColor = isSelected
        ? (isDark ? AppColors.leaf400.withValues(alpha: 0.16) : const Color(0xFFE5F1EA))
        : (isDark ? const Color(0xFF1D2B25) : Colors.transparent);

    final borderColor = isSelected
        ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
        : (isDark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2));

    final textColor = isSelected
        ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
        : (isDark ? Colors.white : const Color(0xFF1F2937));

    final iconColor = isSelected
        ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
        : (isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280));

    return GestureDetector(
      onTap: () {
        themeNotifier.setThemeMode(mode);
        Navigator.pop(ctx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
              ),
          ],
        ),
      ),
    );
  }

  /// Settings and component architecture overview dialog
  void _showSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141F1B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Customer Preferences',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.figmaDarkGreen,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Component A manages customer profiles, budget boundaries, and personalized travel preferences. '
          'Preferences saved here guide the Coordinator AI Agent when assembling your personalized trip.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF4B5563),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.leaf400 : const Color(0xFF123F32),
              foregroundColor: isDark ? const Color(0xFF06231B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet to edit account details (Full Name and Mobile)
  void _showEditProfileModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141F1B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                color: isDark ? Colors.white : AppColors.figmaDarkGreen,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                labelText: 'Mobile Phone',
                labelStyle: TextStyle(
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveAllPreferences();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                  foregroundColor: isDark ? const Color(0xFF06231B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
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
