import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../components/components.dart';
import '../providers/sales_provider.dart';

/// Formulario "Ítem libre": una línea de la venta que no es un producto del catálogo (un
/// servicio, un cargo...), con su descripción, un código opcional, la cantidad y el precio. Solo
/// lo ve quien tiene el permiso `factura.libre`, como en la web.
///
/// Devuelve el aviso a mostrar si el código escrito ya era un producto del catálogo (la línea pasó a
/// ser ese producto), o `null`. Quien lo llama puede distinguir "se cerró" de "se agregó" mirando
/// el provider.
Future<String?> showFreeItemForm(BuildContext context) async {
  final sales = context.read<SalesProvider>();
  final formKey = GlobalKey<FormState>();
  final code = TextEditingController();
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final error = ValueNotifier<String?>(null);
  String? info;

  await showAppModal(
    context,
    title: 'Agregar ítem libre',
    subtitle: 'Una línea que no es un producto del catálogo',
    icon: Icons.edit_note_outlined,
    primaryLabel: 'Agregar',
    formKey: formKey,
    error: error,
    child: AppDisposer(
      onDispose: [code.dispose, description.dispose, quantity.dispose, price.dispose, error.dispose],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: description,
            label: 'Descripción del concepto',
            maxLines: 2,
            keyboardType: TextInputType.multiline,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe la descripción' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: code,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Código (opcional)',
              helperText: 'Si ya existe en el catálogo, se agrega como producto normal',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Mínimo 1' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  decoration: InputDecoration(labelText: 'Precio ${sales.moneySymbol}'),
                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Escribe el precio' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    onPrimary: () async {
      error.value = null;
      final result = await sales.addFreeItem(
        descripcion: description.text,
        codigo: code.text,
        cantidad: int.tryParse(quantity.text) ?? 1,
        precio: double.tryParse(price.text) ?? 0,
      );
      if (result.problem != null) {
        // El modal sigue abierto con el motivo.
        error.value = result.problem;
        throw StateError(result.problem!);
      }
      info = result.info;
    },
  );

  return info;
}
