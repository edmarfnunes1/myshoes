import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'product_image_storage_service.dart';

class ProductImageSelectionResult {
  const ProductImageSelectionResult({
    required this.images,
    this.cancelled = false,
  });

  final List<TemporaryProductImageFiles> images;
  final bool cancelled;
}

/// Abre a galeria e prepara as imagens em uma área temporária.
typedef MultiImagePickerCallback = Future<List<XFile>> Function(int limit);

class ProductImageSelectionService {
  ProductImageSelectionService({
    ImagePicker? picker,
    MultiImagePickerCallback? pickImages,
    ProductImageStorageService? storageService,
  })  : _pickImages = pickImages ??
            ((limit) => (picker ?? ImagePicker()).pickMultiImage(
                  limit: limit,
                  imageQuality: 100,
                )),
        _storageService = storageService ?? ProductImageStorageService();

  final MultiImagePickerCallback _pickImages;
  final ProductImageStorageService _storageService;

  Future<ProductImageSelectionResult> selectAndPrepare({
    required int availableSlots,
  }) async {
    if (availableSlots <= 0) {
      throw const ProductImageStorageException(
        'Este tênis já possui o limite de 5 fotos.',
      );
    }

    final selected = await _pickImages(availableSlots);
    if (selected.isEmpty) {
      return const ProductImageSelectionResult(images: [], cancelled: true);
    }

    if (selected.length > availableSlots) {
      throw ProductImageStorageException(
        'Você pode selecionar no máximo $availableSlots foto(s).',
      );
    }

    final prepared = <TemporaryProductImageFiles>[];
    try {
      for (final image in selected) {
        prepared.add(
          await _storageService.prepareTemporary(
            sourceFile: File(image.path),
          ),
        );
      }
      return ProductImageSelectionResult(images: prepared);
    } catch (_) {
      for (final image in prepared) {
        await _storageService.removeTemporary(image);
      }
      rethrow;
    }
  }
}
