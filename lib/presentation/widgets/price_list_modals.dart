import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/import_entity.dart';
import '../../domain/entities/price_list_entity.dart';
import '../components/components.dart';

/// Formulario de Lista de precios: crear o, si se pasa [list], editar. Los mismos campos que la
/// web: nombre, moneda (solo al crear: después no se cambia) y estado. [onSubmit] guarda y devuelve
/// `null` si salió bien o el motivo del rechazo, que se muestra dentro del modal (que sigue abierto
/// para corregir). Devuelve `true` si se guardó.
Future<bool> showPriceListForm(
  BuildContext context, {
  PriceListEntity? list,
  required Future<String?> Function(PriceListFormEntity form) onSubmit,
}) async {
  final editing = list != null;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: list?.name ?? '');
  final currency = ValueNotifier<String?>(list?.currency);
  final active = ValueNotifier<bool>(list?.active ?? true);
  final error = ValueNotifier<String?>(null);
  var saved = false;

  await showAppModal(
    context,
    title: editing ? 'Editar lista de precios' : 'Crear lista de precios',
    subtitle: editing
        ? list.name
        : 'Agrupa los precios de tus productos por moneda',
    icon: Icons.sell_outlined,
    primaryLabel: editing ? 'Editar' : 'Crear',
    formKey: formKey,
    error: error,
    onPrimary: () async {
      error.value = null;
      final problem = await onSubmit(
        PriceListFormEntity(
          name: name.text.trim(),
          currency: currency.value ?? list?.currency ?? 's',
          active: active.value,
        ),
      );
      if (problem != null) {
        // El modal sigue abierto con el motivo (por ejemplo, "La lista ya existe").
        error.value = problem;
        throw StateError(problem);
      }
      saved = true;
    },
    child: AppDisposer(
      onDispose: [
        name.dispose,
        currency.dispose,
        active.dispose,
        error.dispose,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            key: const ValueKey('lista-nombre'),
            controller: name,
            label: 'Nombre de la lista',
            prefixIcon: Icons.sell_outlined,
            textInputAction: TextInputAction.done,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Escribe el nombre de la lista'
                : null,
          ),
          if (!editing) ...[
            const SizedBox(height: 16),
            AppDropdownField<String>(
              key: const ValueKey('lista-moneda'),
              label: 'Tipo de moneda',
              value: currency.value,
              items: const [
                DropdownMenuItem(value: 's', child: Text('Soles')),
                DropdownMenuItem(value: 'd', child: Text('Dólares')),
              ],
              onChanged: (v) => currency.value = v,
              validator: (v) => v == null ? 'Elige la moneda' : null,
            ),
          ],
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, value, _) => SwitchListTile(
              key: const ValueKey('lista-estado'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Estado'),
              subtitle: Text(value ? 'Activo' : 'Inactivo'),
              value: value,
              onChanged: (v) => active.value = v,
            ),
          ),
        ],
      ),
    ),
  );

  return saved;
}

/// "2.5" o "2,5" como número; vacío es 0 (como la web, que guarda 0 si se borra el precio).
double? parsePrice(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  return double.tryParse(t);
}

/// Cambiar el precio de un producto en la lista. La web lo edita en la misma fila de la tabla; en
/// el celular se abre este modal con el campo del precio. [onSubmit] guarda y devuelve `null` si
/// salió bien o el motivo del rechazo, que se muestra dentro del modal. Devuelve `true` si se
/// guardó.
Future<bool> showPriceEditor(
  BuildContext context, {
  required PriceListEntity list,
  required PriceListProductEntity product,
  required Future<String?> Function(double precio) onSubmit,
}) async {
  final controller = TextEditingController(
    text: product.precio == null ? '' : _plain(product.precio!),
  );
  final error = ValueNotifier<String?>(null);
  var saved = false;

  await showAppModal(
    context,
    title: 'Precio del producto',
    subtitle: list.name,
    icon: Icons.attach_money,
    primaryLabel: 'Guardar',
    error: error,
    onPrimary: () async {
      final precio = parsePrice(controller.text);
      if (precio == null) {
        error.value = 'Escribe un precio válido';
        throw StateError('Precio inválido');
      }
      error.value = null;
      final problem = await onSubmit(precio);
      if (problem != null) {
        error.value = problem;
        throw StateError(problem);
      }
      saved = true;
    },
    child: AppDisposer(
      onDispose: [controller.dispose, error.dispose],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDetailRow(
            label: 'Código',
            value: product.codigo.isEmpty ? '—' : product.codigo,
          ),
          AppDetailRow(label: 'Descripción', value: product.name),
          if (product.marca != null)
            AppDetailRow(label: 'Marca', value: product.marca),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('precio-nuevo'),
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Precio (${list.currencyLabel})',
              hintText: '0.00',
              prefixText: '${list.symbol} ',
            ),
          ),
        ],
      ),
    ),
  );

  return saved;
}

/// El precio sin ceros de más para el campo: `12.5`, `10`.
String _plain(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// Las filas del Excel que el servidor no pudo importar y por qué, después de subir los precios
/// (se subieron todas las demás).
Future<void> showPriceListImportFailures(
  BuildContext context, {
  required List<ImportFailureEntity> failures,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  return showAppModal(
    context,
    title: 'Filas con errores',
    subtitle: 'Se subieron los precios excepto estas filas',
    icon: Icons.error_outline,
    tone: AppModalTone.warning,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
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
                failure.row > 0 ? 'Error en fila ${failure.row}' : 'Error',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (final e in failure.errors)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: scheme.error)),
                      Expanded(child: Text(e)),
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

/// El precio de una fila: `S/. 12.50`, o "Sin precio" si todavía no tiene.
String priceLabel(PriceListEntity list, double? precio) =>
    precio == null ? 'Sin precio' : formatMoney(precio, symbol: list.symbol);
