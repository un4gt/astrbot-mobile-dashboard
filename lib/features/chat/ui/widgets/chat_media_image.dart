/// Cached image fetched from `/api/chat/get_file?filename=<name>`. Wrapped
/// in a Riverpod future provider so identical media in different bubbles
/// shares one fetch.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_service.dart';

final mediaBytesProvider =
    FutureProvider.family<Uint8List, String>((ref, name) async {
  return ref.watch(chatServiceProvider).getMediaBytes(name);
});

class ChatMediaImage extends ConsumerWidget {
  const ChatMediaImage({
    super.key,
    required this.filename,
    this.maxWidth = 240,
  });

  final String filename;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(mediaBytesProvider(filename));
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: bytes.when(
        loading: () => Container(
          height: 96,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => Container(
          height: 64,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
        data: (data) => GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _MemoryImagePreview(bytes: data, name: filename),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(data, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _MemoryImagePreview extends StatelessWidget {
  const _MemoryImagePreview({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ImagePreviewScreenForBytes(bytes: bytes, name: name);
  }
}

class ImagePreviewScreenForBytes extends StatelessWidget {
  const ImagePreviewScreenForBytes({
    super.key,
    required this.bytes,
    required this.name,
  });
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}
