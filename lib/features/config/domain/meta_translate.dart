/// Translates strings that come from the server's metadata `description` /
/// `hint` / `labels`. The dashboard prefixes them with
/// `features.config-metadata.` before looking up; if the lookup misses we
/// return the original string verbatim (it is already localized).
library;

import '../../../core/i18n/app_localizations.dart';

const _prefix = 'features.config-metadata.';

String? translateMetaString(AppLocalizations loc, dynamic value) {
  if (value == null) return null;
  if (value is! String) return value.toString();
  if (value.isEmpty) return value;
  // Dotted key -> attempt translation. Otherwise treat as literal.
  if (value.contains('.')) {
    final translated = loc.t('$_prefix$value');
    if (translated != '$_prefix$value') return translated;
  }
  return value;
}

/// Resolves `meta.labels` -- can be a list (use as-is) or a string i18n key
/// pointing to a list under config-metadata. Returns null when neither.
List<String>? translateMetaLabels(AppLocalizations loc, dynamic labels) {
  if (labels is List) {
    return labels.map((e) => e?.toString() ?? '').toList();
  }
  if (labels is String && labels.isNotEmpty) {
    final raw = loc.raw('$_prefix$labels');
    if (raw is List) return raw.map((e) => e?.toString() ?? '').toList();
  }
  return null;
}
