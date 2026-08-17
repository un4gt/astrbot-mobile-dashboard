/// Form host for both creating and editing a platform adapter. Uses the
/// shared `ConfigForm` widget over `metadata.platform_group.metadata.platform`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../config/data/config_service.dart';
import '../../config/domain/config_bundle.dart';
import '../../config/domain/selector.dart';
import '../../config/ui/config_form.dart';
import '../data/platform_service.dart';

class EditPlatformScreen extends ConsumerStatefulWidget {
  const EditPlatformScreen({
    super.key,
    required this.config,
    required this.isNew,
    this.templateName,
    this.originalId,
  });

  /// Mutable starting values (deep-cloned by the caller).
  final Map<String, dynamic> config;

  /// True when creating, false when editing existing.
  final bool isNew;

  /// Template name (only set when creating).
  final String? templateName;

  /// Original id when editing -- used for the update endpoint.
  final String? originalId;

  @override
  ConsumerState<EditPlatformScreen> createState() => _EditPlatformScreenState();
}

class _EditPlatformScreenState extends ConsumerState<EditPlatformScreen> {
  final _formKey = GlobalKey<ConfigFormState>();
  bool _saving = false;

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    final next = form.currentValue();
    final id = (next['id'] ?? '').toString();
    if (id.isEmpty) {
      _snack('id is required.', error: true);
      return;
    }

    if (widget.isNew) {
      // Client-side conflict detection mirroring PlatformPage.vue.
      final existing = ref.read(configBundleProvider).valueOrNull?.platforms ??
          const <Map<String, dynamic>>[];
      if (existing.any((p) => p['id'] == id) || id == 'webchat') {
        _snack('ID "$id" already in use. Please pick a different one.',
            error: true);
        return;
      }
    } else if (widget.originalId != null && widget.originalId != id) {
      // The server's update endpoint keys on the original id.
      final ok = await showConfirmDialog(
        context: context,
        title: 'Rename adapter?',
        message:
            'You changed id from "${widget.originalId}" to "$id". The server will update it under the original key.',
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final svc = ref.read(platformServiceProvider);
      if (widget.isNew) {
        await svc.create(next);
      } else {
        await svc.update(widget.originalId ?? id, next);
      }
      ref.invalidate(configBundleProvider);
      if (mounted) {
        _snack(widget.isNew
            ? context.trM('config.adapterCreated')
            : context.trM('config.adapterSaved'));
        context.pop();
      }
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(configBundleProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew
            ? context.trM('config.newAdapter')
            : context.trM('config.editAdapter')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.trM('config.save')),
          ),
        ],
      ),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : e.toString()),
        ),
        data: (b) {
          final schema = b.platformItemsSchema;
          if (schema == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Server did not return a platform schema.'),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: ConfigForm(
              key: _formKey,
              sectionMeta: schema,
              initial: _initialConfig(b),
              title: widget.templateName,
              mode: ConfigFormMode.configKeys,
            ),
          );
        },
      ),
    );
  }

  /// Mirrors PlatformPage.vue `configExistingPlatform`: when editing an
  /// existing adapter, merge it over the matching template's default config
  /// so newly introduced template fields appear with their defaults.
  Map<String, dynamic> _initialConfig(ConfigBundle b) {
    if (widget.isNew) return widget.config;
    final type = widget.config['type']?.toString();
    Map<String, dynamic>? template;
    if (type != null) {
      for (final t in b.platformTemplates.values) {
        if (t['type']?.toString() == type) {
          template = t;
          break;
        }
      }
    }
    return mergeWithTemplateDefaults(widget.config, template);
  }
}
