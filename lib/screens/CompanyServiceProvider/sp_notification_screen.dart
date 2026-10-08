import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/Transport/notification_controller.dart';
import '../../models/notification_model.dart';
import '../../widgets/custom_loader.dart';
import 'booking_details_screen.dart';
import 'leads/lead_detail_screen.dart';

// Design tokens — match CompanyTransport notification_screen
const _primary = Color(0xFFF36969);
const _primaryLight = Color(0xFFFFF1F1);
const _bg = Color(0xFFF9FAFB);
const _cardBg = Colors.white;
const _textDark = Color(0xFF111827);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

/// Service Provider Notifications — mirrors CompanyTransport NotificationScreen.
/// Uses the same [NotificationController] since the backend endpoint is role-agnostic.
class SpNotificationScreen extends StatelessWidget {
  const SpNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Find existing controller or create; permanent=false so it clears when
    // the SP wrapper disposes.
    final controller = Get.isRegistered<NotificationController>()
        ? Get.find<NotificationController>()
        : Get.put(NotificationController());

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _border,
        // Also used as a bottom-nav tab, where there is nothing to go back to.
        automaticallyImplyLeading: false,
        leading: ModalRoute.of(context)?.canPop ?? false
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _textDark, size: 20),
                onPressed: () => Get.back(),
              )
            : null,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: _textDark,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (controller.unreadCount == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: controller.markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.notifications.isEmpty) {
          return const Center(child: CustomLoader(message: 'Loading…'));
        }

        if (controller.notifications.isEmpty) {
          return const _SpEmptyState();
        }

        final groups = _groupByDate(controller.notifications);

        return RefreshIndicator(
          onRefresh: controller.refreshNotifications,
          color: _primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: _countItems(groups),
            itemBuilder: (context, index) =>
                _resolveItem(groups, index, controller),
          ),
        );
      }),
    );
  }

  // ── Date grouping ──────────────────────────────────────────────────────────

  List<_Group> _groupByDate(List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationModel>[];
    final yesterdayItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final n in notifications) {
      final date = _parseDate(n.createdDate);
      if (date == null) {
        earlierItems.add(n);
        continue;
      }
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }

    return [
      if (todayItems.isNotEmpty) _Group('Today', todayItems),
      if (yesterdayItems.isNotEmpty) _Group('Yesterday', yesterdayItems),
      if (earlierItems.isNotEmpty) _Group('Earlier', earlierItems),
    ];
  }

  DateTime? _parseDate(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  int _countItems(List<_Group> groups) =>
      groups.fold(0, (sum, g) => sum + 1 + g.items.length);

  Widget _resolveItem(
    List<_Group> groups,
    int index,
    NotificationController controller,
  ) {
    int cursor = 0;
    for (final group in groups) {
      if (index == cursor) return _DateHeader(label: group.label);
      cursor++;
      if (index < cursor + group.items.length) {
        final item = group.items[index - cursor];
        return _SpNotificationCard(
            notification: item, controller: controller);
      }
      cursor += group.items.length;
    }
    return const SizedBox.shrink();
  }
}

// ── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textGrey,
          fontFamily: 'Poppins',
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Notification card (swipe to delete) ─────────────────────────────────────

class _SpNotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final NotificationController controller;

  const _SpNotificationCard({
    required this.notification,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async =>
          controller.deleteNotification(notification.notificationId),
      child: GestureDetector(
        onTap: () {
          if (isUnread) controller.markAsRead(notification.notificationId);
          _openTarget(notification);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isUnread ? _primary.withValues(alpha: 0.25) : _border,
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _typeColor(notification.type)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _typeIcon(notification.type, notification.title),
                    color: _typeColor(notification.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _textDark,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _textGrey,
                          fontFamily: 'Poppins',
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: _textGrey),
                          const SizedBox(width: 4),
                          Text(
                            notification.formattedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textGrey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Deep-link a notification to the relevant detail screen.
  void _openTarget(NotificationModel n) {
    final leadId = n.leadId;
    if (leadId != null) {
      Get.to(() => LeadDetailScreen(leadId: leadId));
      return;
    }
    final serviceId = n.serviceId;
    if (serviceId != null && n.isServiceBooking) {
      Get.to(() => BookingDetailsScreen(serviceId: serviceId));
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'success':
        return const Color(0xFF22C55E);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return _primary;
    }
  }

  IconData _typeIcon(String type, String title) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
    }
    final t = title.toLowerCase();
    if (t.contains('booking') || t.contains('service')) {
      return Icons.handyman_outlined;
    }
    if (t.contains('lead')) return Icons.person_add_outlined;
    if (t.contains('job') || t.contains('application')) {
      return Icons.work_outline_rounded;
    }
    if (t.contains('payment') || t.contains('earning')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (t.contains('like')) return Icons.favorite_outline_rounded;
    if (t.contains('comment') || t.contains('message')) {
      return Icons.chat_bubble_outline_rounded;
    }
    return Icons.notifications_outlined;
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _SpEmptyState extends StatelessWidget {
  const _SpEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 40, color: _primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 14,
              color: _textGrey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal data class ──────────────────────────────────────────────────────

class _Group {
  final String label;
  final List<NotificationModel> items;
  const _Group(this.label, this.items);
}
