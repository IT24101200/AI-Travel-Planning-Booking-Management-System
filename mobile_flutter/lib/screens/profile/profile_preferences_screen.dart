import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';
import '../../main.dart' show themeNotifier, currencyNotifier;
import '../../services/currency_notifier.dart';

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
  String? _loadError;
  bool _profileMissing = false;
  bool _preferencesMissing = false;
  final _editFormKey = GlobalKey<FormState>();

  // Profile fields
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final String _homeCountry = 'Sri Lanka';
  int _tripCount = 0;

  // Travel preferences: Budget range (in LKR)
  double _budgetMin = 75000;
  double _budgetMax = 350000;
  String _currency = 'LKR';

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

  void _normalizeBudget() {
    _budgetMin = _budgetMin.isFinite ? _budgetMin.clamp(25000, 1000000).toDouble() : 25000;
    _budgetMax = _budgetMax.isFinite ? _budgetMax.clamp(25000, 1000000).toDouble() : 1000000;
    if (_budgetMax < _budgetMin) _budgetMax = _budgetMin;
  }

  String? _validateName(String? value) => value == null || value.trim().isEmpty ? 'Full name is required' : null;

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    if (value.trim().length != 10) return 'Must be exactly 10 digits';
    if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) return 'Only digits allowed';
    return null;
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _loadError = null; _profileMissing = false; });
    try {
      final profile = await ApiService.getProfile();
      if (!mounted) return;
      if (profile['statusCode'] == 204 || profile['statusCode'] == 404) {
        _profileMissing = true;
        return;
      }
      if (profile['statusCode'] != 200) throw ApiException(profile['message']?.toString() ?? 'Could not load your profile.');
      final prefResponse = await ApiService.getPreferences();
      if (!mounted) return;
      _nameCtrl.text = profile['fullName']?.toString() ?? '';
      _emailCtrl.text = profile['email']?.toString() ?? '';
      _phoneCtrl.text = profile['phone']?.toString() ?? '';
      _tripCount = (profile['tripCount'] as num?)?.toInt() ?? 0;
      _preferencesMissing = prefResponse.statusCode == 404 || prefResponse.statusCode == 204;
      if (!_preferencesMissing) {
        if (prefResponse.statusCode != 200) throw const ApiException('Could not load your preferences.');
        final pref = jsonDecode(prefResponse.body);
        if (pref == null || (pref is Map && pref.isEmpty)) {
          _preferencesMissing = true;
        } else if (pref is Map) {
          _budgetMin = (pref['budgetMin'] as num?)?.toDouble() ?? 75000;
          _budgetMax = (pref['budgetMax'] as num?)?.toDouble() ?? 350000;
          _currency = currencyNotifier.normalize(pref['currency']?.toString());
          currencyNotifier.setCurrency(_currency);
          _selectedInterests..clear()..addAll((pref['preferredActivities']?.toString() ?? '').split(',').map((value) => value.trim()).where((value) => value.isNotEmpty));
          final diet = pref['dietaryNotes']?.toString() ?? '';
          _selectedDietary = diet.isEmpty ? 'No restrictions' : _dietaryOptions.contains(diet) ? diet : 'Custom';
          _dietaryCustomCtrl.text = _selectedDietary == 'Custom' ? diet : '';
          final access = pref['accessibilityNotes']?.toString() ?? '';
          _selectedAccessibility = access.isEmpty ? 'None' : _accessibilityOptions.contains(access) ? access : 'Custom';
          _accessibilityCustomCtrl.text = _selectedAccessibility == 'Custom' ? access : '';
        } else {
          throw const ApiException('The server returned invalid preferences.');
        }
      }
      _normalizeBudget();
    } catch (error) {
      if (mounted) {
        if (error is ApiException && error.statusCode == 404) {
          _profileMissing = true;
        } else {
          _loadError = error.toString();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAllPreferences() async {
    if (_isSaving) return;
    final validationError = _validateName(_nameCtrl.text) ?? _validatePhone(_phoneCtrl.text);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }
    _normalizeBudget();
    setState(() => _isSaving = true);
    bool profileSaved = false;
    try {
      final profile = await ApiService.updateProfile({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (profile['statusCode'] != 200 && profile['statusCode'] != 204) {
        throw ApiException(profile['message']?.toString() ?? 'Could not save your profile.');
      }
      profileSaved = true;
      final prefRes = await ApiService.updatePreferences({
        'budgetMin': _budgetMin,
        'budgetMax': _budgetMax,
        'currency': _currency,
        'preferredActivities': _selectedInterests.join(', '),
        'dietaryNotes': _selectedDietary == 'Custom' ? _dietaryCustomCtrl.text.trim() : _selectedDietary,
        'accessibilityNotes': _selectedAccessibility == 'Custom' ? _accessibilityCustomCtrl.text.trim() : _selectedAccessibility,
      });
      if (prefRes.statusCode != 200 && prefRes.statusCode != 204) {
        throw const ApiException('Could not save your preferences.');
      }
      if (!mounted) return;
      currencyNotifier.setCurrency(_currency);
      setState(() => _preferencesMissing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile and travel preferences saved successfully!')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${profileSaved ? 'Profile saved, but preferences were not saved. ' : ''}$error'),
        action: SnackBarAction(label: 'Retry', onPressed: _saveAllPreferences),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    if (_loadError != null) {
      return Scaffold(body: ErrorMessage(message: _loadError!, onRetry: _loadData));
    }
    if (_profileMissing) {
      return Scaffold(body: EmptyState(icon: Icons.person_outline, message: 'No customer profile found.', actionLabel: 'Retry', onAction: _loadData));
    }

    final currencyFmt = NumberFormat('#,##0', 'en_US');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_preferencesMissing)
              const Padding(padding: EdgeInsets.all(16), child: Text('No saved preferences yet. Choose your preferences below.')),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Currency Selector Badge in Top Bar
                          InkWell(
                            onTap: _showCurrencyPicker,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.currency_exchange,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$_currency ▾',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          child: AppNetworkImage(
                            imageUrl: 'assets/photos/explore-hero.jpg',
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
                        Divider(height: 16, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E3D36) : const Color(0xFFE4E7E2)),
                        _buildAccountField(
                          icon: Icons.currency_exchange,
                          label: 'Preferred currency',
                          value: _currency == 'USD' ? 'US Dollar (USD · \$)' : 'Sri Lankan Rupee (LKR · Rs)',
                          onTap: _showCurrencyPicker,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Interactive Currency Switcher Chip
                          InkWell(
                            onTap: _showCurrencyPicker,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    size: 12,
                                    color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_currency ▾',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Range Display Badge
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
                              '$_currency ${currencyFmt.format(_budgetMin)} – ${currencyFmt.format(_budgetMax)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target spending comfort zone per traveler in ${_currency == 'USD' ? 'US Dollars' : 'Sri Lankan Rupees'}',
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
                                      formatMoney(_budgetMin, _currency),
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
                                      formatMoney(_budgetMax, _currency),
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
                              _budgetMin,
                              _budgetMax,
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

                  const SizedBox(height: 12),

                  // ── 7b. Preferred Currency Preference ──
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
                            color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE5F1EA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.currency_exchange,
                            color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preferred Currency',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currency == 'USD'
                                    ? 'US Dollar (USD · \$)'
                                    : 'Sri Lankan Rupee (LKR · Rs)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showCurrencyPicker,
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
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap ?? _showEditProfileModal,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
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

  /// Bottom sheet to select preferred currency (LKR / USD)
  void _showCurrencyPicker() {
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
                    'Preferred Currency',
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
              const SizedBox(height: 8),
              Text(
                'Select your preferred currency for trip pricing, bookings, and payments.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              _buildCurrencyOption(ctx, 'LKR', 'Sri Lankan Rupee (LKR · Rs)'),
              const SizedBox(height: 10),
              _buildCurrencyOption(ctx, 'USD', 'US Dollar (USD · \$)'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrencyOption(BuildContext ctx, String code, String label) {
    final isSelected = _currency == code;
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

    return GestureDetector(
      onTap: () {
        setState(() {
          _currency = code;
        });
        currencyNotifier.setCurrency(code);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Currency updated to $code'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.figmaDarkGreen,
          ),
        );
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.leaf400.withValues(alpha: 0.2) : const Color(0xFFCEE5D8))
                    : (isDark ? const Color(0xFF23332B) : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                code == 'USD' ? '\$' : 'Rs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen)
                      : (isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280)),
                ),
              ),
            ),
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

  /// Settings and app configuration dialog with quick Theme and Currency options
  void _showSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
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
                  'App Settings',
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
            // Currency option tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE5F1EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.currency_exchange,
                  color: isDark ? AppColors.leaf400 : AppColors.figmaDarkGreen,
                  size: 20,
                ),
              ),
              title: Text(
                'Currency Preference',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _currency == 'USD' ? 'US Dollar (USD · \$)' : 'Sri Lankan Rupee (LKR · Rs)',
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _showCurrencyPicker();
              },
            ),
            const Divider(),
            // Theme option tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2411) : const Color(0xFFF5F0E3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.brightness_6_outlined,
                  color: AppColors.figmaGold,
                  size: 20,
                ),
              ),
              title: Text(
                'Appearance Theme',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                themeNotifier.value == ThemeMode.light
                    ? 'Light'
                    : themeNotifier.value == ThemeMode.dark
                        ? 'Dark'
                        : 'System default',
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.pop(ctx);
                _showThemePicker();
              },
            ),
          ],
        ),
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
        child: Form(
          key: _editFormKey,
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
            TextFormField(
              validator: _validateName,
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
            TextFormField(
              validator: _validatePhone,
              keyboardType: TextInputType.phone,
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
                  if (!_editFormKey.currentState!.validate()) return;
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
      ),
    );
  }
}
