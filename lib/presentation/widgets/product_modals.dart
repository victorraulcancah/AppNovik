import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_form_entity.dart';
import '../components/components.dart';

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
    );
  }
}

/// Carga los catálogos del formulario y deja elegidos el canal y el giro por
/// defecto al crear, como la web.
class _CatalogsLoader extends ChangeNotifier {
  final Future<ProductCatalogsEntity> Function() _load;
  final _ProductFormValues _values;
  final bool _editing;
  late Future<ProductCatalogsEntity> future = _run();

  _CatalogsLoader(this._load, this._values, this._editing);

  void retry() {
    future = _run();
    notifyListeners();
  }

  Future<ProductCatalogsEntity> _run() async {
    final catalogs = await _load();
    if (!_editing) {
      _values.canalId ??= _default(catalogs.canales, 'ELECTRÓNICA');
      _values.giroId ??= _default(catalogs.giros, 'CAR AUDIO');
    }
    return catalogs;
  }

  int? _default(List<CatalogItemEntity> items, String preferred) {
    if (items.isEmpty) return null;
    for (final i in items) {
      if (i.name == preferred) return i.id;
    }
    return items.reduce((a, b) => a.id < b.id ? a : b).id;
  }
}

/// Formulario de producto para crear ([product] nulo) o editar, con los mismos
/// campos que pide la web, repartidos en pestañas (General, Clasificación y
/// Más opciones). [onSubmit] devuelve `null` si guardó o el mensaje de error,
/// que se muestra dentro del modal sin cerrarlo.
Future<bool?> showProductForm(
  BuildContext context, {
  ProductEntity? product,
  required Future<ProductCatalogsEntity> Function() loadCatalogs,
  required Future<String?> Function(ProductFormEntity form) onSubmit,
}) {
  final values = _ProductFormValues(product);
  final editing = product != null;
  final loader = _CatalogsLoader(loadCatalogs, values, editing);
  final tabs = AppTabsController();
  final forms = List.generate(3, (_) => GlobalKey<FormState>());
  final error = ValueNotifier<String?>(null);

  return showAppModal(
    context,
    title: editing ? 'Editar producto' : 'Nuevo producto',
    subtitle: editing ? product.name : 'Completa los datos del producto',
    icon: editing ? Icons.edit_outlined : Icons.add_box_outlined,
    primaryLabel: editing ? 'Guardar cambios' : 'Crear producto',
    tabsController: tabs,
    error: error,
    onPrimary: () async {
      error.value = null;
      // Valida cada pestaña; salta a la primera que tenga errores.
      if (!tabs.validate(forms)) throw StateError('formulario inválido');

      final form = values.toEntity();
      if (form == null) {
        error.value = 'Completa los campos obligatorios';
        tabs.select(1);
        throw StateError('formulario incompleto');
      }
      final message = await onSubmit(form);
      if (message != null) {
        error.value = message;
        throw StateError(message);
      }
    },
    tabs: [
      AppTabItem(
        label: 'General',
        icon: Icons.info_outline,
        child: Form(key: forms[0], child: _GeneralTab(values: values, editing: editing)),
      ),
      AppTabItem(
        label: 'Clasificación',
        icon: Icons.category_outlined,
        child: Form(key: forms[1], child: _ClassificationTab(values: values, loader: loader)),
      ),
      AppTabItem(
        label: 'Más opciones',
        icon: Icons.tune,
        child: Form(key: forms[2], child: _OptionsTab(values: values)),
      ),
    ],
  );
}

const _gap = SizedBox(height: 16);

Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
  return SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}

/// Tipo, código, SKU, descripción y estado.
class _GeneralTab extends StatefulWidget {
  final _ProductFormValues values;
  final bool editing;

