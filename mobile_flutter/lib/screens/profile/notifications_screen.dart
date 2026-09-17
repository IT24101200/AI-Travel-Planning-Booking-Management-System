import 'package:flutter/material.dart';
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
    setState(() { _loading = true; _error = null; });
    try {
      _notifications = await ApiService.getMyNotifications();
    } catch (e) {
      _error = 'Failed to load notifications';
    }
    if (mounted) setState(() { _loading = false; });
  }

  /// Mark a single notification as read
  Future<void> _markRead(String id, int index) async {
    try {
      await ApiService.markNotificationRead(id);
      setState(() {
        _notifications[index]['readAt'] = DateTime.now().toIso8601String();
      });
    } catch (e) {
      // Silent fail — notification will refresh on next load
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      setState(() {
        for (var n in _notifications) {
          n['readAt'] = DateTime.now().toIso8601String();
        }
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Get icon for notification type
  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tripupdate':
        return Icons.flight;
      case 'bookingconfirmation':
        return Icons.check_circle;
      case 'paymentreceipt':
        return Icons.receipt;
      case 'systemalert':
        return Icons.warning;
      case 'promotion':
        return Icons.local_offer;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['readAt'] == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications ${unreadCount > 0 ? '($unreadCount)' : ''}'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator(message: 'Loading notifications...')
          : _error != null
              ? ErrorMessage(message: _error!, onRetry: _loadNotifications)
              : _notifications.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_off,
                      message: 'No notifications yet',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return _buildNotificationCard(n, index);
                        },
                      ),
                    ),
    );
  }

  /// Build a notification card
  Widget _buildNotificationCard(Map<String, dynamic> n, int index) {
    final isRead = n['readAt'] != null;
    final type = n['messageType'] ?? 'SystemAlert';
    final channel = n['channel'] ?? 'InApp';

    return Card(
      color: isRead ? null : const Color(0xFF0D9488).withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.grey.shade100
                      : const Color(0xFF0D9488).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: isRead ? Colors.grey : const Color(0xFF0D9488),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Channel badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            channel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n['content'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n['sentAt']?.toString().substring(0, 16) ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!isRead)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D9488),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
