import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../components/components.dart';
import '../utils/import_file.dart';

AppStatusBadge _siNo(bool value) => AppStatusBadge(
      label: value ? 'Sí' : 'No',
      tone: value ? AppBadgeTone.success : AppBadgeTone.neutral,
    );

/// Modal "ver detalle" de un producto, con los mismos datos que la web en
/// `/productos`: la pestaña General trae las columnas de la tabla y Adicional
/// las de la fila expandida. Devuelve `true` si el usuario pulsó "Editar"; con
/// [canEdit] falso no hay botón de editar.
Future<bool?> showProductDetail(
  BuildContext context,
  ProductEntity p, {
  bool canEdit = true,
}) {
  return showAppModal(
    context,
    title: p.name,
    subtitle: p.codigo.isEmpty ? null : p.codigo,
    icon: Icons.category_outlined,
    primaryLabel: canEdit ? 'Editar' : null,
    secondaryLabel: 'Cerrar',
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Tipo', value: p.esServicio ? 'Servicio' : 'Producto'),
            AppDetailRow(label: 'Código', value: p.codigo),
            AppDetailRow(label: 'Descripción', value: p.name),
            AppDetailRow(label: 'Marca', value: p.marca),
            AppDetailRow(label: 'Categoría', value: p.categoria),
            AppDetailRow(label: 'U. de medida', value: p.unidadLabel),
            AppDetailRow(
              label: 'Estado',
              valueWidget: AppStatusBadge(
                label: p.activo ? 'Activo' : 'Inactivo',
                tone: p.activo ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ),
          ],
        ),
      ),
      AppTabItem(
        label: 'Adicional',
        icon: Icons.list_alt_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDetailRow(label: 'Código de barra', value: p.codBarra),
            AppDetailRow(label: 'SKU', value: p.sku),
            AppDetailRow(label: 'Proveedor', value: p.proveedor),
            AppDetailRow(label: 'Adicional', value: p.descripcion),
            AppDetailRow(label: 'Usuario', value: p.usuario),
            AppDetailRow(label: 'Venta sin stock', valueWidget: _siNo(p.ventaSinStock)),
            AppDetailRow(label: 'Duplicar', valueWidget: _siNo(p.duplicar)),
            AppDetailRow(
              label: 'Creado',
              value: p.creado == null
                  ? null
                  : DateFormat(AppConstants.dateFormat).format(p.creado!),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Valores del formulario mientras se edita.
class _ProductFormValues {
  String tipo;
  final TextEditingController codigo;
  final TextEditingController sku;
  final TextEditingController name;
  final TextEditingController codBarra;
  final TextEditingController cantidad;
  final TextEditingController descripcion;
  bool estado;
  bool ventaSinStock;
  bool duplicar;
  int? measureId;
  int? brandId;
  int? categoryId;
  int? providerId;
  int? canalId;
  int? giroId;
  ProductPhotoEntity? foto;
  bool eliminarImagen = false;

  _ProductFormValues(ProductEntity? p)
      : tipo = (p?.esServicio ?? false) ? 's' : 'p',
        codigo = TextEditingController(text: p?.codigo),
        sku = TextEditingController(text: p?.sku),
        name = TextEditingController(text: p?.name),
        codBarra = TextEditingController(text: p?.codBarra),
        cantidad = TextEditingController(text: p?.cantidadBloque?.toString()),
        descripcion = TextEditingController(text: p?.descripcion),
        estado = p?.activo ?? true,
        ventaSinStock = p?.ventaSinStock ?? false,
        duplicar = p?.duplicar ?? false,
        measureId = p?.unidadId,
        brandId = p?.marcaId,
        categoryId = p?.categoriaId,
        providerId = p?.proveedorId,
        canalId = p?.canalId,
        giroId = p?.giroNegocioId;

  void dispose() {
    for (final c in [codigo, sku, name, codBarra, cantidad, descripcion]) {
      c.dispose();
    }
  }

  /// `null` si falta algún dato obligatorio.
  ProductFormEntity? toEntity() {
    final brand = brandId, category = categoryId, provider = providerId;
    final canal = canalId, giro = giroId;
    if (brand == null || category == null || provider == null || canal == null || giro == null) {
      return null;
    }
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return ProductFormEntity(
      tipo: tipo,
      codigo: codigo.text.trim(),
      sku: text(sku),
      name: name.text.trim(),
      estado: estado,
      measureId: measureId,
      cantidadBloque: int.tryParse(cantidad.text.trim()),
      brandId: brand,
      codBarra: text(codBarra),
      categoryId: category,
      ventaSinStock: ventaSinStock,
      providerId: provider,
      duplicar: duplicar,
      canalId: canal,
      giroNegocioId: giro,
      descripcion: text(descripcion),
      foto: foto,
      eliminarImagen: eliminarImagen,
    );
  }
}

/// Carga los catálogos del formulario, deja elegidos el canal y el giro por defecto al crear
/// (como la web) y suma los elementos que se crean con el "+".
class _CatalogsLoader extends ChangeNotifier {
  final Future<ProductCatalogsEntity> Function() _load;
  final _ProductFormValues _values;
  final bool _editing;

  /// `true` cuando los catálogos ya están cargados y se puede guardar.
  final ready = ValueNotifier<bool>(false);

  bool loading = true;
  String? error;
  bool _disposed = false;

  List<CatalogItemEntity> marcas = const [];
  List<CatalogItemEntity> categorias = const [];
  List<CatalogItemEntity> medidas = const [];
  List<CatalogItemEntity> proveedores = const [];
  List<CatalogItemEntity> canales = const [];
  List<CatalogItemEntity> giros = const [];

  _CatalogsLoader(this._load, this._values, this._editing) {
    load();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final c = await _load();
      if (_disposed) return;
      marcas = c.marcas;
      categorias = c.categorias;
      medidas = c.medidas;
      proveedores = c.proveedores;
      canales = c.canales;
      giros = c.giros;
      if (!_editing) {
        _values.canalId ??= _default(canales, 'ELECTRÓNICA');
        _values.giroId ??= _default(giros, 'CAR AUDIO');
      }
      ready.value = true;
    } catch (e) {
      if (_disposed) return;
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;
    notifyListeners();
  }

  int? _default(List<CatalogItemEntity> items, String preferred) {
    if (items.isEmpty) return null;
    for (final i in items) {
      if (i.name == preferred) return i.id;
    }
    return items.reduce((a, b) => a.id < b.id ? a : b).id;
  }

  /// Suma un elemento recién creado al principio de su catálogo y lo deja elegido.
  void add(CatalogKind kind, CatalogItemEntity item) {
    List<CatalogItemEntity> prepend(List<CatalogItemEntity> list) => [item, ...list];
    switch (kind) {
      case CatalogKind.medida:
        medidas = prepend(medidas);
        _values.measureId = item.id;
      case CatalogKind.marca:
        marcas = prepend(marcas);
        _values.brandId = item.id;
      case CatalogKind.categoria:
        categorias = prepend(categorias);
        _values.categoryId = item.id;
      case CatalogKind.canal:
        canales = prepend(canales);
        _values.canalId = item.id;
      case CatalogKind.giro:
        giros = prepend(giros);
        _values.giroId = item.id;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ready.dispose();
    super.dispose();
  }
}

/// Formulario de producto para crear ([product] nulo) o editar: un solo formulario con los mismos
/// campos y en el mismo orden que el de la web (tipo, código, SKU, descripción, estado, unidad de
/// medida, cantidad, marca, código de barras, categoría, vender sin stock, proveedor, duplicar,
/// canal, giro de negocio, adicional y foto), con el "+" para crear al vuelo marcas, categorías,
/// unidades, canales y giros. [onSubmit] devuelve `null` si guardó o el mensaje de error, que se
/// muestra dentro del modal sin cerrarlo.
Future<bool?> showProductForm(
  BuildContext context, {
  ProductEntity? product,
  required Future<ProductCatalogsEntity> Function() loadCatalogs,
  required Future<CatalogItemEntity> Function(CatalogKind kind, String name) createCatalogItem,
  required Future<String?> Function(ProductFormEntity form) onSubmit,
  Future<PickedPhoto?> Function() pickPhoto = pickProductPhoto,
}) {
  final values = _ProductFormValues(product);
  final editing = product != null;
  final loader = _CatalogsLoader(loadCatalogs, values, editing);
  final formKey = GlobalKey<FormState>();
  final error = ValueNotifier<String?>(null);

  return showAppModal(
    context,
    title: editing ? 'Editar producto' : 'Nuevo producto',
    subtitle: editing ? product.name : 'Completa los datos del producto',
    icon: editing ? Icons.edit_outlined : Icons.add_box_outlined,
    primaryLabel: editing ? 'Guardar cambios' : 'Crear producto',
    formKey: formKey,
    primaryEnabled: loader.ready,
    error: error,
    onPrimary: () async {
      error.value = null;
      final form = values.toEntity();
      if (form == null) {
        error.value = 'Completa los campos obligatorios';
        throw StateError('formulario incompleto');
      }
      final message = await onSubmit(form);
      if (message != null) {
        error.value = message;
        throw StateError(message);
      }
    },
    child: AppDisposer(
      onDispose: [values.dispose, loader.dispose, error.dispose],
      child: _ProductFormBody(
        values: values,
        loader: loader,
        product: product,
        createCatalogItem: createCatalogItem,
        pickPhoto: pickPhoto,
      ),
    ),
  );
}

const _gap = SizedBox(height: 16);

/// Dos campos lado a lado cuando hay ancho (tableta), uno bajo el otro en el celular.
Widget _pair(Widget a, Widget b) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 480) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [a, _gap, b],
      );
    },
  );
}

Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
  return SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}

