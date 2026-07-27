import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/product_repository.dart';
import '../models/product.dart';
import '../models/product_image.dart';
import '../services/product_image_selection_service.dart';
import '../services/product_image_storage_service.dart';
import '../widgets/currency_input_formatter.dart';
import '../pages/product_image_gallery_page.dart';


class _GalleryItem {
  _GalleryItem.existing(this.existing)
      : temporary = null,
        isPrimary = existing!.isPrimary;

  _GalleryItem.temporary(this.temporary)
      : existing = null,
        isPrimary = false;

  final ProductImage? existing;
  final TemporaryProductImageFiles? temporary;
  bool isPrimary;

  bool get isTemporary => temporary != null;
  String get imagePath => existing?.imagePath ?? temporary!.imagePath;
  String get thumbnailPath =>
      existing?.thumbnailPath ?? temporary!.thumbnailPath;
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    this.product,
    this.repository,
    this.imageSelectionService,
    this.imageStorageService,
  });

  final Product? product;
  final ProductRepository? repository;
  final ProductImageSelectionService? imageSelectionService;
  final ProductImageStorageService? imageStorageService;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ProductRepository _repository;
  late final ProductImageStorageService _imageStorageService;
  late final ProductImageSelectionService _imageSelectionService;
  final _brandController = TextEditingController();
  final _brandFocusNode = FocusNode();
  final _modelController = TextEditingController();
  final _minimumSizeController = TextEditingController();
  final _maximumSizeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _notesController = TextEditingController();

  static const _popularBrands = <String>[
  'Nike',
  'Adidas',
  'Puma',
  'New Balance',
  'Vans',
  'Lacoste',
  'Oakley',
  'Converse',
  'Asics',
  'Fila',
  'Reebok',
  'Under Armour',
  'Mizuno',
  'Olympikus',
  'Skechers',
  'Jordan',
  'Vert (Veja)',
  'Timberland',
  'DC Shoes',
  'Balenciaga',
];

  List<String> _availableBrands = _popularBrands;
  bool _saving = false;
  bool _selectingImages = false;
  final List<_GalleryItem> _galleryItems = [];
  bool _loadingImages = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _imageStorageService =
        widget.imageStorageService ?? ProductImageStorageService();
    _imageSelectionService = widget.imageSelectionService ??
        ProductImageSelectionService(storageService: _imageStorageService);
    _repository = widget.repository ??
        ProductRepository(imageStorageService: _imageStorageService);
    final product = widget.product;
    _loadBrands();
    if (product == null) return;

    final currency = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    _brandController.text = product.brand;
    _modelController.text = product.model;
    _minimumSizeController.text = product.minimumSize.toString();
    _maximumSizeController.text = product.maximumSize.toString();
    _costPriceController.text = currency.format(product.costPrice);
    if (product.salePrice != null) {
      _salePriceController.text = currency.format(product.salePrice);
    }
    _notesController.text = product.notes ?? '';
    _galleryItems.addAll(product.images.map(_GalleryItem.existing));
    if (_galleryItems.isEmpty && product.id != null) {
      unawaited(_loadExistingImages(product.id!));
    }
  }

  @override
  void dispose() {
    for (final item in _galleryItems.where((item) => item.isTemporary)) {
      unawaited(_imageStorageService.removeTemporary(item.temporary!));
    }
    _brandController.dispose();
    _brandFocusNode.dispose();
    _modelController.dispose();
    _minimumSizeController.dispose();
    _maximumSizeController.dispose();
    _costPriceController.dispose();
    _salePriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    List<String> savedBrands;
    try {
      savedBrands = await _repository.findBrands();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final brands = <String>[];
    for (final brand in [..._popularBrands, ...savedBrands]) {
      final alreadyAdded = brands.any(
        (item) => item.toLowerCase() == brand.toLowerCase(),
      );
      if (!alreadyAdded) brands.add(brand);
    }

    setState(() => _availableBrands = brands);
  }

  void _selectBrand(String brand) {
    setState(() {
      _brandController.value = TextEditingValue(
        text: brand,
        selection: TextSelection.collapsed(offset: brand.length),
      );
    });
    _brandFocusNode.unfocus();
  }

  void _enterAnotherBrand() {
    setState(_brandController.clear);
    _brandFocusNode.requestFocus();
  }

  Iterable<String> _brandOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return _availableBrands;
    return _availableBrands.where(
      (brand) => brand.toLowerCase().contains(query),
    );
  }

  Widget _buildBrandField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<String>(
          textEditingController: _brandController,
          focusNode: _brandFocusNode,
          optionsBuilder: _brandOptions,
          displayStringForOption: (brand) => brand,
          onSelected: _selectBrand,
          fieldViewBuilder: (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Marca *',
                prefixIcon: Icon(Icons.sell_outlined),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              validator: (value) => _requiredText(value, 'a marca'),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final items = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    minWidth: 280,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final brand = items[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sell_outlined, size: 20),
                        title: Text(brand),
                        onTap: () => onSelected(brand),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          'Marcas mais usadas',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5A6575),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._popularBrands.map((brand) {
              final selected =
                  _brandController.text.trim().toLowerCase() ==
                      brand.toLowerCase();
              return ChoiceChip(
                label: Text(brand),
                selected: selected,
                onSelected: (_) => _selectBrand(brand),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Outra'),
              onPressed: _enterAnotherBrand,
            ),
          ],
        ),
      ],
    );
  }

  String? _requiredText(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Informe $label.';
    return null;
  }

  String? _validateMinimumSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a numeração mínima.';
    }
    final number = int.tryParse(value);
    if (number == null || number <= 0) return 'Informe uma numeração válida.';
    return null;
  }

  String? _validateMaximumSize(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a numeração máxima.';
    }
    final maximum = int.tryParse(value);
    final minimum = int.tryParse(_minimumSizeController.text);
    if (maximum == null || maximum <= 0) {
      return 'Informe uma numeração válida.';
    }
    if (minimum != null && maximum < minimum) {
      return 'A numeração máxima deve ser igual ou maior que a mínima.';
    }
    return null;
  }

  String? _validateCost(String? value) {
    final amount = CurrencyInputFormatter.parse(value ?? '');
    if (amount == null) return 'Informe o valor de custo.';
    if (amount <= 0) return 'O valor de custo deve ser maior que zero.';
    return null;
  }

  String? _validateOptionalSalePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = CurrencyInputFormatter.parse(value);
    if (amount == null || amount <= 0) {
      return 'O valor de venda deve ser maior que zero.';
    }
    return null;
  }


  int get _availableImageSlots => 5 - _galleryItems.length;

  Future<void> _loadExistingImages(int productId) async {
    setState(() => _loadingImages = true);
    try {
      final images = await _repository.getImagesByProductId(productId);
      if (!mounted) return;
      setState(() {
        _galleryItems
          ..removeWhere((item) => !item.isTemporary)
          ..insertAll(0, images.map(_GalleryItem.existing));
      });
    } catch (_) {
      // O formulário continua utilizável mesmo se as fotos não puderem ser lidas.
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _selectImages() async {
    final available = _availableImageSlots;
    if (available <= 0) {
      _showMessage('Este tênis já possui o limite de 5 fotos.');
      return;
    }

    setState(() => _selectingImages = true);
    try {
      final result = await _imageSelectionService.selectAndPrepare(
        availableSlots: available,
      );
      if (!mounted || result.cancelled) return;
      setState(() {
        final wasEmpty = _galleryItems.isEmpty;
        _galleryItems.addAll(result.images.map(_GalleryItem.temporary));
        if (wasEmpty && _galleryItems.isNotEmpty) {
          _setPrimary(0, notify: false);
        }
      });
    } on ProductImageStorageException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível preparar as fotos. Verifique os arquivos e o espaço disponível no aparelho.',
        );
      }
    } finally {
      if (mounted) setState(() => _selectingImages = false);
    }
  }

  Future<void> _removeImage(int index) async {
    final item = _galleryItems.removeAt(index);
    final removedPrimary = item.isPrimary;
    if (removedPrimary && _galleryItems.isNotEmpty) {
      _setPrimary(0, notify: false);
    }
    setState(() {});
    if (item.isTemporary) {
      try {
        await _imageStorageService.removeTemporary(item.temporary!);
      } catch (_) {
        if (mounted) _showMessage('Não foi possível remover o arquivo temporário.');
      }
    }
  }

  void _setPrimary(int index, {bool notify = true}) {
    for (var i = 0; i < _galleryItems.length; i++) {
      _galleryItems[i].isPrimary = i == index;
    }
    if (notify) setState(() {});
  }

  void _moveImage(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _galleryItems.length) return;
    setState(() {
      final item = _galleryItems.removeAt(index);
      _galleryItems.insert(target, item);
    });
  }

  Future<void> _previewImage(_GalleryItem item) async {
    final initialIndex = _galleryItems.indexOf(item);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductImageGalleryPage(
          images: _galleryItems.map((entry) => entry.imagePath).toList(),
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          productName: '${_brandController.text.trim()} — ${_modelController.text.trim()}',
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildImageSection() {
    final available = _availableImageSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Fotos do tênis', style: Theme.of(context).textTheme.titleMedium),
            ),
            Text('${_galleryItems.length}/5'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          available > 0
              ? 'Você pode selecionar mais $available foto(s).'
              : 'Limite de 5 fotos atingido.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_loadingImages) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_galleryItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = _galleryItems[index];
                return SizedBox(
                  width: 124,
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _previewImage(item),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(item.thumbnailPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Color(0xFFE9EDF2),
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                                if (item.isPrimary)
                                  const Positioned(
                                    left: 6,
                                    top: 6,
                                    child: Chip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: Icon(Icons.star, size: 14),
                                      label: Text('Principal'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: IconButton(
                                tooltip: 'Mover para esquerda',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: index == 0 || _saving
                                    ? null
                                    : () => _moveImage(index, -1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                            ),
                            Expanded(
                              child: PopupMenuButton<String>(
                                tooltip: 'Ações da foto',
                                enabled: !_saving,
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'primary') _setPrimary(index);
                                  if (value == 'remove') _removeImage(index);
                                  if (value == 'view') _previewImage(item);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('Visualizar'),
                                  ),
                                  if (!item.isPrimary)
                                    const PopupMenuItem(
                                      value: 'primary',
                                      child: Text('Definir como principal'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remover'),
                                  ),
                                ],
                                child: const SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: Icon(Icons.more_vert),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: IconButton(
                                tooltip: 'Mover para direita',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 40,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: index == _galleryItems.length - 1 || _saving
                                    ? null
                                    : () => _moveImage(index, 1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving || _selectingImages || available <= 0 ? null : _selectImages,
          icon: _selectingImages
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_selectingImages ? 'Abrindo galeria...' : 'Adicionar fotos'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toque na foto para visualizar. Use o menu para definir a principal ou remover e as setas para reorganizar. As mudanças só serão aplicadas ao salvar.',
        ),
      ],
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final product = Product(
        id: widget.product?.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        minimumSize: int.parse(_minimumSizeController.text),
        maximumSize: int.parse(_maximumSizeController.text),
        costPrice: CurrencyInputFormatter.parse(_costPriceController.text)!,
        salePrice: CurrencyInputFormatter.parse(_salePriceController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final savedProduct = await _repository.save(product);
      final productId = savedProduct.id;
      if (productId == null) {
        throw StateError('O tênis salvo não possui identificador.');
      }
      if (_galleryItems.isNotEmpty || _editing) {
        final temporary = _galleryItems
            .where((item) => item.isTemporary)
            .map((item) => item.temporary!)
            .toList();
        final primaryIndex = _galleryItems.isEmpty
            ? -1
            : _galleryItems.indexWhere((item) => item.isPrimary);
        await _repository.saveImageGallery(
          productId: productId,
          orderedImageIds: _galleryItems
              .map((item) => item.existing?.id)
              .toList(),
          temporaryImages: temporary,
          primaryIndex: primaryIndex < 0 && _galleryItems.isNotEmpty ? 0 : primaryIndex,
        );
        _galleryItems.removeWhere((item) => item.isTemporary);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ProductImageStorageException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível salvar o tênis e suas fotos. Verifique o espaço disponível no aparelho.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar tênis' : 'Novo tênis'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                _editing
                    ? 'Atualize as informações do modelo.'
                    : 'Cadastre o modelo recebido da fábrica.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5A6575),
                    ),
              ),
              const SizedBox(height: 24),
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildBrandField(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo *',                  prefixIcon: Icon(Icons.directions_run_outlined),
                ),
                validator: (value) => _requiredText(value, 'o modelo'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimumSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Numeração mínima *',
                      ),
                      validator: _validateMinimumSize,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maximumSizeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Numeração máxima *',
                      ),
                      validator: _validateMaximumSize,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor de custo *',                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: _validateCost,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salePriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Valor de venda',                  prefixIcon: Icon(Icons.price_check_outlined),
                ),
                validator: _validateOptionalSalePrice,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Observações',                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving || _loadingImages ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Salvando...' : 'Salvar tênis'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
