/// GitHub-flavored markdown renderer used by the plugin README dialog (and
/// any future place we surface markdown content). Wraps `flutter_markdown`
/// with three integrations:
///
/// 1. **Tap-to-zoom images**: any `![]()` rendered as `Image.network` is
///    wrapped in a GestureDetector that pushes a full-screen `PhotoView`.
///    Relative URLs are resolved against `repoRawBase` if provided.
/// 2. **Link bottom-sheet**: `onTapLink` opens [showLinkActionSheet] so the
///    user picks "Open in browser / Copy / Share" rather than silently
///    leaving the app.
/// 3. **GFM tasklists**: `extensionSet: ExtensionSet.gitHubFlavored` enables
///    `[ ] / [x]` checkboxes; flutter_markdown renders them with its
///    default checkbox builder (read-only -- README context).
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'image_preview_screen.dart';
import 'link_action_sheet.dart';

class MarkdownReadmeView extends StatelessWidget {
  const MarkdownReadmeView({
    super.key,
    required this.content,
    this.repoRawBase,
  });

  /// Raw markdown body.
  final String content;

  /// Optional base URL to resolve relative image / link refs against,
  /// typically `https://raw.githubusercontent.com/<owner>/<repo>/<branch>/`.
  final String? repoRawBase;

  Uri? _resolveAsset(String src) {
    final candidate = Uri.tryParse(src);
    if (candidate == null) return null;
    if (candidate.hasScheme) return candidate;
    if (repoRawBase == null) return candidate;
    final base = Uri.tryParse(repoRawBase!);
    if (base == null) return candidate;
    return base.resolveUri(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Markdown(
      data: content,
      selectable: true,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (text, href, title) {
        if (href == null || href.isEmpty) return;
        final resolved = _resolveAsset(href)?.toString() ?? href;
        showLinkActionSheet(context, resolved);
      },
      sizedImageBuilder: (config) {
        final resolved = _resolveAsset(config.uri.toString());
        if (resolved == null) return Text(config.alt ?? '');
        return _ZoomableImage(uri: resolved, alt: config.alt);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium,
        h1: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        h2: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
        h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        h4: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.onSurface,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border(
            left: BorderSide(color: cs.primary.withValues(alpha: 0.6), width: 4),
          ),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        a: TextStyle(
          color: cs.primary,
          decoration: TextDecoration.underline,
          decorationColor: cs.primary.withValues(alpha: 0.4),
        ),
        tableBorder: TableBorder.all(
          color: cs.outlineVariant,
          width: 0.5,
        ),
        tableHead: const TextStyle(fontWeight: FontWeight.w700),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cs.outlineVariant),
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({required this.uri, this.alt});
  final Uri uri;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final tag = uri.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onDoubleTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImagePreviewScreen(imageUrl: tag, heroTag: tag),
          ),
        ),
        child: Stack(
          children: [
            Hero(
              tag: tag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  tag,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 96,
                      alignment: Alignment.center,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    height: 64,
                    alignment: Alignment.center,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(alt ?? tag,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle hint that the image is double-tap zoomable.
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'double-tap',
                      style:
                          TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
