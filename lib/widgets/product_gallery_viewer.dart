import 'dart:io';

import 'package:flutter/material.dart';

class ProductGalleryViewer extends StatefulWidget {
  const ProductGalleryViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  }) : assert(imagePaths.length > 0);

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<ProductGalleryViewer> createState() => _ProductGalleryViewerState();
}

class _ProductGalleryViewerState extends State<ProductGalleryViewer> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          PageView.builder(
            key: const ValueKey('product-gallery-page-view'),
            controller: _controller,
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.file(
                File(widget.imagePaths[index]),
                key: ValueKey('product-gallery-image-$index'),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 320,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  '${_currentIndex + 1}/${widget.imagePaths.length}',
                  key: const ValueKey('product-gallery-counter'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filledTonal(
              key: const ValueKey('product-gallery-close'),
              tooltip: 'Fechar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
