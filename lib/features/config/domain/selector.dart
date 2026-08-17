/// Helpers for navigating dotted JSON-selector keys in a config map.
/// Mirrors `getValueBySelector` / `setValueBySelector` in
/// `dashboard/src/components/shared/AstrBotConfigV4.vue` (lines 65-93),
/// with a few mobile-side compatibility extensions for backend metadata
/// variants observed across AstrBot versions.
library;

dynamic getValueBySelector(Map<String, dynamic> obj, String selector) {
  dynamic cur = obj;
  for (final k in selector.split('.')) {
    if (cur is Map && cur.containsKey(k)) {
      cur = cur[k];
    } else {
      return null;
    }
  }
  return cur;
}

void setValueBySelector(
    Map<String, dynamic> obj, String selector, dynamic value) {
  final keys = selector.split('.');
  var cur = obj;
  for (var i = 0; i < keys.length - 1; i++) {
    final k = keys[i];
    final next = cur[k];
    if (next is Map<String, dynamic>) {
      cur = next;
    } else {
      final fresh = <String, dynamic>{};
      cur[k] = fresh;
      cur = fresh;
    }
  }
  cur[keys.last] = value;
}

/// Returns true if an actual field value matches the metadata condition's
/// expected value. Supports three common backend variants:
/// - exact scalar equality (`type == 'aiocqhttp'`)
/// - expected value is a list (`type in [...]`)
/// - actual value is a list (`plugin in [...]`)
bool conditionValueMatches(dynamic actual, dynamic expected) {
  if (expected is List) return expected.contains(actual);
  if (actual is List) return actual.contains(expected);
  return actual == expected;
}

/// Shallow check for `metadata.condition`: every (key, expectedValue) pair
/// must match the corresponding value in `obj` (resolved via dotted
/// selector). Mirrors the Vue dashboard's `shouldShowItem`, but adds list
/// matching to handle newer backend metadata.
bool conditionSatisfied(
    Map<String, dynamic>? condition, Map<String, dynamic> obj) {
  if (condition == null || condition.isEmpty) return true;
  for (final entry in condition.entries) {
    final actual = getValueBySelector(obj, entry.key);
    if (!conditionValueMatches(actual, entry.value)) return false;
  }
  return true;
}

Map<String, dynamic> deepCopyMap(Map<String, dynamic> m) =>
    Map<String, dynamic>.from(m.map((k, v) => MapEntry(k, _copyValue(v))));

/// Deep merge where `src` values win: maps recurse, everything else is
/// replaced. Used to combine several section forms that each started from
/// the same whole-config snapshot back into one config on save.
void deepMergeOverwrite(Map<String, dynamic> dst, Map<String, dynamic> src) {
  for (final e in src.entries) {
    final d = dst[e.key];
    if (e.value is Map && d is Map) {
      final dm = d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d);
      dst[e.key] = dm;
      deepMergeOverwrite(dm, Map<String, dynamic>.from(e.value as Map));
    } else {
      dst[e.key] = _copyValue(e.value);
    }
  }
}

dynamic _copyValue(dynamic v) {
  if (v is Map) {
    return Map<String, dynamic>.from(
        v.map((k, vv) => MapEntry(k.toString(), _copyValue(vv))));
  }
  if (v is List) return v.map(_copyValue).toList();
  return v;
}

/// Port of `mergeConfigWithOrder` in ProviderPage.vue / PlatformPage.vue:
/// live config values win; keys the live config is missing are filled from
/// the template default (recursively), so fields newly added to a template
/// show up with their defaults when editing an existing entry.
Map<String, dynamic> mergeWithTemplateDefaults(
    Map<String, dynamic> config, Map<String, dynamic>? template) {
  final out = deepCopyMap(config);
  if (template != null && template.isNotEmpty) {
    _fillMissing(out, template);
  }
  return out;
}

void _fillMissing(Map<String, dynamic> target, Map<String, dynamic> reference) {
  for (final e in reference.entries) {
    final ref = e.value;
    if (ref is Map) {
      final cur = target[e.key];
      if (cur is Map<String, dynamic>) {
        _fillMissing(cur, Map<String, dynamic>.from(ref));
      } else if (cur is Map) {
        final conv = Map<String, dynamic>.from(cur);
        target[e.key] = conv;
        _fillMissing(conv, Map<String, dynamic>.from(ref));
      } else {
        final fresh = <String, dynamic>{};
        target[e.key] = fresh;
        _fillMissing(fresh, Map<String, dynamic>.from(ref));
      }
    } else if (ref is List) {
      target.putIfAbsent(e.key, () => List<dynamic>.from(ref));
    } else {
      target.putIfAbsent(e.key, () => ref);
    }
  }
}
