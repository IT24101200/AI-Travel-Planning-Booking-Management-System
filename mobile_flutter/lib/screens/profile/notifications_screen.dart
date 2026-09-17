import 'package:flutter/material.dart';
import '../../app_constants.dart';
import '../../services/api_service.dart';
import '../../widgets/common_widgets.dart';

/// Notifications screen showing customer notifications with read/unread status.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  /// Fetch notifications from backend
  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getMyNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications';
          _loading = false;
        });
      }
    }
  }

  /// Mark a single notification as read
  Future<void> _markRead(String id, int index) async {
    try {
      await ApiService.markNotificationRead(id);
      if (mounted) {
        setState(() {
          _notifications[index]['readAt'] = DateTime.now().toIso8601String();
        });
      }
    } catch (_) {}
  }

  /// Mark all notifications as read
  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      if (mounted) {
        setState(() {
          for (var n in _notifications) {
            n['readAt'] = DateTime.now().toIso8601String();
          }
        });
      }
    } catch (_) {}
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tripupdate':
        return Icons.auto_awesome;
      case 'bookingconfirmation':
        return Icons.verified;
      case 'paymentreceipt':
        return Icons.receipt_long;
      case 'systemalert':
        return Icons.notifications_active;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.mail_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['readAt'] == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(unreadCount > 0 ? 'Notifications ($unreadCount)' : 'Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 16),
              label: const Text(
                'Read All',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Checking for updates...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadNotifications)
              : _notifications.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      message: 'No notifications at this time.\nUpdates regarding trip planning & bookings will appear here.',
                    )
                  : RefreshIndicator(
                      color: AppColors.jungle600,
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _buildNotificationCard(n, index);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n, int index) {
    final isRead = n['readAt'] != null;
    final type = n['messageType'] ?? 'SystemAlert';
    final channel = n['channel'] ?? 'InApp';
    final content = n['content'] ?? '';
    final sentAt = n['sentAt']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : AppColors.leaf50.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? AppColors.line : AppColors.leaf400.withOpacity(0.5),
          width: isRead ? 0.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (!isRead) {
            _markRead(n['id']?.toString() ?? '', index);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.mist
                      : AppColors.jungle600.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: isRead ? AppColors.ink3 : AppColors.jungle600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Content Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.line,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            channel.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink2,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                            color: isRead ? AppColors.ink3 : AppColors.jungle700,
                          ),
                        ),
                        const Spacer(),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.jungle600,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sentAt.length >= 16 ? sentAt.substring(0, 16) : sentAt,
                      style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
