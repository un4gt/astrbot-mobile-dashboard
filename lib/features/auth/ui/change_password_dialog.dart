/// Change-password dialog used from the Settings screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../shared/providers/app_providers.dart';
import '../data/auth_service.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = context.trM('changePassword.mismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).editAccount(
            currentPlainPassword: _curCtrl.text,
            newPlainPassword: _newCtrl.text,
          );
      if (!mounted) return;
      // Server invalidates the token, force user to re-login.
      await ref.read(tokenProvider.notifier).clear();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.trM('changePassword.title')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _curCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.trM('changePassword.current'),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? context.trM('login.required')
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.trM('changePassword.new'),
                ),
                validator: (v) => (v == null || v.length < 4)
                    ? context.trM('changePassword.minLength')
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.trM('changePassword.confirm'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(context.trM('common.cancel')),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.trM('common.save')),
        ),
      ],
    );
  }
}
