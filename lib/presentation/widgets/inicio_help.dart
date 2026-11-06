import 'package:flutter/material.dart';
import '../../domain/entities/inicio_entity.dart';
import '../../theme/app_theme.dart';
import '../utils/inicio_copy.dart';

/// El texto de una ayuda (?) del Inicio: un título, una línea que explica y, si la hay, una tabla
/// de conceptos. Cada celda es un `String` o un `Widget` (una etiqueta de color, por ejemplo).
/// Son los mismos textos de los íconos (?) del Dashboard de la web; se quitan solo las filas que
/// hablan de enlaces a pantallas que la app no tiene (el ↗ que abre otro reporte, abrir la ficha
/// del cliente o Gestión).
class InicioHelp {
  final String title;
  final String? intro;
  final List<String> columns;
  final List<List<Object>> rows;

  const InicioHelp({required this.title, this.intro, this.columns = const [], this.rows = const []});

  /// Una ayuda de un solo párrafo (en la web, un tooltip de texto).
  const InicioHelp.text(this.title, String text) : intro = text, columns = const [], rows = const [];
}

/// Botón (?) para el borde del título de una sección: abre su ayuda en una hoja inferior.
class InicioHelpButton extends StatelessWidget {
  final InicioHelp help;

  const InicioHelpButton({super.key, required this.help});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: () => showInicioHelp(context, help),
      icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// Muestra la ayuda en una hoja inferior (como la de los mensajes de la meta).
Future<void> showInicioHelp(BuildContext context, InicioHelp help) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
      final threeColumns = help.columns.length >= 3;

