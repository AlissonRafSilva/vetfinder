import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../payments/data/payments_repository.dart';
import '../../payments/domain/payment_summary.dart';
import '../../reviews/data/reviews_repository.dart';
import '../../reviews/domain/review_summary.dart';
import '../domain/engagement_summary.dart';

class EngagementDetailPage extends StatefulWidget {
  const EngagementDetailPage({
    super.key,
    required this.item,
    required this.isInstitutionView,
  });

  final EngagementSummary item;
  final bool isInstitutionView;

  @override
  State<EngagementDetailPage> createState() => _EngagementDetailPageState();
}

class _EngagementDetailPageState extends State<EngagementDetailPage> {
  final PaymentsRepository _paymentsRepository = PaymentsRepository();
  final ReviewsRepository _reviewsRepository = ReviewsRepository();
  Future<PaymentSummary?>? _paymentFuture;
  Future<List<ReviewSummary>>? _reviewsFuture;
  String? _loadedPaymentKey;
  String? _loadedReviewsKey;
  PaymentSummary? _createdPayment;
  ReviewSummary? _createdReview;
  bool _isCreatingPayment = false;
  bool _isConfirmingPayment = false;
  bool _isCreatingReview = false;
  bool _shouldRefreshOnExit = false;
  String? _paymentFeedback;
  String? _reviewFeedback;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPayment();
    _loadReviews();
  }

  void _loadPayment() {
    final session = AppSessionScope.of(context);
    final paymentKey =
        '${session.userId}:${session.accessToken}:${widget.item.id}';
    if (!session.isAuthenticated || session.accessToken == null) {
      _paymentFuture = null;
      _loadedPaymentKey = paymentKey;
      return;
    }

    if (_loadedPaymentKey == paymentKey && _paymentFuture != null) {
      return;
    }

    _loadedPaymentKey = paymentKey;

    final future = _paymentsRepository.fetchPaymentByEngagement(
      accessToken: session.accessToken!,
      engagementId: widget.item.id,
    );

    _paymentFuture = future;
    future.then((payment) {
      if (mounted && payment != null && _createdPayment == null) {
        setState(() {
          _createdPayment = payment;
        });
      }
    }).catchError((_) {});
  }

  void _loadReviews() {
    final session = AppSessionScope.of(context);
    final reviewsKey =
        '${session.userId}:${session.accessToken}:${widget.item.id}';
    if (!session.isAuthenticated || session.accessToken == null) {
      _reviewsFuture = null;
      _loadedReviewsKey = reviewsKey;
      return;
    }

    if (_loadedReviewsKey == reviewsKey && _reviewsFuture != null) {
      return;
    }

    _loadedReviewsKey = reviewsKey;
    _refreshReviews(session.accessToken!);
  }

  void _refreshReviews(String accessToken) {
    _reviewsFuture = _reviewsRepository.fetchByEngagement(
      accessToken: accessToken,
      engagementId: widget.item.id,
    );
  }

  Future<void> _registerPayment() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated ||
        !session.isInstitutionUser ||
        session.accessToken == null ||
        _isCreatingPayment) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Registrar pagamento'),
            content: const Text(
              'Gerar checkout sandbox para este plantão? O contrato continuará aguardando pagamento até a confirmação do gateway.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Gerar checkout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _isCreatingPayment = true;
      _paymentFeedback = null;
    });

    try {
      final payment = await _paymentsRepository.createCheckoutPayment(
        accessToken: session.accessToken!,
        engagementId: widget.item.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _createdPayment = payment;
        _paymentFuture = Future.value(payment);
        _shouldRefreshOnExit = true;
        _paymentFeedback = 'Checkout sandbox criado com sucesso.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentFeedback = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
        });
      }
    }
  }

  Future<void> _confirmSandboxPayment(PaymentSummary payment) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated ||
        !session.isInstitutionUser ||
        session.accessToken == null ||
        _isConfirmingPayment) {
      return;
    }

    setState(() {
      _isConfirmingPayment = true;
      _paymentFeedback = null;
    });

    try {
      final confirmedPayment = await _paymentsRepository.confirmSandboxPayment(
        accessToken: session.accessToken!,
        paymentId: payment.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _createdPayment = confirmedPayment;
        _paymentFuture = Future.value(confirmedPayment);
        _loadedPaymentKey =
            '${session.userId}:${session.accessToken}:${widget.item.id}';
        _shouldRefreshOnExit = true;
        _paymentFeedback = 'Pagamento sandbox confirmado com sucesso.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _paymentFeedback = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isConfirmingPayment = false);
      }
    }
  }

  Future<void> _openCheckout(PaymentSummary payment) async {
    final checkoutUrl = payment.checkoutUrl;
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      return;
    }

    await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openReviewDialog() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated ||
        session.accessToken == null ||
        _isCreatingReview) {
      return;
    }

    final result = await Navigator.of(context).push<_ReviewFormResult>(
      MaterialPageRoute(
        builder: (_) => const _ReviewFormPage(),
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _isCreatingReview = true;
      _reviewFeedback = null;
    });

    try {
      final review = await _reviewsRepository.createReview(
        accessToken: session.accessToken!,
        engagementId: widget.item.id,
        rating: result.rating,
        comment: result.comment,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _createdReview = review;
        _refreshReviews(session.accessToken!);
        _loadedReviewsKey =
            '${session.userId}:${session.accessToken}:${widget.item.id}';
        _shouldRefreshOnExit = true;
        _reviewFeedback = 'Avaliação registrada com sucesso.';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _reviewFeedback = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingReview = false;
        });
      }
    }
  }

  bool get _canRegisterPayment {
    return widget.isInstitutionView &&
        widget.item.statusLabel == 'Aguardando pagamento' &&
        _createdPayment == null;
  }

  bool get _canReview {
    return _createdPayment != null ||
        widget.item.statusLabel == 'Confirmado' ||
        widget.item.statusLabel == 'Em andamento' ||
        widget.item.statusLabel == 'Concluido';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryPersonLabel =
        widget.isInstitutionView ? 'Profissional confirmado' : 'Instituição';
    final primaryPersonValue = widget.isInstitutionView
        ? widget.item.professionalName
        : widget.item.institutionName;
    final primaryPersonSubtitle = widget.isInstitutionView
        ? widget.item.professionalRoleLabel
        : 'Contratante';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(_shouldRefreshOnExit),
        ),
        title: const Text('Detalhes do plantão'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        InfoBadge(
                          label: _createdPayment == null
                              ? widget.item.statusLabel
                              : 'Confirmado',
                        ),
                        InfoBadge(label: widget.item.sourceLabel),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.item.opportunityTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.item.shiftLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: primaryPersonLabel,
              children: [
                _DetailRow(label: 'Nome', value: primaryPersonValue),
                _DetailRow(label: 'Perfil', value: primaryPersonSubtitle),
                if (widget.isInstitutionView &&
                    widget.item.professionalEmail.isNotEmpty)
                  _DetailRow(
                    label: 'Email',
                    value: widget.item.professionalEmail,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Plantão',
              children: [
                _DetailRow(
                    label: 'Especialidade', value: widget.item.specialtyLabel),
                _DetailRow(label: 'Horário', value: widget.item.shiftLabel),
                _DetailRow(
                    label: 'Fechamento', value: widget.item.createdAtLabel),
                _DetailRow(
                  label: 'Status',
                  value: _createdPayment == null
                      ? widget.item.statusLabel
                      : 'Confirmado',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Financeiro',
              children: [
                _DetailRow(
                    label: 'Valor bruto', value: widget.item.grossAmountLabel),
                _DetailRow(
                  label: 'Taxa da plataforma',
                  value: widget.item.platformFeeLabel,
                ),
                _DetailRow(
                  label: 'Valor líquido profissional',
                  value: widget.item.netAmountLabel,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PaymentSection(
              paymentFuture: _paymentFuture,
              createdPayment: _createdPayment,
              feedback: _paymentFeedback,
              canRegisterPayment: _canRegisterPayment,
              canConfirmSandboxPayment: widget.isInstitutionView,
              isCreatingPayment: _isCreatingPayment,
              isConfirmingPayment: _isConfirmingPayment,
              onRegisterPayment: _registerPayment,
              onConfirmSandboxPayment: _confirmSandboxPayment,
              onOpenCheckout: _openCheckout,
            ),
            const SizedBox(height: 14),
            _ReviewsSection(
              reviewsFuture: _reviewsFuture,
              createdReview: _createdReview,
              feedback: _reviewFeedback,
              canReview: _canReview,
              currentUserId: AppSessionScope.of(context).userId ?? '',
              isCreatingReview: _isCreatingReview,
              onCreateReview: _openReviewDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.paymentFuture,
    required this.createdPayment,
    required this.feedback,
    required this.canRegisterPayment,
    required this.canConfirmSandboxPayment,
    required this.isCreatingPayment,
    required this.isConfirmingPayment,
    required this.onRegisterPayment,
    required this.onConfirmSandboxPayment,
    required this.onOpenCheckout,
  });

  final Future<PaymentSummary?>? paymentFuture;
  final PaymentSummary? createdPayment;
  final String? feedback;
  final bool canRegisterPayment;
  final bool canConfirmSandboxPayment;
  final bool isCreatingPayment;
  final bool isConfirmingPayment;
  final VoidCallback onRegisterPayment;
  final ValueChanged<PaymentSummary> onConfirmSandboxPayment;
  final ValueChanged<PaymentSummary> onOpenCheckout;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.payments_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pagamento',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ambiente sandbox: este fluxo simula checkout e split. O gateway real será conectado após escolha jurídica/financeira.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (createdPayment != null)
              _PaymentDetails(
                payment: createdPayment!,
                canConfirmSandbox: canConfirmSandboxPayment,
                isConfirmingPayment: isConfirmingPayment,
                onConfirmSandboxPayment: onConfirmSandboxPayment,
                onOpenCheckout: onOpenCheckout,
              )
            else if (paymentFuture == null)
              const Text('Pagamento ainda não carregado para esta sessão.')
            else
              FutureBuilder<PaymentSummary?>(
                future: paymentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'Não foi possível verificar o pagamento agora.',
                    );
                  }

                  final payment = snapshot.data;
                  if (payment != null) {
                    return _PaymentDetails(
                      payment: payment,
                      canConfirmSandbox: canConfirmSandboxPayment,
                      isConfirmingPayment: isConfirmingPayment,
                      onConfirmSandboxPayment: onConfirmSandboxPayment,
                      onOpenCheckout: onOpenCheckout,
                    );
                  }

                  return const Text(
                    'Aguardando pagamento. A instituição pode gerar um checkout sandbox enquanto o gateway real não foi escolhido.',
                  );
                },
              ),
            if (feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                feedback!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (canRegisterPayment) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isCreatingPayment ? null : onRegisterPayment,
                  icon: const Icon(Icons.price_check_rounded),
                  label: Text(
                    isCreatingPayment
                        ? 'Registrando pagamento...'
                        : 'Gerar checkout sandbox',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentDetails extends StatelessWidget {
  const _PaymentDetails({
    required this.payment,
    required this.canConfirmSandbox,
    required this.isConfirmingPayment,
    required this.onConfirmSandboxPayment,
    required this.onOpenCheckout,
  });

  final PaymentSummary payment;
  final bool canConfirmSandbox;
  final bool isConfirmingPayment;
  final ValueChanged<PaymentSummary> onConfirmSandboxPayment;
  final ValueChanged<PaymentSummary> onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'Status', value: payment.statusLabel),
        _DetailRow(label: 'Provedor', value: payment.providerLabel),
        _DetailRow(
          label: 'Status do provedor',
          value: payment.providerStatusLabel,
        ),
        _DetailRow(label: 'Valor bruto', value: payment.grossAmountLabel),
        _DetailRow(label: 'Split plataforma', value: payment.platformFeeLabel),
        _DetailRow(
          label: 'Split profissional',
          value: payment.netAmountLabel,
        ),
        _DetailRow(label: 'Data', value: payment.paidAtLabel),
        if (payment.hasCheckout) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onOpenCheckout(payment),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir checkout sandbox'),
            ),
          ),
        ],
        if (canConfirmSandbox && !payment.isPaid) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isConfirmingPayment
                  ? null
                  : () => onConfirmSandboxPayment(payment),
              icon: const Icon(Icons.verified_rounded),
              label: Text(
                isConfirmingPayment
                    ? 'Confirmando pagamento...'
                    : 'Confirmar pagamento sandbox',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviewsFuture,
    required this.createdReview,
    required this.feedback,
    required this.canReview,
    required this.currentUserId,
    required this.isCreatingReview,
    required this.onCreateReview,
  });

  final Future<List<ReviewSummary>>? reviewsFuture;
  final ReviewSummary? createdReview;
  final String? feedback;
  final bool canReview;
  final String currentUserId;
  final bool isCreatingReview;
  final VoidCallback onCreateReview;

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
                Icon(
                  Icons.star_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Avaliações',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (reviewsFuture == null)
              const Text('Avaliações ainda não carregadas para esta sessão.')
            else
              FutureBuilder<List<ReviewSummary>>(
                future: reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return const Text(
                      'Não foi possível carregar as avaliações agora.',
                    );
                  }

                  final loadedReviews =
                      snapshot.data ?? const <ReviewSummary>[];
                  final reviews = [
                    ...loadedReviews,
                    if (createdReview != null &&
                        !loadedReviews.any(
                          (review) => review.id == createdReview!.id,
                        ))
                      createdReview!,
                  ];
                  final alreadyReviewed = reviews.any(
                    (review) => review.reviewerUserId == currentUserId,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reviews.isEmpty)
                        const Text(
                          'Ainda não há avaliações para este plantão.',
                        )
                      else
                        ...reviews.map(_ReviewTile.new),
                      if (feedback != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          feedback!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (canReview && !alreadyReviewed) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isCreatingReview ? null : onCreateReview,
                            icon: const Icon(Icons.rate_review_rounded),
                            label: Text(
                              isCreatingReview
                                  ? 'Registrando avaliação...'
                                  : 'Avaliar contraparte',
                            ),
                          ),
                        ),
                      ] else if (!canReview) ...[
                        const SizedBox(height: 12),
                        Text(
                          'A avaliação será liberada após a confirmação do pagamento.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Sua avaliação deste plantão já foi registrada.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.review);

  final ReviewSummary review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review.ratingLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${review.reviewerName} avaliou ${review.revieweeName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (review.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review.comment),
              ],
              const SizedBox(height: 8),
              Text(
                review.createdAtLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewFormPage extends StatefulWidget {
  const _ReviewFormPage();

  @override
  State<_ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends State<_ReviewFormPage> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Registrar avaliação'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Como foi a experiência?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A avaliação escrita ajuda a plataforma a criar confiança entre profissionais e instituições.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<int>(
                initialValue: _rating,
                decoration: const InputDecoration(
                  labelText: 'Nota',
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5 - Excelente')),
                  DropdownMenuItem(value: 4, child: Text('4 - Muito bom')),
                  DropdownMenuItem(value: 3, child: Text('3 - Regular')),
                  DropdownMenuItem(value: 2, child: Text('2 - Ruim')),
                  DropdownMenuItem(value: 1, child: Text('1 - Muito ruim')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _rating = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _commentController,
                minLines: 5,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Comentário',
                  hintText:
                      'Ex.: Profissional pontual, boa comunicação e atendimento conforme combinado.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          _ReviewFormResult(
                            rating: _rating,
                            comment: _commentController.text,
                          ),
                        );
                      },
                      child: const Text('Registrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewFormResult {
  const _ReviewFormResult({
    required this.rating,
    required this.comment,
  });

  final int rating;
  final String comment;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
