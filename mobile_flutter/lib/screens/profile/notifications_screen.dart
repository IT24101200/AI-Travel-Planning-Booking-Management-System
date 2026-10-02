import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

/// Notifications & Alerts screen connecting exclusively to the live database API.
/// Does not use dummy data — displays real database notification records for the logged-in customer.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Bookings', 'Payments', 'Info'];

  // Real alerts populated only from the database API
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseNotifications();
  }

  /// Fetch notifications strictly from the backend database
  Future<void> _loadDatabaseNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawList = await ApiService.getMyNotifications();

      final List<Map<String, dynamic>> parsedList = [];

      for (final raw in rawList) {
        if (raw is! Map<String, dynamic>) continue;

        final id = raw['id']?.toString() ?? '';
        final content = raw['content']?.toString() ?? '';
        final messageType = raw['messageType']?.toString() ?? 'SystemAlert';
        final status = raw['status']?.toString() ?? 'Sent';
        final isUnread = status.toLowerCase() != 'read';
        final sentAtRaw = raw['sentAt']?.toString() ?? '';
        final DateTime? sentAt = DateTime.tryParse(sentAtRaw);

        // Map database message type to visual category and styling
        String tag = 'INFO';
        Color tagColor = const Color(0xFF0E382C);
        String category = 'Info';
        IconData icon = Icons.notifications_outlined;
        Color iconColor = const Color(0xFF0E382C);
        String defaultTitle = 'Notification';

        switch (messageType.toLowerCase()) {
          case 'bookingconfirmation':
            tag = 'BOOKING';
            tagColor = const Color(0xFF13684B);
            category = 'Bookings';
            icon = Icons.check_circle_outline;
            iconColor = const Color(0xFF13684B);
            defaultTitle = 'Booking Confirmed';
            break;
          case 'paymentreceipt':
            tag = 'PAYMENT';
            tagColor = const Color(0xFF1D6F8A);
            category = 'Payments';
            icon = Icons.credit_card_outlined;
            iconColor = const Color(0xFF1D6F8A);
            defaultTitle = 'Payment Successful';
            break;
          case 'systemalert':
            tag = 'ALERT';
            tagColor = const Color(0xFFB27D26);
            category = 'Info';
            icon = Icons.wb_sunny_outlined;
            iconColor = const Color(0xFFB27D26);
            defaultTitle = 'Travel Alert';
            break;
          case 'tripupdate':
            tag = 'AI TRIP';
            tagColor = const Color(0xFFD4A346);
            category = 'Info';
            icon = Icons.auto_awesome;
            iconColor = const Color(0xFFD4A346);
            defaultTitle = 'Itinerary Update';
            break;
          case 'reminder':
            tag = 'TRANSIT';
            tagColor = const Color(0xFF0E382C);
            category = 'Bookings';
            icon = Icons.directions_subway_outlined;
            iconColor = const Color(0xFF0E382C);
            defaultTitle = 'Transit Reminder';
            break;
          case 'promotion':
            tag = 'PROMO';
            tagColor = const Color(0xFF9E4B28);
            category = 'Info';
            icon = Icons.local_offer_outlined;
            iconColor = const Color(0xFF9E4B28);
            defaultTitle = 'Special Offer';
            break;
        }

        // Split title and body if database content contains a colon header
        String title = defaultTitle;
        String body = content;
        if (content.contains(': ')) {
          final parts = content.split(': ');
          title = parts.first.trim();
          body = parts.sublist(1).join(': ').trim();
        }

        parsedList.add({
          'id': id,
          'tag': tag,
          'tagColor': tagColor,
          'time': _formatRelativeTime(sentAt),
          'isUnread': isUnread,
          'icon': icon,
          'iconColor': iconColor,
          'title': title,
          'body': body,
          'category': category,
        });
      }

      if (mounted) {
        setState(() {
          _alerts = parsedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load alerts from database.';
        });
      }
    }
  }

  /// Format timestamp into friendly relative time string
  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return 'Recent';
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Mark all alerts as read in database and UI
  Future<void> _markAllAsRead() async {
    setState(() {
      for (final a in _alerts) {
        a['isUnread'] = false;
      }
    });

    try {
      await ApiService.markAllNotificationsRead();
    } catch (_) {}
  }

  /// Mark single alert as read on tap
  Future<void> _markSingleAsRead(Map<String, dynamic> item) async {
    if (item['isUnread'] != true) return;

    setState(() {
      item['isUnread'] = false;
    });

    final id = item['id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        await ApiService.markNotificationRead(id);
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_selectedCategory == 'All') return _alerts;
    return _alerts.where((a) => a['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => a['isUnread'] == true).length;
    final displayList = _filteredAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0E382C),
          backgroundColor: Colors.white,
          onRefresh: _loadDatabaseNotifications,
          child: Column(
            children: [
              // ── Top Header Row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerts',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF08201A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isLoading
                              ? 'Checking database...'
                              : '$unreadCount new updates',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9E96),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Double check circular button (Mark All Read)
                    GestureDetector(
                      onTap: _alerts.isEmpty ? null : _markAllAsRead,
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
                        child: Center(
                          child: Icon(
                            Icons.done_all,
                            color: _alerts.any((a) => a['isUnread'] == true)
                                ? const Color(0xFF0E382C)
                                : const Color(0xFF9E9E9E),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Filter Chips ──
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0E382C) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0E382C) : const Color(0xFFEDECE4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // ── Recent updates label & Mark all read ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent updates',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF08201A),
                      ),
                    ),
                    if (_alerts.any((a) => a['isUnread'] == true))
                      GestureDetector(
                        onTap: _markAllAsRead,
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E382C),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Content Area: Loading / Error / Empty / List ──
              Expanded(
                child: _buildContent(displayList),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> displayList) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0E382C)),
            SizedBox(height: 14),
            Text(
              'Loading database alerts...',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A9E96), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFFE27D60)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF08201A)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadDatabaseNotifications,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E382C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (displayList.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEFAF4),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.notifications_none_outlined, size: 36, color: Color(0xFF0E382C)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedCategory == 'All'
                    ? 'No alerts in database'
                    : 'No $_selectedCategory alerts',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF08201A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Live notifications, booking approvals, payment receipts, and travel notices from the database will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF8A9E96),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _loadDatabaseNotifications,
                icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF0E382C)),
                label: const Text(
                  'Refresh',
                  style: TextStyle(color: Color(0xFF0E382C), fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0E382C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final item = displayList[index];
        return _buildAlertCard(item);
      },
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> item) {
    final isUnread = item['isUnread'] == true;
    final tag = item['tag'] ?? 'INFO';
    final Color tagColor = item['tagColor'] ?? const Color(0xFF0E382C);
    final time = item['time'] ?? 'Just now';
    final IconData icon = item['icon'] ?? Icons.notifications_outlined;
    final Color iconColor = item['iconColor'] ?? const Color(0xFF0E382C);
    final title = item['title'] ?? 'Notification';
    final body = item['body'] ?? '';

    return GestureDetector(
      onTap: () => _markSingleAsRead(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFF0F8F5) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnread ? const Color(0xFFD9F4E7) : const Color(0xFFEDECE4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon rounded container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDECE4)),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag & Time Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: tagColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            time,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E96)),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4A346),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF08201A),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Body text
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.4,
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
}
