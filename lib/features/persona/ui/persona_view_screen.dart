/// Read-only persona viewer. Lists system prompt, preset dialog turns, and
/// the assigned tools. Edit button in the app bar pushes the form.
library;

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../data/persona_service.dart';

class PersonaViewScreen extends StatelessWidget {
  const PersonaViewScreen({super.key, required this.persona});
  final Map<String, dynamic> persona;

  @override
  Widget build(BuildContext context) {
    final p = Persona(persona);
    final dialogs = p.beginDialogs;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.id),
        actions: [
          TextButton.icon(
            onPressed: () =>
                context.push('/more/persona/edit', extra: persona),
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.trM('common.edit')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.trM('persona.systemPrompt'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              p.systemPrompt.isEmpty ? '(empty)' : p.systemPrompt,
            ),
          ),
          const SizedBox(height: 24),
          Text('Tools (${p.tools.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (persona['tools'] == null)
            Text(context.trM('persona.allTools'))
          else if (p.tools.isEmpty)
            Text(context.trM('persona.noTools'))
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in p.tools)
                  Chip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          const SizedBox(height: 24),
          Text('Preset dialog (${dialogs.length ~/ 2 +
                  (dialogs.length.isOdd ? 1 : 0)} message(s))',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (dialogs.isEmpty)
            Text(context.trM('persona.noPrompt'))
          else
            for (var i = 0; i < dialogs.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _DialogBubble(
                  isUser: i.isEven,
                  text: dialogs[i]['content']?.toString() ??
                      dialogs[i].toString(),
                ),
              ),
        ],
      ),
    );
  }
}

class _DialogBubble extends StatelessWidget {
  const _DialogBubble({required this.isUser, required this.text});
  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser ? 'User' : 'Assistant',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                SelectableText(text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
