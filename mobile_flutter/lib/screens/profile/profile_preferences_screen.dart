import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Profile & Preferences screen with edit forms and logout.
class ProfilePreferencesScreen extends StatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  State<ProfilePreferencesScreen> createState() => _ProfilePreferencesScreenState();
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
  String _currency = 'USD';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load profile and preferences from backend
  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
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
        _budgetMinCtrl.text = (pref['budgetMin'] ?? 0).toString();
        _budgetMaxCtrl.text = (pref['budgetMax'] ?? 0).toString();
        _currency = pref['currency'] ?? 'USD';
        _activitiesCtrl.text = pref['preferredActivities'] ?? '';
        _dietaryCtrl.text = pref['dietaryNotes'] ?? '';
        _accessibilityCtrl.text = pref['accessibilityNotes'] ?? '';
      }
    } catch (e) {
      _error = 'Failed to load profile';
    }
    if (mounted) setState(() { _loading = false; });
  }

  /// Save profile changes
  Future<void> _saveProfile() async {
    setState(() { _successMsg = null; });
    try {
      await ApiService.updateProfile({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      setState(() { _successMsg = 'Profile updated!'; });
    } catch (e) {
      setState(() { _error = 'Failed to update profile'; });
    }
  }

  /// Save preference changes
  Future<void> _savePreferences() async {
    setState(() { _successMsg = null; });
    try {
      await ApiService.updatePreferences({
        'budgetMin': double.tryParse(_budgetMinCtrl.text) ?? 0,
        'budgetMax': double.tryParse(_budgetMaxCtrl.text) ?? 0,
        'currency': _currency,
        'preferredActivities': _activitiesCtrl.text.trim(),
        'dietaryNotes': _dietaryCtrl.text.trim(),
        'accessibilityNotes': _accessibilityCtrl.text.trim(),
      });
      setState(() { _successMsg = 'Preferences saved!'; });
    } catch (e) {
      setState(() { _error = 'Failed to save preferences'; });
    }
  }

  /// Logout and clear token
  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading profile...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadData)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Success message
                      if (_successMsg != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_successMsg!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.green.shade700)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Profile Section ──
                      const Text('Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          child: const Text('Save Profile'),
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      // ── Preferences Section ──
                      const Text('Travel Preferences',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
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
                          const SizedBox(width: 16),
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _activitiesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Activities',
                          hintText: 'e.g., Hiking, Beach, Cultural tours',
                          prefixIcon: Icon(Icons.sports_handball),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dietaryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dietary Notes',
                          hintText: 'e.g., Vegetarian, Halal',
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _accessibilityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Accessibility Notes',
                          hintText: 'e.g., Wheelchair access needed',
                          prefixIcon: Icon(Icons.accessible),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savePreferences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CFC),
                          ),
                          child: const Text('Save Preferences'),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Logout button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Logout', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