  const _GeneralTab({required this.values, required this.editing});

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  String? _required(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final v = widget.values;
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
        AppTextField(
          controller: v.codigo,
          label: 'Código *',
          textInputAction: TextInputAction.next,
          validator: (t) => _required(t, 'El código es requerido'),
        ),
        _gap,
        AppTextField(
          controller: v.sku,
          label: widget.editing ? 'SKU *' : 'SKU (opcional)',
          textInputAction: TextInputAction.next,
          validator: widget.editing ? (t) => _required(t, 'El SKU es requerido') : null,
        ),
        _gap,
        AppTextField(
          controller: v.name,
          label: 'Descripción *',
          validator: (t) => _required(t, 'La descripción es requerida'),
        ),
        _switch('Estado (activo)', v.estado, (b) => setState(() => v.estado = b)),
      ],
    );
  }
}

/// Marca, categoría, unidad de medida, proveedor, canal y giro: vienen de los
/// catálogos de la empresa.
class _ClassificationTab extends StatefulWidget {
  final _ProductFormValues values;
  final _CatalogsLoader loader;

  const _ClassificationTab({required this.values, required this.loader});

  @override
  State<_ClassificationTab> createState() => _ClassificationTabState();
}

class _ClassificationTabState extends State<_ClassificationTab> {
  Widget _catalog({
    required String label,
    required List<CatalogItemEntity> items,
    required int? value,
    required ValueChanged<int?> onChanged,
    bool required = false,
  }) {
    return AppDropdownField<int>(
      label: required ? '$label *' : label,
      value: items.any((i) => i.id == value) ? value : null,
      items: [
        for (final i in items)
          DropdownMenuItem<int>(
            value: i.id,
            child: Text(i.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Selecciona una opción' : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.values;

    return ListenableBuilder(
      listenable: widget.loader,
      builder: (context, _) => FutureBuilder<ProductCatalogsEntity>(
        future: widget.loader.future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                ErrorBanner(
                  message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: widget.loader.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            );
          }

          final c = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _catalog(
                label: 'Marca',
                items: c.marcas,
                value: v.brandId,
                required: true,
                onChanged: (id) => setState(() => v.brandId = id),
              ),
              _gap,
              _catalog(
                label: 'Categoría',
                items: c.categorias,
                value: v.categoryId,
                required: true,
                onChanged: (id) => setState(() => v.categoryId = id),
              ),
              _gap,
              _catalog(
                label: 'Unidad de medida',
                items: c.medidas,
                value: v.measureId,
                onChanged: (id) => setState(() => v.measureId = id),
              ),
              _gap,
              AppTextField(
                controller: v.cantidad,
                label: 'Cantidad por unidad',
                keyboardType: TextInputType.number,
                validator: (t) =>
                    (t == null || t.trim().isEmpty || int.tryParse(t.trim()) != null)
                        ? null
                        : 'Debe ser un número entero',
              ),
              _gap,
              _catalog(
                label: 'Proveedor',
                items: c.proveedores,
                value: v.providerId,
                required: true,
                onChanged: (id) => setState(() => v.providerId = id),
              ),
              _gap,
              _catalog(
                label: 'Canal',
                items: c.canales,
                value: v.canalId,
                required: true,
                onChanged: (id) => setState(() => v.canalId = id),
              ),
              _gap,
              _catalog(
                label: 'Giro de negocio',
                items: c.giros,
                value: v.giroId,
                required: true,
                onChanged: (id) => setState(() => v.giroId = id),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Código de barras, vender sin stock, duplicar y adicional.
class _OptionsTab extends StatefulWidget {
  final _ProductFormValues values;

  const _OptionsTab({required this.values});

  @override
  State<_OptionsTab> createState() => _OptionsTabState();
}

class _OptionsTabState extends State<_OptionsTab> {
  @override
  Widget build(BuildContext context) {
    final v = widget.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: v.codBarra,
          label: 'Código de barras (opcional)',
          textInputAction: TextInputAction.next,
        ),
        _switch(
          'Vender sin stock',
          v.ventaSinStock,
          (b) => setState(() => v.ventaSinStock = b),
        ),
        _switch('Duplicar', v.duplicar, (b) => setState(() => v.duplicar = b)),
        _gap,
        AppTextField(
          controller: v.descripcion,
          label: 'Adicional (opcional)',
          maxLines: 3,
        ),
      ],
    );
  }
}
