import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/app_session_scope.dart';
import '../../auth/data/auth_repository.dart';

class SecurityPrivacyPage extends StatefulWidget {
  const SecurityPrivacyPage({super.key});

  @override
  State<SecurityPrivacyPage> createState() => _SecurityPrivacyPageState();
}

class _SecurityPrivacyPageState extends State<SecurityPrivacyPage> {
  final _authRepository = AuthRepository();
  final _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  bool _loading = false;

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final session = AppSessionScope.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha atual')),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Nova senha (mínimo 8 caracteres)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Atualizar'))
        ],
      ),
    );
    if (accepted != true || session.accessToken == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final message = await _authRepository.changePassword(
          accessToken: session.accessToken!,
          currentPassword: current.text,
          newPassword: next.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      current.dispose();
      next.dispose();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportData() async {
    final token = AppSessionScope.of(context).accessToken;
    if (token == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final data =
          await _apiClient.getDynamic('/users/me/export', accessToken: token);
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Meus dados'),
                  content: SizedBox(
                      width: 680,
                      child:
                          SingleChildScrollView(child: SelectableText(json))),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: json));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Dados copiados.')));
                          }
                        },
                        child: const Text('Copiar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'))
                  ]));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deactivate() async {
    final confirmation = TextEditingController();
    final session = AppSessionScope.of(context);
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Encerrar conta'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Esta ação bloqueia o acesso à conta. Registros financeiros precisam ser preservados.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: confirmation,
                      decoration: const InputDecoration(
                          labelText: 'Digite ENCERRAR MINHA CONTA'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Encerrar'))
                ]));
    if (accepted != true || session.accessToken == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _apiClient.deleteJson('/users/me',
          accessToken: session.accessToken!);
      session.logout();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      confirmation.dispose();
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Segurança e privacidade')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Gerencie o acesso e os dados da sua conta.'),
        const SizedBox(height: 18),
        _ActionCard(
            icon: Icons.lock_reset_rounded,
            title: 'Trocar senha',
            subtitle: 'Atualize sua senha de acesso.',
            onTap: _loading ? null : _changePassword),
        _ActionCard(
            icon: Icons.download_rounded,
            title: 'Exportar meus dados',
            subtitle: 'Visualize e copie uma exportação em JSON.',
            onTap: _loading ? null : _exportData),
        _ActionCard(
            icon: Icons.no_accounts_rounded,
            title: 'Encerrar minha conta',
            subtitle: 'Bloqueia o acesso; dados financeiros são preservados.',
            destructive: true,
            onTap: _loading ? null : _deactivate),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()))
      ]));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.destructive = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Card(
        child: ListTile(
            onTap: onTap,
            leading: Icon(icon, color: color),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded)));
  }
}
