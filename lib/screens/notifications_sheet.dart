import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../ui/common.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({required this.onOpen, super.key});
  final ValueChanged<Target> onOpen;

  @override
  Widget build(BuildContext context) {
    final state = FlackleScope.of(context);
    return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Notifications',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.display(17,
                                    weight: FontWeight.w600))),
                        IconButton(
                            tooltip: 'Close notifications',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 19)),
                      ]),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              onPressed: state.unreadNotifications == 0
                                  ? null
                                  : state.markNotificationsRead,
                              child: const Text('Mark all read'))),
                    ])),
            Expanded(
                child: state.notifications.isEmpty
                    ? const EmptyPane(
                        icon: Icons.notifications_none_rounded,
                        title: 'You’re all caught up',
                        detail:
                            'Mentions, replies and direct messages appear here.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                        itemCount: state.notifications.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: context.c.line),
                        itemBuilder: (context, index) {
                          final item = state.notifications[index];
                          return ListTile(
                            leading: Icon(
                                item.read
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                size: 20,
                                color: item.read
                                    ? context.c.muted
                                    : context.c.accent),
                            title: Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.label(13,
                                    weight: item.read
                                        ? FontWeight.w500
                                        : FontWeight.w700)),
                            subtitle: Text(item.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.label(12,
                                    color: context.c.textDim)),
                            trailing: Text(relativeTime(item.createdAt),
                                style:
                                    context.label(10, color: context.c.muted)),
                            onTap: () {
                              state.markNotificationRead(item);
                              if (item.target != null) {
                                Navigator.of(context).pop();
                                onOpen(item.target!);
                              }
                            },
                          );
                        },
                      )),
          ]),
        ));
  }
}
