import 'dart:io';

import 'package:flutter/material.dart';

class ProductImageGalleryPage extends StatefulWidget {
  const ProductImageGalleryPage({
    super.key,
    required this.images,
    required this.productName,
    this.initialIndex = 0,
  }) : assert(images.length > 0);

  final List<String> images;
  final int initialIndex;
  final String productName;

  @override
  State<ProductImageGalleryPage> createState() =>
      _ProductImageGalleryPageState();
}

class _ProductImageGalleryPageState extends State<ProductImageGalleryPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('product-image-gallery-page'),
      backgroundColor: const Color(0xFF080B10),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _GalleryHeader(
                  productName: widget.productName,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const ValueKey('product-gallery-page-view'),
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => _ZoomableImage(
                      key: ValueKey('product-gallery-image-$index'),
                      imagePath: widget.images[index],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    children: [
                      Text(
                        '${_currentIndex + 1} de ${widget.images.length}',
                        key: const ValueKey('product-gallery-counter'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.images.length > 1) ...[
                        const SizedBox(height: 12),
                        _NavigationDots(
                          count: widget.images.length,
                          currentIndex: _currentIndex,
                          onSelected: (index) => _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({required this.productName, required this.onClose});

  final String productName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('product-gallery-close'),
            tooltip: 'Fechar',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1) {
      _transformationController.value = Matrix4.identity();
      return;
    }

    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 5,
        panEnabled: true,
        scaleEnabled: true,
        clipBehavior: Clip.none,
        child: Center(
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDots extends StatelessWidget {
  const _NavigationDots({
    required this.count,
    required this.currentIndex,
    required this.onSelected,
  });

  final int count;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: List.generate(
        count,
        (index) => GestureDetector(
          key: ValueKey('product-gallery-dot-$index'),
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == currentIndex ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: index == currentIndex ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
