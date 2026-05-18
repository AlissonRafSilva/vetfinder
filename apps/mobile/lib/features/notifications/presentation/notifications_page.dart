import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_summary.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsRepository _repository = NotificationsRepository();
  Future<List<NotificationSummary>>? _future;
  String? _loadedSessionKey;
  bool _isMarkingAll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final session = AppSessionScope.of(context);
    final sessionKey = '${session.userId}:${session.accessToken}';

    if (!session.isAuthenticated || session.accessToken == null) {
      _future = null;
      _loadedSessionKey = sessionKey;
      return;
    }

    if (_loadedSessionKey == sessionKey && _future != null) {
      return;
    }

    _loadedSessionKey = sessionKey;
    _refresh();
  }

  void _refresh() {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || session.accessToken == null) {
      _future = null;
      return;
    }

    _future = _repository.fetchMine(accessToken: session.accessToken!);
  }

  Future<void> _markAllAsRead() async {
    final session = AppSessionScope.of(context);
    if (_isMarkingAll || session.accessToken == null) {
      return;
    }

    setState(() => _isMarkingAll = true);

    try {
      await _repository.markAllAsRead(accessToken: session.accessToken!);
      if (!mounted) {
        return;
      }
      setState(_refresh);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  Future<void> _markAsRead(NotificationSummary item) async {
    final session = AppSessionScope.of(context);
    if (item.isRead || session.accessToken == null) {
      return;
    }

    try {
      await _repository.markAsRead(
        accessToken: session.accessToken!,
        notificationId: item.id,
      );
      if (!mounted) {
        return;
      }
      setState(_refresh);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.of(context);

    if (!session.isAuthenticated) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Notificacoes',
              subtitle: 'Faca login para acompanhar alertas do marketplace.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma sessao ativa no momento.'),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Notificacoes',
            subtitle:
                'Acompanhe convites, candidaturas, respostas e plantoes fechados.',
            trailing: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(_refresh),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Atualizar'),
                ),
                ElevatedButton.icon(
                  onPressed: _isMarkingAll ? null : _markAllAsRead,
                  icon: const Icon(Icons.done_all_rounded),
                  label: Text(_isMarkingAll ? 'Marcando...' : 'Ler tudo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<NotificationSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nao foi possivel carregar suas notificacoes agora.',
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <NotificationSummary>[];
              final unreadCount = items.where((item) => !item.isRead).length;

              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'Nenhum alerta por enquanto',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Quando houver convites, candidaturas, respostas ou fechamento de plantao, tudo aparece aqui.',
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoBadge(label: '$unreadCount nao lidas'),
                  const SizedBox(height: 14),
                  for (var index = 0; index < items.length; index++) ...[
                    _NotificationCard(
                      item: items[index],
                      onMarkAsRead: () => _markAsRead(items[index]),
                    ),
                    if (index < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onMarkAsRead,
  });

  final NotificationSummary item;
  final VoidCallback onMarkAsRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: item.isRead
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.isRead
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_rounded,
                  color: item.isRead
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: item.isRead ? 'Lida' : 'Nova'),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.body),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  item.createdAtLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (!item.isRead)
                  TextButton(
                    onPressed: onMarkAsRead,
                    child: const Text('Marcar como lida'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
