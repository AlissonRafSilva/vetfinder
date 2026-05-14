import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../availability/data/availability_repository.dart';
import '../../availability/domain/availability_slot_model.dart';
import '../../applications/data/applications_repository.dart';
import '../../applications/domain/application_summary.dart';
import '../../applications/domain/invite_summary.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ApplicationsRepository _applicationsRepository = ApplicationsRepository();
  final AvailabilityRepository _availabilityRepository = AvailabilityRepository();
  final List<AvailabilitySlotModel> _editableSlots = [];
  Future<List<ApplicationSummary>>? _applicationsFuture;
  Future<List<InviteSummary>>? _invitesFuture;
  Future<List<AvailabilitySlotModel>>? _availabilityFuture;
  bool _isSavingAvailability = false;
  String? _loadedSessionKey;
  final Set<String> _respondingInviteIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFromSession();
  }

  void _refreshFromSession() {
    final session = AppSessionScope.of(context);
    final sessionKey = '${session.userId}:${session.accessToken}';

    if (!session.isAuthenticated || !session.canApplyToOpportunities) {
      _applicationsFuture = null;
      _invitesFuture = null;
      _availabilityFuture = null;
      _editableSlots.clear();
      _loadedSessionKey = null;
      return;
    }

    if (_loadedSessionKey == sessionKey &&
        _applicationsFuture != null &&
        _invitesFuture != null &&
        _availabilityFuture != null) {
      return;
    }

    _loadedSessionKey = sessionKey;
    _applicationsFuture = _applicationsRepository.fetchMyApplications(
      accessToken: session.accessToken!,
    );
    _invitesFuture = _applicationsRepository.fetchMyInvites(
      accessToken: session.accessToken!,
    );
    _availabilityFuture = _availabilityRepository
        .fetchMyAvailability(accessToken: session.accessToken!)
        .then((slots) {
      _editableSlots
        ..clear()
        ..addAll(slots);
      return slots;
    });
  }

  void _reload() {
    setState(() {
      _loadedSessionKey = null;
      _refreshFromSession();
    });
  }

  Future<void> _respondInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || session.accessToken == null) {
      return;
    }

    setState(() {
      _respondingInviteIds.add(inviteId);
    });

    try {
      final message = await _applicationsRepository.respondInvite(
        accessToken: session.accessToken!,
        inviteId: inviteId,
        accept: accept,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _reload();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _respondingInviteIds.remove(inviteId);
        });
      }
    }
  }

  Future<void> _saveAvailability() async {
    final session = AppSessionScope.of(context);
    if (!session.isAuthenticated || session.accessToken == null) {
      return;
    }

    setState(() {
      _isSavingAvailability = true;
    });

    try {
      final slots = await _availabilityRepository.saveMyAvailability(
        accessToken: session.accessToken!,
        slots: _editableSlots,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _editableSlots
          ..clear()
          ..addAll(slots);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disponibilidade atualizada com sucesso.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAvailability = false;
        });
      }
    }
  }

  void _addSlot() {
    setState(() {
      _editableSlots.add(
        const AvailabilitySlotModel(
          weekday: 1,
          startTime: '08:00',
          endTime: '18:00',
        ),
      );
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _editableSlots.removeAt(index);
    });
  }

  void _updateSlot(int index, AvailabilitySlotModel slot) {
    setState(() {
      _editableSlots[index] = slot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = AppSessionScope.of(context);

    if (!session.isAuthenticated) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Minhas candidaturas',
              subtitle: 'Faca login para acompanhar o andamento das vagas que voce aplicou.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma sessao ativa. Entre com um perfil profissional.'),
              ),
            ),
          ],
        ),
      );
    }

    if (!session.canApplyToOpportunities) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Minhas candidaturas',
              subtitle: 'Esta area e destinada a veterinarios e estagiarios.',
            ),
            SizedBox(height: 18),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Perfis de clinica e hospital usam outros fluxos, como publicacao de vagas e resposta a candidaturas.',
                ),
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
          const SectionHeader(
            title: 'Minha agenda',
            subtitle: 'Informe seus horarios livres para que clinicas e hospitais encontrem voce mais rapido.',
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoBadge(label: 'Historico real'),
              InfoBadge(label: 'Status atualizado'),
              InfoBadge(label: 'Fluxo profissional'),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<AvailabilitySlotModel>>(
            future: _availabilityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _editableSlots.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponibilidade recorrente',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Esses horarios poderao ser usados pelas clinicas para encontrar profissionais disponiveis.',
                      ),
                      const SizedBox(height: 16),
                      if (_editableSlots.isEmpty)
                        const Text('Nenhum horario cadastrado ainda.')
                      else
                        Column(
                          children: [
                            for (var index = 0; index < _editableSlots.length; index++) ...[
                              _EditableAvailabilityCard(
                                slot: _editableSlots[index],
                                onChanged: (slot) => _updateSlot(index, slot),
                                onRemove: () => _removeSlot(index),
                              ),
                              if (index < _editableSlots.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addSlot,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar horario'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSavingAvailability
                                  ? null
                                  : _saveAvailability,
                              child: _isSavingAvailability
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Salvar agenda'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Convites recebidos',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Aqui aparecem os convites que clinicas e hospitais enviaram diretamente para voce.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<InviteSummary>>(
            future: _invitesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Nao foi possivel carregar seus convites agora.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                );
              }

              final invites = snapshot.data ?? const <InviteSummary>[];
              if (invites.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Nenhum convite recebido no momento.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < invites.length; index++) ...[
                    _InviteCard(
                      item: invites[index],
                      isResponding: _respondingInviteIds.contains(invites[index].id),
                      onAccept: () => _respondInvite(
                        inviteId: invites[index].id,
                        accept: true,
                      ),
                      onDecline: () => _respondInvite(
                        inviteId: invites[index].id,
                        accept: false,
                      ),
                    ),
                    if (index < invites.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Minhas candidaturas',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Acompanhe o status das oportunidades para as quais voce ja aplicou.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<ApplicationSummary>>(
            future: _applicationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nao foi possivel carregar suas candidaturas.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tente novamente para atualizar o historico vindo da API.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _reload,
                          child: const Text('Atualizar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final items = snapshot.data ?? const <ApplicationSummary>[];
              if (items.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voce ainda nao enviou candidaturas.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acesse a aba Plantoes, escolha uma oportunidade e envie sua candidatura por la.',
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _ApplicationCard(item: items[index]),
                    if (index < items.length - 1) const SizedBox(height: 14),
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

class _EditableAvailabilityCard extends StatelessWidget {
  const _EditableAvailabilityCard({
    required this.slot,
    required this.onChanged,
    required this.onRemove,
  });

  final AvailabilitySlotModel slot;
  final ValueChanged<AvailabilitySlotModel> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: slot.weekday,
                  decoration: const InputDecoration(
                    labelText: 'Dia da semana',
                  ),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_weekdayLabel(index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(
                        AvailabilitySlotModel(
                          weekday: value,
                          startTime: slot.startTime,
                          endTime: slot.endTime,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: slot.startTime,
                  decoration: const InputDecoration(
                    labelText: 'Inicio',
                    hintText: '08:00',
                  ),
                  onChanged: (value) {
                    onChanged(
                      AvailabilitySlotModel(
                        weekday: slot.weekday,
                        startTime: value,
                        endTime: slot.endTime,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: slot.endTime,
                  decoration: const InputDecoration(
                    labelText: 'Fim',
                    hintText: '18:00',
                  ),
                  onChanged: (value) {
                    onChanged(
                      AvailabilitySlotModel(
                        weekday: slot.weekday,
                        startTime: slot.startTime,
                        endTime: value,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _weekdayLabel(int weekday) {
    const values = [
      'Segunda',
      'Terca',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sabado',
      'Domingo',
    ];

    return values[(weekday - 1).clamp(0, values.length - 1)];
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.item,
  });

  final ApplicationSummary item;

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
                    item.opportunityTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: item.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.institutionName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: item.specialtyLabel),
                InfoBadge(label: item.shiftLabel),
                InfoBadge(label: item.amountLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.appliedAtLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.item,
    required this.isResponding,
    required this.onAccept,
    required this.onDecline,
  });

  final InviteSummary item;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
                    item.opportunityTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InfoBadge(label: item.statusLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.institutionName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoBadge(label: item.specialtyLabel),
                InfoBadge(label: item.shiftLabel),
                InfoBadge(label: item.amountLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.invitedAtLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (item.message != null && item.message!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Mensagem da instituicao',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(item.message!),
            ],
            if (item.canRespond) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isResponding ? null : onDecline,
                      child: const Text('Recusar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isResponding ? null : onAccept,
                      child: isResponding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aceitar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
