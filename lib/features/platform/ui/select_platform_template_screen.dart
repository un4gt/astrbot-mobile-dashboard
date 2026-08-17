/// Picker for a platform template (`config_template[name]`). On selection
/// pushes the editor with a fresh deep-clone of the template values.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/type_icons.dart';
import '../../config/data/config_service.dart';

class SelectPlatformTemplateScreen extends ConsumerWidget {
  const SelectPlatformTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(configBundleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Add adapter')),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is ApiException ? e.message : e.toString()),
        ),
        data: (b) {
          final tpls = b.platformTemplates;
          if (tpls.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No platform templates returned by the server.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final names = tpls.keys.toList()..sort();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: names.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final name = names[i];
              final template = tpls[name]!;
              final type = (template['type'] ?? name).toString();
              return ListTile(
                leading: Icon(platformIconFor(type)),
                title: Text(name),
                subtitle: Text(type),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Deep clone so edits don't mutate the metadata template.
                  final clone = _deepClone(template);
                  context.pushReplacement(
                    '/platforms/edit',
                    extra: {
                      'config': clone,
                      'isNew': true,
                      'templateName': name,
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

dynamic _deepClone(dynamic v) {
  if (v is Map) {
    return Map<String, dynamic>.from(
        v.map((k, vv) => MapEntry(k.toString(), _deepClone(vv))));
  }
  if (v is List) return v.map(_deepClone).toList();
  return v;
}
