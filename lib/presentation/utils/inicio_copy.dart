import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/inicio_entity.dart';
import '../providers/inicio_provider.dart';

/// Textos y colores del Inicio, los mismos que define la web para cada rol.

const monthsShort = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

const monthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "KEDER ALONSO RUIZ" → "Keder".
String firstName(String full) {
  final first = full.trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return '';
  return first[0].toUpperCase() + first.substring(1).toLowerCase();
}

/// Saludo según la hora: de 00:00 a 11:59 "Buenos días", de 12:00 a 18:59 "Buenas tardes" y desde
/// las 19:00 "Buenas noches". El texto de abajo cambia según el rol.
({String icon, String title, String text}) greetingFor(InicioView view, String name, int hour) {
  final part = hour < 12 ? 0 : (hour < 19 ? 1 : 2);
  final titles = ['¡Buenos días, $name!', '¡Buenas tardes, $name!', '¡Buenas noches, $name!'];
  const icons = ['☀️', '🌤️', '🌙'];
  final texts = switch (view) {
    InicioView.jefe => const [
      'Hoy tenemos nuevas oportunidades para impulsar las ventas del equipo.',
      'Sigue impulsando a tu equipo para alcanzar los objetivos.',
      'Revisa los resultados del equipo y prepara las próximas oportunidades.',
    ],
    InicioView.ceo => const [
      'Un nuevo día para tomar grandes decisiones.',
      'Sigamos impulsando el crecimiento de nuestra empresa.',
      'Cada decisión de hoy construye el futuro de nuestra empresa.',
    ],
    _ => const [
      'Comienza el día con nuevas oportunidades de venta.',
      'Sigue aprovechando cada oportunidad para alcanzar tu meta.',
      'Revisa tus avances y prepárate para seguir creciendo.',
    ],
  };
  return (icon: icons[part], title: titles[part], text: texts[part]);
}

/// Un tramo del mensaje motivador: hasta qué avance de la meta (exclusivo) y su mensaje.
typedef GoalTier = ({double? hasta, String rango, String icon, String title, String text});

const _executiveTiers = <GoalTier>[
  (hasta: 25, rango: '0% - 24%', icon: '🚀', title: '¡Vamos, {nombre}!', text: 'Cada venta te acerca a tu meta.'),
  (hasta: 50, rango: '25% - 49%', icon: '💪', title: '¡Buen comienzo, {nombre}!', text: 'Sigue sumando ventas.'),
  (hasta: 80, rango: '50% - 79%', icon: '🔥', title: '¡Vas muy bien, {nombre}!', text: 'Ya superaste la mitad del camino.'),
  (hasta: 100, rango: '80% - 99%', icon: '🎯', title: '¡Ya casi lo logras, {nombre}!', text: 'Vamos por ese 100%.'),
  (hasta: 120, rango: '100% - 119%', icon: '🏆', title: '¡Meta cumplida, {nombre}!', text: 'Excelente trabajo, vamos por más.'),
  (hasta: null, rango: '120% o más', icon: '⭐', title: '¡Imparable, {nombre}!', text: 'Superaste tu meta. ¡Felicitaciones!'),
];

const _teamTiers = <GoalTier>[
  (hasta: 25, rango: '0% - 24%', icon: '🚀', title: '¡Vamos, {nombre}!', text: 'Cada venta de tu equipo cuenta para alcanzar la meta.'),
  (hasta: 50, rango: '25% - 49%', icon: '💪', title: '¡Buen comienzo, {nombre}!', text: 'Sigue impulsando a tu equipo hacia el objetivo.'),
  (hasta: 80, rango: '50% - 79%', icon: '🔥', title: '¡Buen avance, {nombre}!', text: 'Tu equipo superó la mitad de la meta. ¡Sigamos creciendo!'),
  (hasta: 100, rango: '80% - 99%', icon: '🎯', title: '¡Ya casi lo logran, {nombre}!', text: 'Tu equipo está muy cerca del 100%.'),
  (hasta: 120, rango: '100% - 119%', icon: '🏆', title: '¡Meta cumplida, {nombre}!', text: 'Gran trabajo en equipo. ¡Vamos por más!'),
  (hasta: null, rango: '120% o más', icon: '🌟', title: '¡Excelente liderazgo, {nombre}!', text: 'Tu equipo superó la meta. ¡Felicitaciones!'),
];

const _ceoTiers = <GoalTier>[
  (hasta: 25, rango: '0% - 24%', icon: '🚀', title: '¡Vamos, {nombre}!', text: 'Los grandes resultados comienzan con cada decisión.'),
  (hasta: 50, rango: '25% - 49%', icon: '💪', title: '¡Seguimos avanzando, {nombre}!', text: 'Cada esfuerzo nos acerca al objetivo.'),
  (hasta: 80, rango: '50% - 79%', icon: '📈', title: '¡Buen progreso, {nombre}!', text: 'Mantengamos el enfoque en los resultados.'),
  (hasta: 100, rango: '80% - 99%', icon: '🎯', title: '¡Estamos muy cerca, {nombre}!', text: 'Es momento de dar el último impulso.'),
  (hasta: 120, rango: '100% - 119%', icon: '🏆', title: '¡Objetivo alcanzado, {nombre}!', text: 'El compromiso del equipo da resultados.'),
  (hasta: null, rango: '120% o más', icon: '🌟', title: '¡Extraordinario, {nombre}!', text: 'Seguimos superando nuestros propios límites.'),
];

