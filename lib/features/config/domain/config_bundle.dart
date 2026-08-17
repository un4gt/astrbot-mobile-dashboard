/// Top-level config bundle the dashboard pulls via `GET /api/config/get`.
///
/// `config` holds the live values (platform[], provider[], various groups).
/// `metadata` describes the schema for forms (config_template per group +
/// items schema for fields). We keep both as raw maps because the schema
/// shape is large, evolves with the server, and only specific subtrees are
/// consumed by individual screens.
library;

class ConfigBundle {
  final Map<String, dynamic> config;
  final Map<String, dynamic> metadata;

  ConfigBundle({required this.config, required this.metadata});

  /// Convenience: list of platform configs (`config.platform`).
  List<Map<String, dynamic>> get platforms {
    final raw = config['platform'];
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return const [];
  }

  /// Convenience: list of provider configs (`config.provider`).
  List<Map<String, dynamic>> get providers {
    final raw = config['provider'];
    if (raw is List) return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return const [];
  }

  /// Templates for the "add platform" picker:
  /// `metadata.platform_group.metadata.platform.config_template[name] = {...}`
  Map<String, Map<String, dynamic>> get platformTemplates =>
      _readTemplates(['platform_group', 'metadata', 'platform', 'config_template']);

  /// Templates for the "add provider" picker, same nesting under provider_group.
  Map<String, Map<String, dynamic>> get providerTemplates =>
      _readTemplates(['provider_group', 'metadata', 'provider', 'config_template']);

  /// Items schema (per-field metadata) for the platform form, shared across
  /// all platform templates. Visibility is filtered per-template via the
  /// `condition` field on each entry.
  Map<String, dynamic>? get platformItemsSchema =>
      _readSection(['platform_group', 'metadata', 'platform']);

  /// Items schema for the provider form.
  Map<String, dynamic>? get providerItemsSchema =>
      _readSection(['provider_group', 'metadata', 'provider']);

  Map<String, Map<String, dynamic>> _readTemplates(List<String> path) {
    dynamic cur = metadata;
    for (final k in path) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return {};
      }
    }
    if (cur is Map) {
      return cur.map((k, v) =>
          MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
    }
    return {};
  }

  Map<String, dynamic>? _readSection(List<String> path) {
    dynamic cur = metadata;
    for (final k in path) {
      if (cur is Map && cur.containsKey(k)) {
        cur = cur[k];
      } else {
        return null;
      }
    }
    return cur is Map ? Map<String, dynamic>.from(cur) : null;
  }
}
