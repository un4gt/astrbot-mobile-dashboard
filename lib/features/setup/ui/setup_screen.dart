/// First-run server URL screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../application/setup_controller.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _statusMsg;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(prefsProvider).baseUrl;
    if (saved != null) _ctrl.text = saved;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return context.trM('setup.validationEmpty');
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || (uri.host).isEmpty) {
      return context.trM('setup.validationInvalid');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return context.trM('setup.validationScheme');
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _statusMsg = null;
    });
    try {
      final ok = await ref
          .read(setupControllerProvider)
          .testConnection(_ctrl.text);
      setState(() {
        _statusOk = ok;
        _statusMsg = ok
            ? context.trM('setup.reachable')
            : context.trM('setup.reachableButOff');
      });
    } on ApiException catch (e) {
      setState(() {
        _statusOk = false;
        _statusMsg = context.trM('setup.connectionFailed', params: {'error': e.message});
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAndContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(baseUrlProvider.notifier).set(_ctrl.text);
    if (mounted) context.go('/login');
  }

  Future<void> _enterLocalDebug() async {
    await ref.read(localDebugProvider.notifier).set(true);
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.dns_rounded, size: 56, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      context.trM('setup.title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.trM('setup.hint'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _ctrl,
                      autofocus: true,
                      autocorrect: false,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: context.trM('setup.urlLabel'),
                        hintText: context.trM('setup.urlHint'),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      validator: _validate,
                      onFieldSubmitted: (_) => _testConnection(),
                    ),
                    if (_statusMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_statusOk ? cs.tertiary : cs.error)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _statusOk
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _statusOk ? cs.tertiary : cs.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_statusMsg!)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _testConnection,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check),
                      label: Text(context.trM('setup.testConnection')),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _saveAndContinue,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(context.trM('setup.saveAndContinue')),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _enterLocalDebug,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: Text(context.trM('setup.localDebug')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
