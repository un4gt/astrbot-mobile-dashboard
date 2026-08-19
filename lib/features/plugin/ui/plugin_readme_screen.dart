/// Plugin README viewer. For installed plugins it calls
/// `/api/plugin/readme?name=<n>`; for market-only plugins (no local copy
/// yet) it falls back to GitHub raw README.md derived from [repoUrl].
/// Renders the markdown with image zoom + link sheet via
/// [MarkdownReadmeView]. Mirrors `components/shared/ReadmeDialog.vue`.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/markdown_readme_view.dart';
import '../data/plugin_service.dart';

class PluginReadmeScreen extends ConsumerStatefulWidget {
  const PluginReadmeScreen({
    super.key,
    required this.pluginName,
    this.repoUrl,
    this.fromMarket = false,
  });

  final String pluginName;
  final String? repoUrl;

  /// When true, skip the local API fetch -- the plugin isn't installed yet.
  final bool fromMarket;

  @override
  ConsumerState<PluginReadmeScreen> createState() => _PluginReadmeScreenState();
}

class _PluginReadmeScreenState extends ConsumerState<PluginReadmeScreen> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<String> _load() async {
    if (!widget.fromMarket) {
      try {
        return await ref
            .read(pluginServiceProvider)
            .fetchReadme(widget.pluginName);
      } on ApiException {
        // fall through to repo fallback
      }
    }
    final raw = _repoRawBase();
    if (raw == null) {
      throw ApiException(
        kind: ApiErrorKind.unknown,
        message: context.trM('plugins.readmeNoRepo'),
      );
    }
    // Probe a few likely filenames.
    final candidates = ['README.md', 'README.MD', 'readme.md', 'Readme.md'];
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ));
    try {
      for (final f in candidates) {
        try {
          final res = await dio.get<String>(
            '$raw$f',
            options: Options(responseType: ResponseType.plain),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            return res.data!;
          }
        } on DioException {
          continue;
        }
      }
    } finally {
      dio.close();
    }
    throw ApiException(
      kind: ApiErrorKind.unknown,
      message: '__i18n__:plugins.readmeNotFound',
    );
  }

  /// Best-effort: convert https://github.com/owner/repo[/...] -> the raw
  /// content base so relative image refs in the README load. Picks
  /// `main` as branch since most repos use it; if not found we return null
  /// (caller skips the fallback).
  String? _repoRawBase() {
    final url = widget.repoUrl;
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host != 'github.com') return null;
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return null;
    return 'https://raw.githubusercontent.com/${parts[0]}/${parts[1]}/main/';
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repoBase = _repoRawBase();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.pluginName} · README'),
        actions: [
          if (widget.repoUrl != null)
            IconButton(
              tooltip: context.trM('plugins.openRepo'),
              onPressed: () => launchUrl(Uri.parse(widget.repoUrl!)),
              icon: const Icon(Icons.open_in_new),
            ),
          IconButton(
            tooltip: context.trM('common.refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // _load() throws with an __i18n__:<key> marker so the
                      // message can be localized here, where context exists.
                      () {
                        final msg = e is ApiException ? e.message : e.toString();
                        if (msg.startsWith('__i18n__:')) {
                          return context.trM(msg.substring(9));
                        }
                        return msg;
                      }(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: Text(context.trM('common.retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          final content = (snap.data ?? '').trim();
          if (content.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.trM('plugins.readmeNone')),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: MarkdownReadmeView(
              content: content,
              repoRawBase: repoBase,
            ),
          );
        },
      ),
    );
  }
}
