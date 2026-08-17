/// Full-screen image preview using PhotoView. Pushed when the user taps an
/// image inside a markdown body. Pinch-to-zoom and double-tap-to-zoom both
/// supported by photo_view's defaults.
library;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key, required this.imageUrl, this.heroTag});

  final String imageUrl;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget child = PhotoView(
      imageProvider: NetworkImage(imageUrl),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      loadingBuilder: (_, _) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorBuilder: (_, _, _) => const Center(
        child: Text(
          'Failed to load image.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    if (heroTag != null) {
      child = Hero(tag: heroTag!, child: child);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          imageUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: cs.onSurface, fontSize: 12),
        ),
      ),
      body: child,
    );
  }
}