/// Los tramos del mensaje motivador de cada rol (los textos los definió el cliente, en 6 tramos).
List<GoalTier> goalTiers(InicioView view) => switch (view) {
  InicioView.jefe => _teamTiers,
  InicioView.ceo => _ceoTiers,
  _ => _executiveTiers,
};

/// Posición del tramo que le toca a un [avance] (en %).
int goalTierIndex(List<GoalTier> tiers, double avance) =>
    tiers.indexWhere((t) => t.hasta == null || avance < t.hasta!);

/// El mensaje motivador según cuánto lleva de la meta del mes, con el nombre ya puesto.
({String icon, String title, String text}) goalMessage(InicioView view, double avance, String name) {
  final tiers = goalTiers(view);
  final tier = tiers[goalTierIndex(tiers, avance)];
  return (icon: tier.icon, title: tier.title.replaceAll('{nombre}', name), text: tier.text);
}

/// Colores del semáforo de la meta.
Color goalColor(GoalLight light) => switch (light) {
  GoalLight.rojo => const Color(0xFFEF4444),
  GoalLight.ambar => const Color(0xFFF59E0B),
  GoalLight.verde => const Color(0xFF22C55E),
  GoalLight.gris => const Color(0xFFCBD5E1),
};

/// Estado de un cliente o producto en caída: etiqueta y colores.
({String label, Color color}) fallState(String estado) => switch (estado) {
  'critico' => (label: 'Crítico', color: const Color(0xFFDC2626)),
  'riesgo' => (label: 'En riesgo', color: const Color(0xFFD97706)),
  'seguimiento' => (label: 'En seguimiento', color: const Color(0xFF2563EB)),
  _ => (label: 'Normal', color: const Color(0xFF16A34A)),
};

/// Prioridad de una cotización pendiente (por días desde su emisión).
({String label, Color color}) priorityStyle(QuotePriority priority) => switch (priority) {
  QuotePriority.alta => (label: 'Alta', color: const Color(0xFFDC2626)),
  QuotePriority.media => (label: 'Media', color: const Color(0xFFD97706)),
  QuotePriority.baja => (label: 'Baja', color: const Color(0xFF16A34A)),
};

/// Ícono, color y nombres de cada tipo de gestión (llamada, WhatsApp, visita, correo).
({IconData icon, Color color, String short, String plural}) contactType(String tipo) => switch (tipo) {
  'llamada' => (icon: Icons.phone, color: const Color(0xFF22C55E), short: 'Llamar', plural: 'Llamadas'),
  'whatsapp' => (icon: Icons.chat, color: const Color(0xFF16A34A), short: 'WhatsApp', plural: 'WhatsApp'),
  'visita' => (icon: Icons.place, color: const Color(0xFFA855F7), short: 'Visita', plural: 'Visitas'),
  'correo' => (icon: Icons.email, color: const Color(0xFF3B82F6), short: 'Correo', plural: 'Correos'),
  _ => (icon: Icons.circle, color: const Color(0xFF94A3B8), short: tipo, plural: tipo),
};

/// Orden de las gestiones en el resumen del equipo: llamadas, visitas, WhatsApp y correos.
const managementOrder = ['llamada', 'visita', 'whatsapp', 'correo'];

/// El último momento del periodo: hoy, el domingo de esta semana o el último día del mes.
DateTime periodEnd(TaskPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final end = switch (period) {
    TaskPeriod.hoy => today,
    TaskPeriod.semana => today.add(Duration(days: (7 - now.weekday) % 7)),
    TaskPeriod.mes => DateTime(now.year, now.month + 1, 0),
  };
  return DateTime(end.year, end.month, end.day, 23, 59, 59);
}

String _two(int v) => v.toString().padLeft(2, '0');

/// "Vencida 03/11", "Hoy 10:30" o "07/11 10:30".
String taskWhen(TaskEntity task, DateTime now) {
  final f = task.fecha;
  if (task.vencida) return 'Vencida ${_two(f.day)}/${_two(f.month)}';
  final hour = '${_two(f.hour)}:${_two(f.minute)}';
  if (f.year == now.year && f.month == now.month && f.day == now.day) return 'Hoy $hour';
  return '${_two(f.day)}/${_two(f.month)} $hour';
}

/// "Octubre 2026" si el rango cae en un solo mes; si no, "01/09/2026 - 15/10/2026".
String rangeLabel(DateTime desde, DateTime hasta) {
  if (desde.year == hasta.year && desde.month == hasta.month) {
    final month = monthsLong[desde.month - 1];
    return '${month[0].toUpperCase()}${month.substring(1)} ${desde.year}';
  }
  return '${_two(desde.day)}/${_two(desde.month)}/${desde.year} - ${_two(hasta.day)}/${_two(hasta.month)}/${hasta.year}';
}

/// "01/09 – 15/09" (los rangos de comparación).
String shortRange(DateTime desde, DateTime hasta) =>
    '${_two(desde.day)}/${_two(desde.month)} - ${_two(hasta.day)}/${_two(hasta.month)}';

String _grouped(double v, int decimals) => NumberFormat(decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0', 'en_US').format(v);

/// `S/ 1,234` (o con [decimals] decimales).
String soles(double v, [int decimals = 0]) => 'S/ ${_grouped(v, decimals)}';

/// `\$ 1,234` (o con [decimals] decimales).
String dolares(double v, [int decimals = 0]) => '\$ ${_grouped(v, decimals)}';

/// Miles sin símbolo ni decimales: `1,234`.
String thousands(double v) => _grouped(v, 0);