class _ProductFormBody extends StatefulWidget {
  final _ProductFormValues values;
  final _CatalogsLoader loader;
  final ProductEntity? product;
  final Future<CatalogItemEntity> Function(CatalogKind kind, String name) createCatalogItem;
  final Future<PickedPhoto?> Function() pickPhoto;

  const _ProductFormBody({
    required this.values,
    required this.loader,
    required this.product,
    required this.createCatalogItem,
    required this.pickPhoto,
  });

  @override
  State<_ProductFormBody> createState() => _ProductFormBodyState();
}

class _ProductFormBodyState extends State<_ProductFormBody> {
  String? _photoError;

  _ProductFormValues get v => widget.values;
  bool get _editing => widget.product != null;

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  /// Lista del catálogo con su "+" para crear un elemento nuevo, como la web.
  Widget _catalog({
    required String label,
    required CatalogKind? kind,
    required List<CatalogItemEntity> items,
    required int? value,
    required ValueChanged<int?> onChanged,
    bool required = false,
  }) {
    final field = AppDropdownField<int>(
      // Al sumar un elemento nuevo la lista cambia de tamaño y el campo se rearma con él elegido.
      key: ValueKey('$label-${items.length}'),
      label: required ? '$label *' : label,
      value: items.any((i) => i.id == value) ? value : null,
      items: [
        for (final i in items)
          DropdownMenuItem<int>(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
      validator: required ? (id) => id == null ? 'Selecciona una opción' : null : null,
    );
    if (kind == null) return field;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: 'Crear ${kind.label.toLowerCase()}',
            icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
            onPressed: () => _create(kind),
          ),
        ),
      ],
    );
  }

  /// Crea una marca, categoría, unidad, canal o giro y lo deja elegido.
  Future<void> _create(CatalogKind kind) async {
    final controller = TextEditingController();
    final error = ValueNotifier<String?>(null);
    CatalogItemEntity? created;

    await showAppModal(
      context,
      title: 'Crear ${kind.label.toLowerCase()}',
      icon: Icons.add_circle_outline,
      primaryLabel: 'Crear',
      error: error,
      onPrimary: () async {
        error.value = null;
        try {
          created = await widget.createCatalogItem(kind, controller.text);
        } catch (e) {
          error.value = e.toString().replaceFirst('Exception: ', '');
          // Mantiene el modal abierto para corregir el nombre.
          throw StateError('no se creó');
        }
      },
      child: AppDisposer(
        onDispose: [controller.dispose, error.dispose],
        child: AppTextField(controller: controller, label: 'Nombre de ${kind.articulado}'),
      ),
    );

    final item = created;
    if (item == null || !mounted) return;
    setState(() => widget.loader.add(kind, item));
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await widget.pickPhoto();
      if (photo == null || !mounted) return;
      setState(() {
        v.foto = ProductPhotoEntity(name: photo.name, bytes: photo.bytes);
        _photoError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _photoError = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _photoBlock() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = widget.product?.imagen;
    final showCurrent = current != null && !v.eliminarImagen && v.foto == null;
    final photo = v.foto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrent) ...[
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '${ApiConstants.baseDomain}$current',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  headers: {if (ApiConstants.apiHost.isNotEmpty) 'Host': ApiConstants.apiHost},
                  errorBuilder: (_, _, _) => SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Imagen actual', style: theme.textTheme.bodyMedium)),
              TextButton.icon(
                onPressed: () => setState(() => v.eliminarImagen = true),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar imagen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: _pickPhoto,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline),
            ),
            child: photo == null
                ? Column(
                    children: [
                      Icon(Icons.photo_camera_outlined, size: 36, color: scheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        v.eliminarImagen || current != null ? 'Cambiar foto del producto' : 'Subir foto del producto',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG o WEBP de menos de 2 MB',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          photo.bytes,
                          height: 140,
                          fit: BoxFit.contain,
                          // Un archivo dañado no se puede mostrar, pero el servidor decide si lo acepta.
                          errorBuilder: (_, _, _) => SizedBox(
                            height: 140,
                            child: Icon(Icons.broken_image_outlined, size: 48, color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(photo.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      TextButton.icon(
                        onPressed: () => setState(() => v.foto = null),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Quitar foto'),
                      ),
                    ],
                  ),
          ),
        ),
        if (v.eliminarImagen)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => v.eliminarImagen = false),
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Se eliminará la imagen actual. Deshacer'),
            ),
          ),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Text(
              _photoError!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.loader,
      builder: (context, _) {
        final c = widget.loader;
        if (c.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (c.error != null) {
          return Column(
            children: [
              ErrorBanner(message: c.error!),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: c.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdownField<String>(
              label: 'Tipo *',
              value: v.tipo,
              items: const [
                DropdownMenuItem(value: 'p', child: Text('Producto')),
                DropdownMenuItem(value: 's', child: Text('Servicio')),
              ],
              onChanged: (t) => setState(() => v.tipo = t ?? 'p'),
            ),
            _gap,
            _pair(
              AppTextField(
                controller: v.codigo,
                label: 'Código *',
                textInputAction: TextInputAction.next,
                validator: (t) => _required(t, 'El código es requerido'),
              ),
              AppTextField(
                controller: v.sku,
                label: _editing ? 'SKU *' : 'SKU',
                textInputAction: TextInputAction.next,
                validator: _editing ? (t) => _required(t, 'El SKU es requerido') : null,
              ),
            ),
            _gap,
            _pair(
              AppTextField(
                controller: v.name,
                label: 'Descripción *',
                textInputAction: TextInputAction.next,
                validator: (t) => _required(t, 'La descripción es requerida'),
              ),
              _switch('Estado', v.estado, (b) => setState(() => v.estado = b)),
            ),
            _gap,
            _pair(
              _catalog(
                label: 'Unidad de medida',
                kind: CatalogKind.medida,
                items: c.medidas,
                value: v.measureId,
                onChanged: (id) => setState(() => v.measureId = id),
              ),
              AppTextField(
                controller: v.cantidad,
                label: 'Cantidad',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (t) =>
                    (t == null || t.trim().isEmpty || int.tryParse(t.trim()) != null)
                        ? null
                        : 'Debe ser un número entero',
              ),
            ),
            _gap,
            _pair(
              _catalog(
                label: 'Marca',
                kind: CatalogKind.marca,
                items: c.marcas,
                value: v.brandId,
                required: true,
                onChanged: (id) => setState(() => v.brandId = id),
              ),
              AppTextField(
                controller: v.codBarra,
                label: 'Código de barras',
                textInputAction: TextInputAction.next,
              ),
            ),
            _gap,
            _pair(
              _catalog(
                label: 'Categoría',
                kind: CatalogKind.categoria,
                items: c.categorias,
                value: v.categoryId,
                required: true,
                onChanged: (id) => setState(() => v.categoryId = id),
              ),
              _switch(
                'Vender sin stock',
                v.ventaSinStock,
                (b) => setState(() => v.ventaSinStock = b),
              ),
            ),
            _gap,
            _pair(
              _catalog(
                label: 'Proveedor',
                kind: null,
                items: c.proveedores,
                value: v.providerId,
                required: true,
                onChanged: (id) => setState(() => v.providerId = id),
              ),
              _switch('Duplicar', v.duplicar, (b) => setState(() => v.duplicar = b)),
            ),
            _gap,
            _pair(
              _catalog(
                label: 'Canal',
                kind: CatalogKind.canal,
                items: c.canales,
                value: v.canalId,
                required: true,
                onChanged: (id) => setState(() => v.canalId = id),
              ),
              _catalog(
                label: 'Giro de negocio',
                kind: CatalogKind.giro,
                items: c.giros,
                value: v.giroId,
                required: true,
                onChanged: (id) => setState(() => v.giroId = id),
              ),
            ),
            _gap,
            AppTextField(
              controller: v.descripcion,
              label: 'Adicional',
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),
            _gap,
            _photoBlock(),
          ],
        );
      },
    );
  }
}

/// Filas del Excel que el servidor no pudo importar, con el motivo de cada una. El resto del
/// archivo sí se subió (igual que en la web).
Future<void> showImportFailures(
  BuildContext context, {
  required ImportKind kind,
  required List<ImportFailureEntity> failures,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  return showAppModal(
    context,
    title: 'Filas con errores',
    subtitle: 'Se subieron los ${kind.label.toLowerCase()} excepto estas filas',
    icon: Icons.error_outline,
    tone: AppModalTone.warning,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: failures.length,
        separatorBuilder: (_, _) => const Divider(height: 20),
        itemBuilder: (context, i) {
          final failure = failures[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error en fila ${failure.row}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final error in failure.errors)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: scheme.error)),
                      Expanded(child: Text(error)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
