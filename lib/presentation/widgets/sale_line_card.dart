import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/format.dart';
import '../../domain/entities/sale_entity.dart';
import '../../theme/app_theme.dart';
import '../components/components.dart';
import 'product_image.dart';

/// Una línea de la venta como tarjeta: foto del producto, insignia con el código, nombre, precio
/// unitario, cantidad con − / +, el total de la línea y el basurero para quitarla.
///
/// El **descuento** y el **precio** se cambian en un panel que se abre con el botón
/// "Descuento 0 %" (o tocando el precio unitario): el descuento va en porcentaje o, con el botón
/// de cambio, en monto fijo (como la web). Un ítem libre lleva además el lápiz para editar su
/// descripción y su código.
///
/// - Con el tope de stock, el + se apaga y la tarjeta dice "Máx. stock: N".
/// - El total corre hasta su valor al cambiar la cantidad o el descuento (`AppCountUp`).
class SaleLineCard extends StatefulWidget {
  final SaleLineEntity line;

  /// Motivo por el que la línea no se puede vender (sin precio, sin stock...), o `null`.
  final String? problem;

  /// Símbolo de la moneda de la venta (`S/` o `$`).
  final String symbol;

  /// Lo máximo que se puede vender de este producto en el almacén; `null` si no hay tope
  /// (servicio, venta sin stock o ítem libre).
  final double? maxQuantity;

  /// Precio de la lista elegida, para avisar cuando el precio de la línea se cambió a mano.
  final double? listPrice;

  final ValueChanged<int> onQuantity;
  final ValueChanged<double> onPrice;
  final ValueChanged<double> onDto;
  final VoidCallback onToggleDto;
  final VoidCallback onRemove;

  /// Solo en un ítem libre: abre el formulario para cambiar su descripción y su código.
  final VoidCallback? onEditFree;

  const SaleLineCard({
    super.key,
    required this.line,
    required this.problem,
    required this.symbol,
    required this.onQuantity,
    required this.onPrice,
    required this.onDto,
    required this.onToggleDto,
    required this.onRemove,
    this.maxQuantity,
    this.listPrice,
    this.onEditFree,
  });

  @override
  State<SaleLineCard> createState() => _SaleLineCardState();
}

class _SaleLineCardState extends State<SaleLineCard> {
  late final _quantity = TextEditingController(text: '${widget.line.cantidad}');
  late final _price = TextEditingController(text: _priceText(widget.line.precio));
  late final _dto = TextEditingController(text: _dtoText(widget.line.dto));
  final _quantityFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _dtoFocus = FocusNode();

  /// El panel de precio y descuento arranca abierto si falta el precio (hay que escribirlo).
  late bool _expanded = widget.line.precio <= 0;

  static String _priceText(double v) => v == 0 ? '' : v.toStringAsFixed(2);

