import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../../core/widgets/info_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../data/asaas_accounts_repository.dart';
import '../domain/asaas_account_summary.dart';

class FinancialOnboardingPage extends StatefulWidget {
  const FinancialOnboardingPage({super.key});

  @override
  State<FinancialOnboardingPage> createState() =>
      _FinancialOnboardingPageState();
}

class _FinancialOnboardingPageState extends State<FinancialOnboardingPage> {
  final _repository = AsaasAccountsRepository();
  final _formKey = GlobalKey<FormState>();
  final _cpfCnpjController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _incomeController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _addressNumberController = TextEditingController();
  final _complementController = TextEditingController();
  final _provinceController = TextEditingController();

  Future<AsaasAccountSummary?>? _accountFuture;
  String? _companyType;
  bool _isSubmitting = false;
  String? _feedback;

  bool get _isCompany => _cpfCnpjController.text.length > 11;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accountFuture ??= _loadAccount();
  }

  @override
  void dispose() {
    _cpfCnpjController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    _postalCodeController.dispose();
    _addressController.dispose();
    _addressNumberController.dispose();
    _complementController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<AsaasAccountSummary?> _loadAccount() {
    final token = AppSessionScope.of(context).accessToken;
    if (token == null) {
      return Future.value(null);
    }
    return _repository.fetchMine(accessToken: token);
  }

  void _refresh() {
    setState(() {
      _feedback = null;
      _accountFuture = _loadAccount();
    });
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 16),
      helpText: 'Data de nascimento',
    );
    if (selected == null || !mounted) {
      return;
    }
    _birthDateController.text = '${selected.day.toString().padLeft(2, '0')}/'
        '${selected.month.toString().padLeft(2, '0')}/${selected.year}';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final session = AppSessionScope.of(context);
    final token = session.accessToken;
    if (token == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });

    try {
      final birthDate = _birthDateController.text.trim();
      final birthDateParts = birthDate.split('/');
      final account = await _repository.create(
        accessToken: token,
        data: {
          'cpfCnpj': _cpfCnpjController.text,
          if (!_isCompany)
            'birthDate':
                '${birthDateParts[2]}-${birthDateParts[1]}-${birthDateParts[0]}',
          if (_isCompany) 'companyType': _companyType,
          'mobilePhone': _phoneController.text,
          'incomeValue': _parseIncome(_incomeController.text),
          'postalCode': _postalCodeController.text,
          'address': _addressController.text.trim(),
          'addressNumber': _addressNumberController.text.trim(),
          if (_complementController.text.trim().isNotEmpty)
            'complement': _complementController.text.trim(),
          'province': _provinceController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _feedback = 'Conta financeira enviada para análise.';
        _accountFuture = Future.value(account);
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _feedback = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  double _parseIncome(String value) {
    return double.parse(value.replaceAll('.', '').replaceAll(',', '.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conta de recebimento')),
      body: FutureBuilder<AsaasAccountSummary?>(
        future: _accountFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: _refresh);
          }

          final account = snapshot.data;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Receba pelo VetFinder',
                  subtitle:
                      'Cadastre sua conta financeira para receber plantões com split automático e acompanhamento pelo aplicativo.',
                ),
                const SizedBox(height: 18),
                if (account != null)
                  _AccountStatusCard(account: account, onRefresh: _refresh)
                else
                  _buildForm(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecurityNotice(),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dados do titular',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Use os mesmos dados dos documentos que serão validados pelo Asaas.',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _cpfCnpjController,
                    decoration: const InputDecoration(labelText: 'CPF ou CNPJ'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 14,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final length = value?.length ?? 0;
                      return length == 11 || length == 14
                          ? null
                          : 'Informe um CPF ou CNPJ válido.';
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_isCompany)
                    DropdownButtonFormField<String>(
                      initialValue: _companyType,
                      decoration:
                          const InputDecoration(labelText: 'Tipo da empresa'),
                      items: const [
                        DropdownMenuItem(value: 'MEI', child: Text('MEI')),
                        DropdownMenuItem(
                          value: 'LIMITED',
                          child: Text('Sociedade limitada'),
                        ),
                        DropdownMenuItem(
                          value: 'INDIVIDUAL',
                          child: Text('Empresário individual'),
                        ),
                        DropdownMenuItem(
                          value: 'ASSOCIATION',
                          child: Text('Associação'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _companyType = value),
                      validator: (value) =>
                          value == null ? 'Selecione o tipo da empresa.' : null,
                    )
                  else
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _selectBirthDate,
                      decoration: const InputDecoration(
                        labelText: 'Data de nascimento',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Selecione sua data de nascimento.'
                          : null,
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration:
                        const InputDecoration(labelText: 'Celular com DDD'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 11,
                    validator: (value) => (value?.length ?? 0) < 10
                        ? 'Informe um celular válido.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _incomeController,
                    decoration: const InputDecoration(
                      labelText: 'Renda ou faturamento mensal',
                      prefixText: 'R\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll('.', '').replaceAll(',', '.'),
                      );
                      return parsed == null || parsed < 1
                          ? 'Informe o valor mensal.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Endereço cadastral',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'CEP'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    validator: (value) =>
                        value?.length == 8 ? null : 'Informe um CEP válido.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Logradouro'),
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressNumberController,
                          decoration:
                              const InputDecoration(labelText: 'Número'),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _complementController,
                          decoration:
                              const InputDecoration(labelText: 'Complemento'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _provinceController,
                    decoration: const InputDecoration(labelText: 'Bairro'),
                    textCapitalization: TextCapitalization.words,
                    validator: _required,
                  ),
                ],
              ),
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 16),
            Text(
              _feedback!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_rounded),
              label: Text(
                _isSubmitting ? 'Enviando...' : 'Criar conta de recebimento',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obrigatório.' : null;
}

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({required this.account, required this.onRefresh});

  final AsaasAccountSummary account;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approved = account.onboardingStatus == 'APPROVED';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    approved
                        ? Icons.verified_rounded
                        : Icons.hourglass_top_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    account.statusLabel,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                InfoBadge(label: account.environmentLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              approved
                  ? 'Sua carteira está pronta para receber pagamentos pelo marketplace.'
                  : 'O cadastro foi recebido. A liberação final depende da análise cadastral do Asaas.',
            ),
            if (account.maskedWalletId != null) ...[
              const SizedBox(height: 12),
              Text('Carteira: ${account.maskedWalletId}'),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar status'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Seus dados são enviados com conexão segura ao backend e usados para o cadastro financeiro no Asaas. O aplicativo não armazena CPF nem endereço no aparelho.',
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            const Text('Não foi possível consultar a conta financeira.'),
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
