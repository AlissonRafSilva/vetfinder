import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../data/admin_repository.dart';
import '../domain/admin_document_summary.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminRepository _repository = AdminRepository();
  Future<List<AdminDocumentSummary>>? _future;
  bool _isReviewing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || session.accessToken == null) {
      _future = null;
      return;
    }

    _future = _repository.fetchPendingDocuments(
      accessToken: session.accessToken!,
    );
  }

  Future<void> _review(AdminDocumentSummary document, String status) async {
    final session = AppSessionScope.of(context);
    if (session.accessToken == null || _isReviewing) {
      return;
    }

    String? rejectionReason;
    if (status == 'REJECTED') {
      rejectionReason = await showDialog<String>(
        context: context,
        builder: (context) => const _RejectionReasonDialog(),
      );

      if (rejectionReason == null) {
        return;
      }
    }

    setState(() => _isReviewing = true);

    try {
      final message = await _repository.reviewDocument(
        accessToken: session.accessToken!,
        documentId: document.id,
        status: status,
        rejectionReason: rejectionReason,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(_load);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isReviewing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 16),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Validacao administrativa',
              subtitle:
                  'Aprove ou reprove documentos enviados para liberar perfis na plataforma.',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<AdminDocumentSummary>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _AdminStateCard(
                    title: 'Nao foi possivel carregar documentos',
                    message: 'Verifique a API e tente novamente.',
                    actionLabel: 'Atualizar',
                    onAction: () => setState(_load),
                  );
                }

                final documents =
                    snapshot.data ?? const <AdminDocumentSummary>[];
                if (documents.isEmpty) {
                  return _AdminStateCard(
                    title: 'Nada pendente agora',
                    message:
                        'Quando houver CRMV, declaracao de matricula ou CNPJ para revisar, eles aparecem aqui.',
                    actionLabel: 'Atualizar',
                    onAction: () => setState(_load),
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < documents.length; index++) ...[
                      _DocumentReviewCard(
                        document: documents[index],
                        isReviewing: _isReviewing,
                        onApprove: () => _review(documents[index], 'APPROVED'),
                        onReject: () => _review(documents[index], 'REJECTED'),
                      ),
                      if (index < documents.length - 1)
                        const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentReviewCard extends StatelessWidget {
  const _DocumentReviewCard({
    required this.document,
    required this.isReviewing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminDocumentSummary document;
  final bool isReviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    document.ownerLabel,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                InfoBadge(label: document.statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              document.ownerSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: document.documentTypeLabel),
                InfoBadge(label: document.createdAtLabel),
              ],
            ),
            const SizedBox(height: 12),
            if (document.isImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  document.fileUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _DocumentPreviewFallback(fileUrl: document.fileUrl);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ] else
              _DocumentPreviewFallback(fileUrl: document.fileUrl),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: document.fileUrl.isEmpty
                    ? null
                    : () => _openDocument(context, document.fileUrl),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir documento'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isReviewing ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reprovar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isReviewing ? null : onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aprovar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, String fileUrl) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL do documento invalida.')),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o documento.')),
      );
    }
  }
}

class _DocumentPreviewFallback extends StatelessWidget {
  const _DocumentPreviewFallback({
    required this.fileUrl,
  });

  final String fileUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              fileUrl.isEmpty ? 'Arquivo sem URL registrada.' : fileUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStateCard extends StatelessWidget {
  const _AdminStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Motivo da reprova'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Motivo opcional',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Confirmar reprova'),
        ),
      ],
    );
  }
}