  static String _dtoText(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void didUpdateWidget(SaleLineCard old) {
    super.didUpdateWidget(old);
    // Lo cambió otra cosa (la lista de precios, el tope de stock): se refleja en el campo.
    if (!_quantityFocus.hasFocus && _quantity.text != '${widget.line.cantidad}') {
      _quantity.text = '${widget.line.cantidad}';
    }
    if (!_priceFocus.hasFocus && (double.tryParse(_price.text) ?? 0) != widget.line.precio) {
      _price.text = _priceText(widget.line.precio);
    }
    // El descuento se recorta (100 %, o el subtotal si es un monto): el campo muestra el valor
    // que quedó, aunque se esté escribiendo.
    final typed = double.tryParse(_dto.text) ?? 0;
    if (typed != widget.line.dto && (!_dtoFocus.hasFocus || typed > widget.line.dto)) {
      final text = _dtoText(widget.line.dto);
      _dto.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _dto.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    _dtoFocus.dispose();
    super.dispose();
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  /// ¿Ya no se puede subir la cantidad? (llegó al stock del almacén)
  bool get _atMax {
    final max = widget.maxQuantity;
    return max != null && widget.line.cantidad >= max.floor();
  }

  String _money(double v) => formatMoney(v, symbol: widget.symbol);

  /// Texto corto del descuento para el botón: `0 %`, `10 %` o `S/ 5.00`.
  String get _dtoLabel {
    final line = widget.line;
    if (!line.tieneDescuento) return 'Descuento 0 %';
    return '−${line.dtoFijo ? _money(line.dto) : '${_dtoText(line.dto)} %'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final hasProblem = widget.problem != null;

    // El ancho de la tarjeta frente a la letra del sistema: si no alcanza para el nombre y el total
    // lado a lado (ni la cantidad y el descuento en una fila), el total y el descuento bajan.
    final scale = MediaQuery.textScalerOf(context).scale(1);

    Widget card(bool compact) => Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasProblem ? scheme.error : scheme.outlineVariant),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _top(theme, scheme, dark, compact: compact),
          const SizedBox(height: 8),
          _controls(theme, scheme, compact: compact),
          _notes(theme, scheme),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded ? _panel(theme, scheme) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );

    return AppEntrance(
      offset: 10,
      duration: const Duration(milliseconds: 300),
      child: LayoutBuilder(
        // 20 = el relleno de la tarjeta; 250 = el ancho (con letra normal) que necesita el nombre
        // junto al total.
        builder: (context, c) => card((c.maxWidth - 20) / scale < 250),
      ),
    );
  }

  // ── Foto, código, nombre, precio unitario y total ───────────────────────────────────────
  /// El total de la línea (con el importe original tachado encima si hay descuento).
  Widget _total(ThemeData theme, ColorScheme scheme, bool dark, {required Alignment align}) {
    final line = widget.line;
    final color = dark ? scheme.onSurface : AppTheme.brandDark;
    final end = align == Alignment.centerRight;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (line.tieneDescuento)
            Text(
              _money(line.subtotal),
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          AppCountUp(
            value: line.subtotalConDto,
            duration: const Duration(milliseconds: 450),
            format: _money,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// [compact]: en pantallas angostas o con letra muy grande el total baja debajo del precio
  /// unitario (si no, el nombre se quedaría con muy poco ancho).
  Widget _top(ThemeData theme, ColorScheme scheme, bool dark, {required bool compact}) {
    final line = widget.line;
    final badgeText = line.esLibre
        ? [if (line.codigoLibre != null) line.codigoLibre!, 'Ítem libre'].join(' · ')
        : line.product.codigo;
    final edited = widget.listPrice != null && widget.listPrice! > 0 && widget.listPrice != line.precio;
    final marca = line.esLibre ? null : line.product.marca;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_photo(scheme) case final photo?) ...[
          photo,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, c) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La insignia no pasa del 60 % del ancho: el resto es del total.
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth * (compact ? 0.85 : 0.6)),
                      child: _CodeBadge(text: badgeText, free: line.esLibre),
                    ),
                    if (widget.onEditFree != null)
                      SizedBox(
                        width: 32,
                        height: 24,
                        child: IconButton(
                          tooltip: 'Editar descripción y código',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.onEditFree,
                          icon: Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    if (compact)
                      const Spacer()
                    else
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _total(theme, scheme, dark, align: Alignment.centerRight),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                line.product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'P. Unit.: ${_money(line.precio)}'),
                        if (edited)
                          TextSpan(
                            text: '  (lista ${_money(widget.listPrice!)})',
                            style: const TextStyle(fontWeight: FontWeight.w400),
                          ),
                        if (marca != null)
                          TextSpan(
                            text: '  ·  $marca',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: edited ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: edited ? FontWeight.w700 : FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 2),
                _total(theme, scheme, dark, align: Alignment.centerLeft),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// La foto del producto. Sin foto no se dibuja nada (antes era un recuadro gris con un ícono
  /// que le quitaba ancho al nombre y al total).
  Widget? _photo(ColorScheme scheme) {
    const size = 56.0;
    final line = widget.line;
    final path = line.product.imagen;
    if (path == null || line.esLibre) return null;
    return ProductImage(path: path, size: size, radius: 14, fit: BoxFit.cover);
  }

  // ── Cantidad, descuento y basurero ──────────────────────────────────────────────────────
  Widget _controls(ThemeData theme, ColorScheme scheme, {required bool compact}) {
    final line = widget.line;
    final canMinus = line.cantidad > 1;
    final canPlus = !_atMax;

    final chip = _DiscountChip(
      label: _dtoLabel,
      active: line.tieneDescuento,
      expanded: _expanded,
      onTap: _toggleExpanded,
    );

    final row = Row(
      children: [
        _RoundButton(
          tooltip: 'Menos',
          icon: Icons.remove,
          onPressed: canMinus ? () => widget.onQuantity(line.cantidad - 1) : null,
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _quantity,
            focusNode: _quantityFocus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
            onChanged: (text) {
              final n = int.tryParse(text);
              if (n != null && n >= 1) widget.onQuantity(n);
            },
          ),
        ),
        _RoundButton(
          tooltip: 'Más',
          icon: Icons.add,
          filled: true,
          onPressed: canPlus ? () => widget.onQuantity(line.cantidad + 1) : null,
        ),
        const SizedBox(width: 4),
        // Con ancho de sobra el descuento va al lado de la cantidad; si no, debajo.
        if (compact) const Spacer() else Expanded(child: Align(alignment: Alignment.center, child: chip)),
        _RoundButton(
          tooltip: 'Quitar',
          icon: Icons.delete_outline,
          neutral: true,
          onPressed: widget.onRemove,
        ),
      ],
    );

    if (!compact) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Align(alignment: Alignment.centerLeft, child: chip),
      ],
    );
  }

