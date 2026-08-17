/// Multi-server management: list of configured profiles, add/edit/delete,
/// and switching the active one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/storage/profile_store.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/confirm_dialog.dart';

class ProfileManageScreen extends ConsumerWidget {
  const ProfileManageScreen({super.key});

  Future<void> _switchTo(BuildContext context, WidgetRef ref, String id) async {
    final profiles = ref.read(profilesProvider);
    if (profiles.active?.id == id) return;
    await ref.read(profilesProvider.notifier).switchTo(id);
    // Token/baseUrl providers rebuild for the new server; the router
    // redirect sends the user to dashboard (logged in) or login.
  }

  Future<void> _edit(BuildContext context, WidgetRef ref,
      [ServerProfile? existing]) async {
    final saved = await showDialog<({String? id, String name, String baseUrl})>(
      context: context,
      builder: (_) => _ProfileDialog(initial: existing),
    );
    if (saved == null) return;
    await ref.read(profilesProvider.notifier).upsert(
          id: saved.id,
          name: saved.name,
          baseUrl: saved.baseUrl,
          activate: existing == null,
        );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ServerProfile p) async {
    final ok = await showConfirmDialog(
      context: context,
      title: context.trM('profiles.deleteTitle'),
      message: context.trM('profiles.deleteMessage', params: {'name': p.name}),
      destructive: true,
      confirmLabel: context.trM('profiles.deleteConfirm'),
    );
    if (ok != true) return;
    await ref.read(profilesProvider.notifier).remove(p.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesProvider);
    final activeId = state.active?.id;

    return Scaffold(
      appBar: AppBar(title: Text(context.trM('profiles.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.trM('profiles.add')),
      ),
      body: state.profiles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.trM('profiles.empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              children: [
                for (final p in state.profiles)
                  ListTile(
                    leading: Icon(
                      p.id == activeId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: p.id == activeId
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      p.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _switchTo(context, ref, p.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.trM('profiles.edit'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, ref, p),
                        ),
                        IconButton(
                          tooltip: context.trM('profiles.deleteConfirm'),
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _delete(context, ref, p),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.initial});
  final ServerProfile? initial;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _url = TextEditingController(text: widget.initial?.baseUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String? _validateUrl(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return context.trM('setup.validationEmpty');
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return context.trM('setup.validationInvalid');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null
          ? context.trM('profiles.add')
          : context.trM('profiles.edit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.initial == null,
            decoration: InputDecoration(
              labelText: context.trM('profiles.nameLabel'),
              hintText: context.trM('profiles.nameHint'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: context.trM('setup.urlLabel'),
              hintText: context.trM('setup.urlHint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('core.actions.cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_validateUrl(_url.text) != null) return;
            final name = _name.text.trim().isEmpty
                ? _url.text.trim()
                : _name.text.trim();
            Navigator.pop(
              context,
              (id: widget.initial?.id, name: name, baseUrl: _url.text.trim()),
            );
          },
          child: Text(context.tr('core.actions.save')),
        ),
      ],
    );
  }
}
