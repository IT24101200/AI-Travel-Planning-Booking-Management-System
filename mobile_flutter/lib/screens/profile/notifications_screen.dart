import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';

/// Notifications & Alerts Screen
/// Aligned with Component A (Customer Profile, Preferences, Notifications & Trip Requests)
/// Displays multi-channel alerts (Email, SMS, Push, In-App) with read/unread tracking,
/// category filtering, interactive detail bottom-sheet, and mark-all-read capability.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _updatingRead = false;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Unread', 'Bookings', 'Payments', 'Info'];

  // Alerts loaded from backend database API with graceful fallback
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadDatabaseNotifications();
  }

  /// Fetch notifications from the backend database (GET /api/notification/my)
  Future<void> _loadDatabaseNotifications() async {
    if (!mounted || _updatingRead) return;
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
        final channel = raw['channel']?.toString() ?? 'InApp';
        final status = raw['status']?.toString() ?? 'Sent';
        final readAtRaw = raw['readAt']?.toString();
        final isUnread = status.toLowerCase() != 'read' && (readAtRaw == null || readAtRaw.isEmpty);
        final sentAtRaw = raw['sentAt']?.toString() ?? '';
        final DateTime? sentAt = DateTime.tryParse(sentAtRaw);
        final DateTime? readAt = readAtRaw != null ? DateTime.tryParse(readAtRaw) : null;

        // Map database message type to visual category, tag, and icon
        String tag = 'INFO';
        Color tagColor = const Color(0xFF0E382C);
        String category = 'Info';
        IconData icon = Icons.notifications_outlined;
        Color iconColor = const Color(0xFF0E382C);
        String defaultTitle = 'Travel Alert';

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

        // Split title and body if database content contains a colon header (e.g. "Serendib Trails: ...")
        String title = defaultTitle;
        String body = content;
        if (content.contains(': ')) {
          final parts = content.split(': ');
          title = parts.first.trim();
          body = parts.sublist(1).join(': ').trim();
        }

        parsedList.add({
          'id': id,
          'channel': channel,
          'messageType': messageType,
          'tag': tag,
          'tagColor': tagColor,
          'sentAt': sentAt,
          'readAt': readAt,
          'time': _formatRelativeTime(sentAt),
          'isUnread': isUnread,
          'status': status,
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
          _alerts = [];
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Friendly relative time formatting
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

  /// Detailed date & time formatting for modals
  String _formatExactDateTime(DateTime? dt) {
    if (dt == null) return 'Not available';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year} at $hour:$minute $period';
  }

  Future<void> _markAllAsRead() async {
    if (_updatingRead || _isLoading) return;
    if (!_alerts.any((item) => item['isUnread'] == true)) return;
    final snapshots = {for (final item in _alerts) item['id']: Map<String, dynamic>.from(item)};
    setState(() {
      _updatingRead = true;
      for (final item in _alerts) {
        item['isUnread'] = false;
        item['status'] = 'Read';
        item['readAt'] = DateTime.now();
      }
    });
    try {
      await ApiService.markAllNotificationsRead();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All alerts marked as read.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        for (final item in _alerts) {
          final previous = snapshots[item['id']];
          if (previous != null) item..clear()..addAll(previous);
        }
      });
      _showReadError(error, _markAllAsRead);
    } finally {
      if (mounted) setState(() => _updatingRead = false);
    }
  }

  void _showReadError(Object error, VoidCallback retry) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error.toString()),
      action: SnackBarAction(label: 'Retry', onPressed: retry),
    ));
  }

  Future<void> _toggleReadStatus(Map<String, dynamic> item) async {
    if (_updatingRead || _isLoading) return;
    final previous = Map<String, dynamic>.from(item);
    final unread = item['isUnread'] != true;
    setState(() {
      _updatingRead = true;
      item['isUnread'] = unread;
      item['status'] = unread ? 'Sent' : 'Read';
      item['readAt'] = unread ? null : DateTime.now();
    });
    try {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) throw const ApiException('This notification has no ID.');
      if (unread) {
        await ApiService.markNotificationUnread(id);
      } else {
        await ApiService.markNotificationRead(id);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(unread ? 'Alert marked as unread.' : 'Alert marked as read.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => item..clear()..addAll(previous));
      _showReadError(error, () => _toggleReadStatus(item));
    } finally {
      if (mounted) setState(() => _updatingRead = false);
    }
  }

  Future<void> _openAlertDetails(Map<String, dynamic> item) async {
    if (_updatingRead) return;
    if (item['isUnread'] == true) await _toggleReadStatus(item);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => _buildDetailBottomSheet(modalCtx, item),
    );
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_selectedCategory == 'All') return _alerts;
    if (_selectedCategory == 'Unread') {
      return _alerts.where((a) => a['isUnread'] == true).toList();
    }
    return _alerts.where((a) => a['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => a['isUnread'] == true).length;
    final displayList = _filteredAlerts;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.surface,
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
                            color: theme.colorScheme.onSurface,
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
                      child: Tooltip(
                        message: 'Mark all as read',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
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
                                  ? (isDark ? AppColors.leaf400 : const Color(0xFF0E382C))
                                  : (isDark ? const Color(0xFF6B7A73) : const Color(0xFF9E9E9E)),
                              size: 20,
                            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : (isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
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

              // ── Recent updates label & Mark all read link ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent updates',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (_alerts.any((a) => a['isUnread'] == true))
                      GestureDetector(
                        onTap: _markAllAsRead,
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading database alerts...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF8A9E96),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _alerts.isEmpty) {
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadDatabaseNotifications,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E3A2F) : const Color(0xFF0E382C),
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
      String emptyTitle = 'No notifications yet';
      String emptySubtitle = 'Live notifications, booking approvals, payment receipts, and travel notices will show up here.';

      if (_selectedCategory == 'Unread') {
        emptyTitle = 'All caught up!';
        emptySubtitle = 'You have no unread notifications. Check the other category tabs for past history.';
      } else if (_selectedCategory != 'All') {
        emptyTitle = 'No $_selectedCategory alerts';
        emptySubtitle = 'There are no active updates under $_selectedCategory.';
      }

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
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162520) : const Color(0xFFEEFAF4),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.notifications_none_outlined,
                    size: 36,
                    color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF8A9E96),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  if (_selectedCategory != 'All') {
                    setState(() => _selectedCategory = 'All');
                  } else {
                    _loadDatabaseNotifications();
                  }
                },
                icon: Icon(
                  Icons.refresh,
                  size: 16,
                  color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                ),
                label: Text(
                  _selectedCategory != 'All' ? 'View All Alerts' : 'Refresh',
                  style: TextStyle(
                    color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                  ),
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

  /// Compact channel badge indicator representing the multi-channel notification center
  Widget _buildChannelBadge(String channel, bool isDark) {
    IconData icon;
    String label;
    Color bg;
    Color text;

    switch (channel.toLowerCase()) {
      case 'email':
        icon = Icons.mail_outline_rounded;
        label = 'Email';
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
        text = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        break;
      case 'sms':
        icon = Icons.sms_outlined;
        label = 'SMS';
        bg = isDark ? const Color(0xFF143022) : const Color(0xFFF0FDF4);
        text = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        break;
      case 'push':
        icon = Icons.notifications_active_outlined;
        label = 'Push';
        bg = isDark ? const Color(0xFF2E2310) : const Color(0xFFFEF3C7);
        text = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        break;
      case 'inapp':
      default:
        icon = Icons.smartphone_outlined;
        label = 'In-App';
        bg = isDark ? const Color(0xFF162B21) : const Color(0xFFEEFAF4);
        text = isDark ? AppColors.leaf400 : const Color(0xFF0E382C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: text),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  /// Clean notification card matching project design aesthetic
  Widget _buildAlertCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isUnread = item['isUnread'] == true;
    final tag = item['tag'] ?? 'INFO';
    final Color tagColor = item['tagColor'] ?? (isDark ? AppColors.leaf400 : const Color(0xFF0E382C));
    final String channel = item['channel']?.toString() ?? 'InApp';
    final time = item['time'] ?? 'Just now';
    final IconData icon = item['icon'] ?? Icons.notifications_outlined;
    final Color iconColor = item['iconColor'] ?? (isDark ? AppColors.leaf400 : const Color(0xFF0E382C));
    final title = item['title'] ?? 'Notification';
    final body = item['body'] ?? '';

    return GestureDetector(
      onTap: () => _openAlertDetails(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? const Color(0xFF162B21) : const Color(0xFFF0F8F5))
              : theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnread
                ? (isDark ? const Color(0xFF2A5946) : const Color(0xFFBCE3D2))
                : (isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
            width: isUnread ? 1.4 : 1.0,
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
                color: isDark ? const Color(0xFF203028) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
              ),
              child: Center(
                child: Icon(icon, color: isDark ? AppColors.leaf400 : iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag, Channel Badge & Time Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.leaf400 : tagColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildChannelBadge(channel, isDark),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF8A9E96),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
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
                  const SizedBox(height: 5),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Body text (truncated to 2 lines for clean card view)
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF6B7280),
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

  /// Interactive Modal Bottom Sheet displaying full notification details
  Widget _buildDetailBottomSheet(BuildContext modalCtx, Map<String, dynamic> item) {
    final theme = Theme.of(modalCtx);
    final isDark = theme.brightness == Brightness.dark;

    final title = item['title'] ?? 'Notification';
    final body = item['body'] ?? '';
    final tag = item['tag'] ?? 'INFO';
    final Color tagColor = item['tagColor'] ?? (isDark ? AppColors.leaf400 : const Color(0xFF0E382C));
    final channel = item['channel']?.toString() ?? 'InApp';
    final icon = item['icon'] ?? Icons.notifications_outlined;
    final Color iconColor = item['iconColor'] ?? (isDark ? AppColors.leaf400 : const Color(0xFF0E382C));
    final DateTime? sentAt = item['sentAt'] is DateTime ? item['sentAt'] : null;
    final isUnread = item['isUnread'] == true;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B4E44) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row with Channel Badge and Category Tag
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF203028) : const Color(0xFFF7F5EF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
                ),
                child: Center(
                  child: Icon(icon, color: isDark ? AppColors.leaf400 : iconColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.leaf400 : tagColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildChannelBadge(channel, isDark),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatExactDateTime(sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9EABA4) : const Color(0xFF8A9E96),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notification Title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 10),

          // Full Content Body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF2E3D36) : const Color(0xFFEDECE4)),
            ),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFE4E7E2) : const Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Action Buttons: Mark as Unread / Close
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalCtx);
                    _toggleReadStatus(item);
                  },
                  icon: Icon(
                    isUnread ? Icons.done : Icons.mark_email_unread_outlined,
                    size: 16,
                    color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                  ),
                  label: Text(
                    isUnread ? 'Mark as Read' : 'Mark as Unread',
                    style: TextStyle(
                      color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? AppColors.leaf400 : const Color(0xFF0E382C)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(modalCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E3A2F) : const Color(0xFF0E382C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
