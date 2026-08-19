/// Session rule editor. Five sections, each independently saved/cleared:
///   - Service (custom_name, persona_id, enable_session)
///   - Provider overrides (chat / STT / TTS picker)
///   - Plugin set (enabled / disabled lists -- empty means clear)
///   - Knowledge base (kb_ids + top_k + rerank toggle)
///
/// On first open of an unsaved rule, all sections start empty; the user
/// fills the ones they need and taps Save in the section to commit.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../data/session_service.dart';

class SessionRuleEditorScreen extends ConsumerStatefulWidget {
  const SessionRuleEditorScreen({super.key, required this.payload});

  /// `{umo, rules, available_*}` from the list screen, or `{umo, rules: {}}`
  /// for a freshly-added rule (without `available_*`).
  final Map<String, dynamic> payload;

  @override
  ConsumerState<SessionRuleEditorScreen> createState() =>
      _SessionRuleEditorScreenState();
}

class _SessionRuleEditorScreenState
    extends ConsumerState<SessionRuleEditorScreen> {
  late String _umo;
  late Map<String, dynamic> _rules;

  // Available data sources -- come from the list-rule response. If we got
  // here directly via "Add rule" the lists may be empty; we'll fall back
  // to fetching once on demand.
  List<String> _personas = const [];
  List<Map<String, dynamic>> _chatProviders = const [];
  List<Map<String, dynamic>> _sttProviders = const [];
  List<Map<String, dynamic>> _ttsProviders = const [];
  List<Map<String, dynamic>> _pluginsAvail = const [];
  List<Map<String, dynamic>> _kbsAvail = const [];

  @override
  void initState() {
    super.initState();
    _umo = (widget.payload['umo'] ?? '').toString();
    final rules = widget.payload['rules'];
    _rules = rules is Map
        ? Map<String, dynamic>.from(rules)
        : <String, dynamic>{};

    List<String> asStrs(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];
    List<Map<String, dynamic>> asList(dynamic v) => (v is List)
        ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : const [];
    _personas = asStrs(widget.payload['available_personas']);
    _chatProviders = asList(widget.payload['available_chat_providers']);
    _sttProviders = asList(widget.payload['available_stt_providers']);
    _ttsProviders = asList(widget.payload['available_tts_providers']);
    _pluginsAvail = asList(widget.payload['available_plugins']);
    _kbsAvail = asList(widget.payload['available_kbs']);

    // If we don't have available_* (came in via Add Rule), fetch them.
    if (_personas.isEmpty &&
        _chatProviders.isEmpty &&
        _sttProviders.isEmpty &&
        _kbsAvail.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final p =
              await ref.read(sessionServiceProvider).listRules(pageSize: 1);
          if (!mounted) return;
          setState(() {
            _personas = p.availablePersonas;
            _chatProviders = p.availableChatProviders;
            _sttProviders = p.availableSttProviders;
            _ttsProviders = p.availableTtsProviders;
            _pluginsAvail = p.availablePlugins;
            _kbsAvail = p.availableKbs;
          });
        } on ApiException {
          // ignore: best-effort
        }
      });
    }
  }

  Future<void> _saveRuleKey(String key, dynamic value) async {
    try {
      await ref
          .read(sessionServiceProvider)
          .updateRule(umo: _umo, ruleKey: key, ruleValue: value);
      setState(() => _rules[key] = value);
      ref.invalidate(sessionRulesProvider);
      _snack('Saved $key.');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    }
  }

  Future<void> _deleteRuleKey(String key) async {
    try {
      await ref
          .read(sessionServiceProvider)
          .deleteRule(umo: _umo, ruleKey: key);
      setState(() => _rules.remove(key));
      ref.invalidate(sessionRulesProvider);
      _snack('Cleared $key.');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
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
    return Scaffold(
      appBar: AppBar(title: Text(context.trM('session.editRule'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.tag),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _umo,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ServiceSection(
            initial: _rules['session_service_config'] is Map
                ? Map<String, dynamic>.from(
                    _rules['session_service_config'] as Map)
                : const {},
            personas: _personas,
            onSave: (cfg) => _saveRuleKey('session_service_config', cfg),
            onClear:
                _rules.containsKey('session_service_config') ? () => _deleteRuleKey('session_service_config') : null,
          ),
          const SizedBox(height: 12),
          _ProviderSection(
            chatProviders: _chatProviders,
            sttProviders: _sttProviders,
            ttsProviders: _ttsProviders,
            initialChat: _rules['provider_perf_chat_completion']?.toString(),
            initialStt: _rules['provider_perf_speech_to_text']?.toString(),
            initialTts: _rules['provider_perf_text_to_speech']?.toString(),
            onSave: (key, value) {
              if (value == null || value.isEmpty) {
                if (_rules.containsKey(key)) _deleteRuleKey(key);
              } else {
                _saveRuleKey(key, value);
              }
            },
          ),
          const SizedBox(height: 12),
          _PluginSection(
            available: _pluginsAvail,
            initial: _rules['session_plugin_config'] is Map
                ? Map<String, dynamic>.from(
                    _rules['session_plugin_config'] as Map)
                : const {},
            onSave: (cfg) {
              final enabled =
                  (cfg['enabled_plugins'] as List?)?.isNotEmpty ?? false;
              final disabled =
                  (cfg['disabled_plugins'] as List?)?.isNotEmpty ?? false;
              if (!enabled && !disabled) {
                if (_rules.containsKey('session_plugin_config')) {
                  _deleteRuleKey('session_plugin_config');
                }
              } else {
                _saveRuleKey('session_plugin_config', cfg);
              }
            },
          ),
          const SizedBox(height: 12),
          _KbSection(
            available: _kbsAvail,
            initial: _rules['kb_config'] is Map
                ? Map<String, dynamic>.from(_rules['kb_config'] as Map)
                : const {},
            onSave: (cfg) {
              final ids = (cfg['kb_ids'] as List?)?.isNotEmpty ?? false;
              if (!ids) {
                if (_rules.containsKey('kb_config')) _deleteRuleKey('kb_config');
              } else {
                _saveRuleKey('kb_config', cfg);
              }
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(sessionServiceProvider)
                    .deleteRule(umo: _umo);
                ref.invalidate(sessionRulesProvider);
                if (!context.mounted) return;
                context.pop();
              } on ApiException catch (e) {
                _snack(e.message, error: true);
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: Text(context.trM('session.deleteEntireRule')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Service

class _ServiceSection extends StatefulWidget {
  const _ServiceSection({
    required this.initial,
    required this.personas,
    required this.onSave,
    this.onClear,
  });
  final Map<String, dynamic> initial;
  final List<String> personas;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback? onClear;

  @override
  State<_ServiceSection> createState() => _ServiceSectionState();
}

class _ServiceSectionState extends State<_ServiceSection> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: (widget.initial['custom_name'] ?? '').toString());
  late String? _personaId = widget.initial['persona_id']?.toString();
  late bool? _enableSession = widget.initial['enable_session'] as bool?;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service',
      icon: Icons.tune,
      onClear: widget.onClear,
      onSave: () {
        final cfg = <String, dynamic>{};
        if (_nameCtrl.text.trim().isNotEmpty) {
          cfg['custom_name'] = _nameCtrl.text.trim();
        }
        if (_personaId != null && _personaId!.isNotEmpty) {
          cfg['persona_id'] = _personaId;
        }
        if (_enableSession != null) cfg['enable_session'] = _enableSession;
        widget.onSave(cfg);
      },
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Custom name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _personaId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Persona override',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(context.trM('session.defaultOption'))),
              for (final p in widget.personas)
                DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _personaId = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _enableSession ?? false,
            onChanged: (v) => setState(() => _enableSession = v),
            title: Text(context.trM('session.sessionIsolated')),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Provider

class _ProviderSection extends StatefulWidget {
  const _ProviderSection({
    required this.chatProviders,
    required this.sttProviders,
    required this.ttsProviders,
    required this.initialChat,
    required this.initialStt,
    required this.initialTts,
    required this.onSave,
  });
  final List<Map<String, dynamic>> chatProviders;
  final List<Map<String, dynamic>> sttProviders;
  final List<Map<String, dynamic>> ttsProviders;
  final String? initialChat;
  final String? initialStt;
  final String? initialTts;
  final void Function(String key, String? value) onSave;

  @override
  State<_ProviderSection> createState() => _ProviderSectionState();
}

class _ProviderSectionState extends State<_ProviderSection> {
  late String? _chat = widget.initialChat;
  late String? _stt = widget.initialStt;
  late String? _tts = widget.initialTts;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Provider overrides',
      icon: Icons.psychology_outlined,
      onSave: () {
        widget.onSave('provider_perf_chat_completion', _chat);
        widget.onSave('provider_perf_speech_to_text', _stt);
        widget.onSave('provider_perf_text_to_speech', _tts);
      },
      child: Column(
        children: [
          _providerDropdown(
              'Chat completion', _chat, widget.chatProviders, (v) => setState(() => _chat = v)),
          const SizedBox(height: 8),
          _providerDropdown(
              'Speech to text', _stt, widget.sttProviders, (v) => setState(() => _stt = v)),
          const SizedBox(height: 8),
          _providerDropdown(
              'Text to speech', _tts, widget.ttsProviders, (v) => setState(() => _tts = v)),
        ],
      ),
    );
  }

  Widget _providerDropdown(
    String label,
    String? value,
    List<Map<String, dynamic>> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String?>(
      initialValue: options.any((o) => (o['id'] ?? '').toString() == value)
          ? value
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text(context.trM('session.followConfig'))),
        for (final p in options)
          DropdownMenuItem(
            value: (p['id'] ?? '').toString(),
            child: Text((p['id'] ?? '').toString()),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------- Plugin

class _PluginSection extends StatefulWidget {
  const _PluginSection({
    required this.available,
    required this.initial,
    required this.onSave,
  });
  final List<Map<String, dynamic>> available;
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_PluginSection> createState() => _PluginSectionState();
}

class _PluginSectionState extends State<_PluginSection> {
  late final Set<String> _enabled = (widget.initial['enabled_plugins'] is List)
      ? Set<String>.from(
          (widget.initial['enabled_plugins'] as List).map((e) => e.toString()))
      : <String>{};
  late final Set<String> _disabled = (widget.initial['disabled_plugins'] is List)
      ? Set<String>.from(
          (widget.initial['disabled_plugins'] as List).map((e) => e.toString()))
      : <String>{};

  @override
  Widget build(BuildContext context) {
    final names = widget.available
        .map((p) => (p['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
    return _SectionCard(
      title: 'Plugin overrides',
      icon: Icons.extension_outlined,
      onSave: () {
        widget.onSave({
          'enabled_plugins': _enabled.toList(),
          'disabled_plugins': _disabled.toList(),
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toggle each plugin: gray = follow config, green = force enable, red = force disable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          if (names.isEmpty)
            Text(context.trM('session.noPlugins'))
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final n in names)
                  _TristateChip(
                    label: n,
                    state: _enabled.contains(n)
                        ? _PluginState.on
                        : _disabled.contains(n)
                            ? _PluginState.off
                            : _PluginState.follow,
                    onChanged: (s) => setState(() {
                      _enabled.remove(n);
                      _disabled.remove(n);
                      switch (s) {
                        case _PluginState.on:
                          _enabled.add(n);
                          break;
                        case _PluginState.off:
                          _disabled.add(n);
                          break;
                        case _PluginState.follow:
                          break;
                      }
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _PluginState { follow, on, off }

class _TristateChip extends StatelessWidget {
  const _TristateChip({
    required this.label,
    required this.state,
    required this.onChanged,
  });
  final String label;
  final _PluginState state;
  final ValueChanged<_PluginState> onChanged;

  @override
  Widget build(BuildContext context) {
    Color bg;
    IconData? icon;
    switch (state) {
      case _PluginState.follow:
        bg = Theme.of(context).colorScheme.surfaceContainerHighest;
        icon = null;
        break;
      case _PluginState.on:
        bg = Colors.green.withValues(alpha: 0.2);
        icon = Icons.check;
        break;
      case _PluginState.off:
        bg = Theme.of(context).colorScheme.error.withValues(alpha: 0.18);
        icon = Icons.block;
        break;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // cycle: follow -> on -> off -> follow
        switch (state) {
          case _PluginState.follow:
            onChanged(_PluginState.on);
            break;
          case _PluginState.on:
            onChanged(_PluginState.off);
            break;
          case _PluginState.off:
            onChanged(_PluginState.follow);
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12),
              const SizedBox(width: 4),
            ],
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- KB

class _KbSection extends StatefulWidget {
  const _KbSection({
    required this.available,
    required this.initial,
    required this.onSave,
  });
  final List<Map<String, dynamic>> available;
  final Map<String, dynamic> initial;
  final ValueChanged<Map<String, dynamic>> onSave;

  @override
  State<_KbSection> createState() => _KbSectionState();
}

class _KbSectionState extends State<_KbSection> {
  late final Set<String> _kbIds = (widget.initial['kb_ids'] is List)
      ? Set<String>.from(
          (widget.initial['kb_ids'] as List).map((e) => e.toString()))
      : <String>{};
  late int _topK = (widget.initial['top_k'] as num?)?.toInt() ?? 5;
  late bool _rerank = widget.initial['enable_rerank'] == true;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Knowledge base',
      icon: Icons.menu_book_outlined,
      onSave: () => widget.onSave({
        'kb_ids': _kbIds.toList(),
        'top_k': _topK,
        'enable_rerank': _rerank,
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.available.isEmpty)
            Text(context.trM('session.noKbs'))
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final kb in widget.available)
                  FilterChip(
                    label: Text((kb['kb_name'] ?? kb['kb_id']).toString()),
                    selected: _kbIds
                        .contains((kb['kb_id'] ?? '').toString()),
                    onSelected: (on) => setState(() {
                      final id = (kb['kb_id'] ?? '').toString();
                      if (on) {
                        _kbIds.add(id);
                      } else {
                        _kbIds.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(context.trM('session.topK')),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _topK.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null) _topK = n;
                  },
                ),
              ),
              const Spacer(),
              Text(context.trM('session.rerank')),
              Switch(value: _rerank, onChanged: (v) => setState(() => _rerank = v)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- card shell

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.onSave,
    required this.child,
    this.onClear,
  });
  final String title;
  final IconData icon;
  final VoidCallback onSave;
  final VoidCallback? onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: Text(context.trM('common.clear')),
                  ),
                FilledButton.tonal(
                  onPressed: onSave,
                  child: Text(context.trM('common.save')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