  /// El tope de stock y el motivo por el que la línea no se puede vender.
  Widget _notes(ThemeData theme, ColorScheme scheme) {
    final max = widget.maxQuantity;
    final showMax = _atMax && widget.problem == null && max != null && max >= 1;

    Widget note(IconData icon, String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color))),
        ],
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.problem != null)
            note(Icons.warning_amber_rounded, widget.problem!, scheme.error)
          else if (showMax)
            note(Icons.inventory_outlined, 'Máx. stock: ${formatQuantity(max)}', scheme.onSurfaceVariant),
        ],
      ),
    );
  }

  // ── Panel: precio y descuento ───────────────────────────────────────────────────────────
  Widget _panel(ThemeData theme, ColorScheme scheme) {
    final line = widget.line;

    final priceField = TextField(
      controller: _price,
      focusNode: _priceFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(labelText: 'Precio ${widget.symbol}', hintText: '0'),
      onChanged: (text) => widget.onPrice(double.tryParse(text) ?? 0),
    );

    // Descuento: un porcentaje o, cambiando el tipo, un monto (como la web).
    final dtoField = TextField(
      controller: _dto,
      focusNode: _dtoFocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: InputDecoration(
        labelText: line.dtoFijo ? 'Descuento ${widget.symbol}' : 'Descuento %',
        hintText: '0',
        prefixIcon: IconButton(
          tooltip: line.dtoFijo ? 'Descontar en porcentaje (%)' : 'Descontar un monto fijo',
          onPressed: widget.onToggleDto,
          icon: const Icon(Icons.swap_horiz, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 44),
        suffixText: line.dtoFijo ? null : '%',
      ),
      onChanged: (text) => widget.onDto(double.tryParse(text) ?? 0),
    );

    final saved = line.tieneDescuento
        ? Text(
            'Desc. −${_money(line.montoDto)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 300;
            final fields = narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [priceField, const SizedBox(height: 10), dtoField],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: priceField),
                      const SizedBox(width: 10),
                      Expanded(child: dtoField),
                    ],
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fields,
                if (saved != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: saved),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Insignia con el código del producto (verde suave, como la referencia); un ítem libre va en
/// naranja suave.
class _CodeBadge extends StatelessWidget {
  final String text;
  final bool free;

  const _CodeBadge({required this.text, required this.free});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = free
        ? (dark ? const Color(0xFF431407) : const Color(0xFFFFEDD5), dark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412))
        : (dark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5), dark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text.isEmpty ? '—' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Botón circular de 48 px de área táctil: − (contorno), + (relleno naranja) o basurero (gris).
/// Responde con una vibración corta y se hunde al tocarlo.
class _RoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool neutral;

  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final Color background = filled
        ? AppTheme.primaryButton
        : neutral
            ? scheme.surfaceContainerHigh
            : Colors.transparent;
    final Color foreground = filled ? Colors.white : scheme.onSurface;

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: AppPressScale(
          enabled: enabled,
          scale: 0.88,
          child: InkResponse(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onPressed!();
                  }
                : null,
            radius: 26,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: enabled ? 1 : 0.35,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: background,
                      border: filled || neutral ? null : Border.all(color: scheme.outline, width: 1.5),
                    ),
                    child: Icon(icon, size: 20, color: neutral ? scheme.onSurfaceVariant : foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Descuento 0 %": abre o cierra el panel de precio y descuento; con descuento puesto se pinta
/// de color y muestra cuánto es.
class _DiscountChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _DiscountChip({
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = active ? (dark ? scheme.primary : AppTheme.primaryButton) : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      expanded: expanded,
      label: 'Precio y descuento',
      child: AppPressScale(
        scale: 0.95,
        child: Material(
          color: active ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHigh,
          shape: StadiumBorder(
            side: BorderSide(color: active ? scheme.primary : Colors.transparent),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sell_outlined, size: 16, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, size: 18, color: fg),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
