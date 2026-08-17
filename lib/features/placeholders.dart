/// Stub screens for Phase 1 -- each tab/page just shows its name and a hint
/// of what will be implemented in later phases. They get fleshed out in
/// Phase 2..7 per the plan file.
library;

import 'package:flutter/material.dart';

class _Stub extends StatelessWidget {
  const _Stub({required this.title, required this.icon, required this.phase});
  final String title;
  final IconData icon;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: cs.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Coming in $phase',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardStubScreen extends StatelessWidget {
  const DashboardStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
        phase: 'Phase 5',
      );
}

class PlatformStubScreen extends StatelessWidget {
  const PlatformStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Platforms',
        icon: Icons.smart_toy_outlined,
        phase: 'Phase 2',
      );
}

class ProviderStubScreen extends StatelessWidget {
  const ProviderStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Providers',
        icon: Icons.psychology_outlined,
        phase: 'Phase 2',
      );
}

class PluginStubScreen extends StatelessWidget {
  const PluginStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Plugins',
        icon: Icons.extension_outlined,
        phase: 'Phase 4',
      );
}

class ConsoleStubScreen extends StatelessWidget {
  const ConsoleStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Console',
        icon: Icons.terminal,
        phase: 'Phase 3',
      );
}

class ConfigStubScreen extends StatelessWidget {
  const ConfigStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Configuration',
        icon: Icons.tune,
        phase: 'Phase 4',
      );
}

class McpStubScreen extends StatelessWidget {
  const McpStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'MCP / Tool Use',
        icon: Icons.build_outlined,
        phase: 'Phase 6',
      );
}

class PersonaStubScreen extends StatelessWidget {
  const PersonaStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Persona',
        icon: Icons.face_outlined,
        phase: 'Phase 6',
      );
}

class SessionStubScreen extends StatelessWidget {
  const SessionStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Session Rules',
        icon: Icons.rule,
        phase: 'Phase 6',
      );
}

class KbStubScreen extends StatelessWidget {
  const KbStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Knowledge Base',
        icon: Icons.menu_book_outlined,
        phase: 'Phase 7',
      );
}

class AlkaidKbStubScreen extends StatelessWidget {
  const AlkaidKbStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Knowledge Base (Legacy)',
        icon: Icons.archive_outlined,
        phase: 'Phase 7',
      );
}

class MemoryStubScreen extends StatelessWidget {
  const MemoryStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'Long-Term Memory',
        icon: Icons.psychology_alt_outlined,
        phase: 'Phase 7',
      );
}

class AboutStubScreen extends StatelessWidget {
  const AboutStubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Stub(
        title: 'About & Update',
        icon: Icons.info_outline,
        phase: 'Phase 7',
      );
}