      Widget cell(Object value, {required bool first}) => value is Widget
          ? Align(alignment: Alignment.centerLeft, child: value)
          : Text(
              value as String,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: first ? FontWeight.w700 : null),
            );

      Widget row(List<Object> cells, {bool header = false}) {
        final children = <Widget>[];
        for (var i = 0; i < cells.length; i++) {
          final last = i == cells.length - 1;
          final child = header
              ? Text(cells[i] as String, style: muted?.copyWith(fontWeight: FontWeight.w600))
              : cell(cells[i], first: i == 0);
          if (last) {
            children.add(Expanded(child: child));
          } else {
            children.add(SizedBox(width: i == 0 ? (threeColumns ? 88 : 112) : 76, child: child));
            children.add(const SizedBox(width: 8));
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(help.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (help.intro != null) ...[
                const SizedBox(height: 6),
                Text(help.intro!, style: muted),
              ],
              if (help.rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                if (help.columns.isNotEmpty) row(help.columns, header: true),
                for (final r in help.rows) ...[Divider(height: 1, color: scheme.outlineVariant), row(r)],
              ],
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------------------------
// Etiquetas pequeñas para las filas de las tablas de ayuda.

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color Function(BuildContext) color;

  const _Swatch(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color(context), borderRadius: BorderRadius.circular(3)),
  );
}

Widget _fallTag(String estado) {
  final s = fallState(estado);
  return _Tag(s.label, s.color);
}

/// Los estados por % de caída (Clientes con caída y Productos sin ventas), contra el mismo tramo
/// del año pasado.
List<List<Object>> _fallStateRows() => [
  [_fallTag('critico'), 'Cayó 71 % o más'],
  [_fallTag('riesgo'), 'Cayó entre 26 % y 70 %'],
  [_fallTag('seguimiento'), 'Cayó entre 11 % y 25 %'],
];

// ---------------------------------------------------------------------------------------------
// Ayudas comunes a varios resúmenes.

/// "Cotizaciones pendientes": qué cuenta y la prioridad según los días desde la emisión.
InicioHelp inicioPriorityHelp() => InicioHelp(
  title: 'Prioridad según los días desde la emisión',
  intro: 'Tus cotizaciones del rango que siguen sin procesar (ninguna venta nació de ellas).',
  columns: const ['Días', 'Prioridad', 'Qué significa'],
  rows: [
    ['0 - 3 días', _Tag('Baja', priorityStyle(QuotePriority.baja).color), 'Recién emitida: todavía hay tiempo.'],
    ['4 - 7 días', _Tag('Media', priorityStyle(QuotePriority.media).color), 'Conviene darle seguimiento.'],
    ['8 días o más', _Tag('Alta', priorityStyle(QuotePriority.alta).color), 'Urge cerrarla antes de que se enfríe.'],
  ],
);

InicioHelp inicioFallClientsHelp(String intro) => InicioHelp(
  title: 'Clientes con mayor caída',
  intro: intro,
  columns: const ['Estado', 'Caída'],
  rows: _fallStateRows(),
);

/// Ejecutivo: tus clientes. Jefe: los del equipo. CEO: todos.
InicioHelp inicioFallClientsHelpExecutive() => inicioFallClientsHelp(
  'Tus clientes que más cayeron contra el mismo rango del año pasado (reporte Clientes con caída).',
);

InicioHelp inicioFallClientsHelpTeam() => const InicioHelp.text(
  'Clientes con mayor caída',
  'Los clientes del equipo que más cayeron contra el mismo rango del año pasado (reporte Clientes con caída). La variación es en soles; el color, su estado.',
);

InicioHelp inicioFallClientsHelpCeo() => inicioFallClientsHelp(
  'Los clientes que más cayeron contra el mismo rango del año pasado (reporte Clientes con caída).',
);

InicioHelp inicioFallProductsHelpTeam() => const InicioHelp(
  title: 'Productos con mayor caída',
  intro:
      'Los productos que más dejaron de venderse: el rango elegido contra el mismo rango del año pasado (reporte Productos sin ventas).',
  columns: ['Columna', 'Qué es'],
  rows: [
    ['Año pasado / Este año', 'Lo vendido del producto en cada periodo, en soles.'],
    ['Variación', 'La diferencia en soles y en %.'],
  ],
);

InicioHelp inicioFallProductsHelpCeo() => const InicioHelp.text(
  'Productos con mayor caída',
  'Los productos que más dejaron de venderse: el rango contra el mismo rango del año pasado (reporte Productos sin ventas).',
);

// ---------------------------------------------------------------------------------------------
// Ejecutivo.

InicioHelp inicioExecutiveSalesHelp() => const InicioHelp(
  title: 'Ventas y meta',
  intro:
      'Tus ventas del rango elegido: en soles, sin anuladas ni deudas anteriores, las que se te atribuyen (igual que Tracking y Metas Comerciales).',
  columns: ['Concepto', 'Qué es'],
  rows: [
    ['Ventas', 'El total vendido en el rango.'],
    ['+/- %', 'Contra el mismo rango del año pasado; abajo se ve la cifra de entonces.'],
    ['Meta', 'Tu meta del mes en Metas Comerciales. Es mensual: solo se ve si el rango cae en un mismo mes.'],
    ['% de avance', 'Lo vendido en el mes contra la meta. Rojo debajo del 50 %, ámbar del 50 % al 99 %, verde desde el 100 %.'],
    ['Faltan', 'Lo que falta vender para llegar a la meta.'],
    ['Mensaje', 'Cambia según el avance (ver el ? del mensaje).'],
    ['N.º de ventas', 'Cuántas ventas hiciste en el rango.'],
    ['Ticket promedio', 'Ventas ÷ N.º de ventas.'],
  ],
);

InicioHelp inicioExecutiveEvolutionHelp() => InicioHelp(
  title: 'Evolución de mis ventas',
  intro: 'Lo que vendiste cada mes del año, contra el año anterior.',
  columns: const ['Barra', 'Qué es'],
  rows: [
    [_Swatch((c) => Theme.of(c).colorScheme.outlineVariant), 'Venta del mes el año anterior.'],
    [_Swatch((c) => AppTheme.strongFill(Theme.of(c).brightness)), 'Venta del mes este año.'],
  ],
);

InicioHelp inicioTopHelp(String title, String who) => InicioHelp(
  title: title,
  intro: 'Tus 5 $who con más venta en el rango elegido.',
  columns: const ['Concepto', 'Qué es'],
  rows: const [
    ['Monto', 'Lo vendido, en soles.'],
    ['Barra', 'Proporcional al primero de la lista.'],
  ],
);

InicioHelp inicioExecutiveOpportunitiesHelp() => InicioHelp(
  title: 'Oportunidades comerciales',
  intro: 'Lo que conviene trabajar en el rango elegido.',
  columns: const ['Mosaico', 'Qué cuenta'],
  rows: [
    ['Clientes con caída', 'Clientes de tu cartera en Crítico, En riesgo o En seguimiento (reporte Clientes con caída).'],
    ['Cotizaciones pendientes', 'Tus cotizaciones sin procesar y su monto (Documentos → Cotizaciones, Pendientes).'],
    ['Productos sin ventas', 'Productos en Crítico, En riesgo o En seguimiento (reporte Productos sin ventas).'],
    ..._fallStateRows(),
  ],
);

InicioHelp inicioTasksHelp() => const InicioHelp(
  title: 'Mis tareas',
  intro:
      'Las gestiones que programaste en Gestión y que siguen sin hacerse. No dependen del rango de fechas: Hoy, Semana (hasta el domingo) o Mes (hasta fin de mes), siempre con las vencidas.',
  columns: ['Concepto', 'Qué es'],
  rows: [
    ['Hoy HH:mm', 'Gestión programada para hoy, a esa hora.'],
    ['DD/MM HH:mm', 'Gestión programada para otro día de la semana o del mes.'],
    ['Vencida', 'Programada para un día anterior y todavía sin hacer.'],
    ['Hoy / Semana / Mes', 'Hasta cuándo se ven las tareas.'],
    ['Filtros', 'Por tipo de contacto: llamada, visita, WhatsApp o correo.'],
  ],
);

InicioHelp inicioBirthdaysHelp() => InicioHelp(
  title: 'Cumpleaños',
  intro: 'Clientes de tu cartera que cumplen años en el rango elegido (hasta el final del mes en que termina).',
  columns: const ['Día', 'Qué indica'],
  rows: [
    [const _Tag('27', Color(0xFFEC4899)), 'Cumple hoy.'],
    [const _Tag('29', Color(0xFFDB2777)), 'Cumple en los próximos días.'],
    [const _Tag('19', Color(0xFF94A3B8)), 'Ya pasó.'],
  ],
);

// ---------------------------------------------------------------------------------------------
// Jefe.

InicioHelp inicioTeamSalesHelp() => const InicioHelp(
  title: 'Ventas del equipo y meta',
  intro:
      'Todas las ventas de la empresa en el rango: en soles, sin anuladas ni deudas anteriores (el mismo total de Tracking).',
  columns: ['Concepto', 'Qué es'],
  rows: [
    ['Ventas del equipo', 'El total vendido en el rango.'],
    ['+/- %', 'Contra el mismo rango del año pasado; abajo se ve la cifra de entonces.'],
    [
      'Meta',
      'La meta de la empresa del mes (Metas Comerciales). Es mensual: solo se ve si el rango cae en un mismo mes.',
    ],
    ['% de avance', 'Lo vendido en el mes contra la meta. Rojo debajo del 50 %, ámbar del 50 % al 99 %, verde desde el 100 %.'],
    ['N.º de ventas / Ticket', 'Cuántas ventas hubo y el promedio por venta.'],
  ],
);

InicioHelp inicioSellerGoalsHelp() => const InicioHelp(
  title: 'Cumplimiento de metas por vendedor',
  intro:
      'Lo que se le atribuye a cada vendedor en el rango (como en Tracking) contra su meta del mes en Metas Comerciales.',
  columns: ['Columna', 'Qué es'],
  rows: [
    ['Ventas', 'Lo vendido por el vendedor en el rango.'],
    ['Meta', 'Su meta del mes. Con un rango de varios meses no aplica (—).'],
    ['Avance', 'Ventas ÷ meta. Verde desde el 100 %, ámbar del 50 % al 99 %, rojo debajo del 50 %.'],
  ],
);

InicioHelp inicioTeamTopProductsHelp() => const InicioHelp.text(
  'Productos más vendidos del equipo',
  'Los 5 productos con más venta del equipo en el rango. La barra, contra el que más vendió; el porcentaje, de la venta total del equipo.',
);

InicioHelp inicioTeamDepartmentsHelp() => const InicioHelp.text(
  'Venta por departamento',
  'La venta del equipo según el departamento del cliente y su participación en el total del rango.',
);

InicioHelp inicioTeamOpportunitiesHelp() => InicioHelp(
  title: 'Oportunidades comerciales del equipo',
  intro: 'Lo que conviene trabajar en el rango elegido, de todo el equipo.',
  columns: const ['Mosaico', 'Qué cuenta'],
  rows: [
    ['Clientes con caída', 'Clientes en Crítico, En riesgo o En seguimiento (reporte Clientes con caída).'],
    ['Cotizaciones pendientes', 'Cotizaciones del rango sin procesar y su monto.'],
    ['Productos sin ventas', 'Productos en Crítico, En riesgo o En seguimiento (reporte Productos sin ventas).'],
    ..._fallStateRows(),
  ],
);

InicioHelp inicioManagementsHelp() => const InicioHelp(
  title: 'Gestiones del equipo',
  intro:
      'Las gestiones que el equipo programó en Gestión para hoy, esta semana (lunes a domingo) o este mes, por tipo de contacto. No dependen del rango de fechas.',
  columns: ['Concepto', 'Qué es'],
  rows: [
    ['24 / 30', 'Hechas / programadas en el periodo. Una gestión cuenta como hecha cuando se registra la siguiente de ese cliente.'],
    [_Tag('80%', Color(0xFF16A34A)), 'Desde 80 % hechas.'],
    [_Tag('67%', Color(0xFFD97706)), 'Entre 50 % y 79 %.'],
    [_Tag('38%', Color(0xFFDC2626)), 'Debajo del 50 %.'],
  ],
);

// ---------------------------------------------------------------------------------------------
// CEO.

InicioHelp inicioIndicatorsHelp() => const InicioHelp(
  title: 'Indicadores estratégicos (YTD)',
  intro: 'Lo que va del año: del 1 de enero al final del rango elegido, contra el mismo tramo del año anterior.',
  columns: ['Indicador', 'Qué es'],
  rows: [
    ['Ventas acumuladas', 'Lo vendido en el año, en soles, sin anuladas ni deudas anteriores.'],
    ['Utilidad estimada', 'Venta de los productos menos su costo, en el año (oculta: toca el ojo para verla).'],
    ['Cotizaciones pendientes', 'Cotizaciones del año que siguen sin procesar y su monto.'],
    ['Clientes activos', 'Cantidad de clientes que compraron en el mes, contra el mismo mes del año anterior.'],
  ],
);

InicioHelp inicioCeoSellerGoalsHelp() => const InicioHelp.text(
  'Cumplimiento por vendedor',
  'Lo vendido por cada vendedor en el rango (como en Tracking) contra su meta del mes en Metas Comerciales.',
);

InicioHelp inicioCeoDepartmentsHelp() => const InicioHelp.text(
  'Ventas por departamento',
  'La venta del rango según el departamento del cliente.',
);

InicioHelp inicioChannelsHelp() => const InicioHelp.text(
  'Ventas por canal',
  'Los clientes activos de cada categoría (no cambian con el almacén) y lo vendido a ellos en el rango, en soles.',
);

InicioHelp inicioReceivablesHelp() => const InicioHelp(
  title: 'Cuentas por cobrar',
  intro: 'El saldo de hoy de toda la empresa, con el mismo cálculo del módulo Deudas. No depende del rango de fechas.',
  columns: ['Concepto', 'Qué es'],
  rows: [
    ['Total por cobrar', 'Lo que deben los clientes (los dólares, al tipo de cambio de su venta).'],
    ['Vencido', 'El saldo de las cuotas cuya fecha de vencimiento ya pasó.'],
    ['Por vencer', 'El resto del total.'],
  ],
);

InicioHelp inicioCollectionsHelp() => const InicioHelp.text(
  'Cobro por vendedor',
  'Los depósitos de clientes que registró cada vendedor en Pagos de Vendedores en el rango (aprobados y pendientes de aprobar), en soles y en dólares como en esa pantalla. No cambia con el almacén.',
);

InicioHelp inicioIncomesHelp() => const InicioHelp(
  title: 'Ingresos por entidad bancaria',
  intro:
      'El dinero que entró en el rango, por cada método de pago: en soles o en dólares, cada moneda con su participación sobre el total de esa moneda. Cada moneda se compara con esa misma moneda en los mismos días del mes anterior. Con el filtro se eligen los métodos.',
  columns: ['Se suma', 'Qué es'],
  rows: [
    [
      'Depósitos de clientes',
      'Los registrados por los vendedores en Pagos de Vendedores (aprobados y pendientes de aprobar), por su método de pago. Es lo mismo que suma Cobro por vendedor.',
    ],
    ['Almacén', 'Los depósitos no tienen almacén: la tarjeta no cambia con el almacén elegido.'],
  ],
);

InicioHelp inicioNewClientsHelp() => const InicioHelp.text(
  'Nuevos clientes',
  'Clientes que hicieron su primera compra en el rango, contra el mismo rango del año pasado.',
);
