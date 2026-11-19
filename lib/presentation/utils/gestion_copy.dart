import 'package:flutter/material.dart';

import '../../domain/entities/gestion_entity.dart';
import 'inicio_copy.dart' show monthsShort;

/// Textos y colores del módulo Gestión: los mismos que usa la web.

String _two(int v) => v.toString().padLeft(2, '0');

/// "09 dic 2025".
String gestionFecha(DateTime d) => '${_two(d.day)} ${monthsShort[d.month - 1].toLowerCase()} ${d.year}';

/// "09/12/2025".
String gestionDia(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// "09/12".
String gestionDiaMes(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// "10:00 a. m." / "03:30 p. m.".
String gestionHora(DateTime d) => gestionHoraDe(TimeOfDay(hour: d.hour, minute: d.minute));

String gestionHoraDe(TimeOfDay t) {
  final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '${_two(hour)}:${_two(t.minute)} ${t.period == DayPeriod.am ? 'a. m.' : 'p. m.'}';
}

/// "09/12/2025 · 10:00 a. m.".
String gestionDiaHora(DateTime d) => '${gestionDia(d)} · ${gestionHora(d)}';

/// "hoy", "ayer" o "hace 5 días".
String gestionHaceCuanto(DateTime fecha, DateTime now) {
  final dias = DateTime(now.year, now.month, now.day)
      .difference(DateTime(fecha.year, fecha.month, fecha.day))
      .inDays;
  return dias <= 0
      ? 'hoy'
      : dias == 1
          ? 'ayer'
          : 'hace $dias días';
}

/// "Vencida 03/11", "Hoy 10:30" o "07/11 10:30".
String gestionTareaCuando(GestionTarea tarea, DateTime now) {
  final f = tarea.fecha;
  if (tarea.vencida) return 'Vencida ${gestionDiaMes(f)}';
  final hora = '${_two(f.hour)}:${_two(f.minute)}';
  if (f.year == now.year && f.month == now.month && f.day == now.day) return 'Hoy $hora';
  return '${gestionDiaMes(f)} $hora';
}

/// Color del punto y de la etiqueta de cada tono de resultado.
Color gestionTonoColor(GestionTono tono) => switch (tono) {
      GestionTono.positivo => const Color(0xFF16A34A),
      GestionTono.espera => const Color(0xFF2563EB),
      GestionTono.neutro => const Color(0xFF475569),
      GestionTono.objecion => const Color(0xFFEA580C),
      GestionTono.perdido => const Color(0xFFDC2626),
    };

/// Etiqueta, rango de % de caída y color de cada estado del cliente (los del reporte "Clientes con caída").
({String etiqueta, String rango, Color color, IconData icono}) gestionEstadoUi(GestionEstado estado) => switch (estado) {
      GestionEstado.critico => (
          etiqueta: 'Crítico',
          rango: '71 % o más',
          color: const Color(0xFFDC2626),
          icono: Icons.error_outline,
        ),
      GestionEstado.riesgo => (
          etiqueta: 'En riesgo',
          rango: '26 - 70 %',
          color: const Color(0xFFEA580C),
          icono: Icons.warning_amber_outlined,
        ),
      GestionEstado.seguimiento => (
          etiqueta: 'En seguimiento',
          rango: '11 - 25 %',
          color: const Color(0xFF2563EB),
          icono: Icons.visibility_outlined,
        ),
      GestionEstado.normal => (
          etiqueta: 'Normal',
          rango: '0 - 10 %',
          color: const Color(0xFF16A34A),
          icono: Icons.check_circle_outline,
        ),
      GestionEstado.sinBase => (
          etiqueta: 'Sin comparación',
          rango: 'Sin ventas el año anterior',
          color: const Color(0xFF64748B),
          icono: Icons.help_outline,
        ),
    };

/// Cada estado con su rango de % de caída y lo que significa ("¿Qué significa cada estado?").
const gestionEstadosAyuda = <({GestionEstado estado, String rango, String significado})>[
  (estado: GestionEstado.critico, rango: '71 % o más', significado: 'Caída severa o dejó de comprar.'),
  (estado: GestionEstado.riesgo, rango: '26 % - 70 %', significado: 'Disminución importante.'),
  (estado: GestionEstado.seguimiento, rango: '11 % - 25 %', significado: 'Disminución moderada.'),
  (estado: GestionEstado.normal, rango: '0 % - 10 %', significado: 'Ventas estables o en crecimiento.'),
  (estado: GestionEstado.sinBase, rango: 'Sin base', significado: 'Sin compras en el periodo anterior.'),
];

/// Días sin compra: 0-15 normal, 16-30 seguimiento, 31-60 en riesgo, 61 o más crítico.
Color gestionColorDeDias(int? dias) {
  if (dias == null) return const Color(0xFF94A3B8);
  if (dias >= 61) return const Color(0xFFDC2626);
  if (dias >= 31) return const Color(0xFFEA580C);
  if (dias >= 16) return const Color(0xFF2563EB);
  return const Color(0xFF16A34A);
}

/// Ícono y color de cada tipo de contacto, para los círculos del historial y el selector del formulario.
({IconData icon, Color color}) gestionContactoStyle(GestionContacto tipo) => switch (tipo) {
      GestionContacto.llamada => (icon: Icons.phone, color: const Color(0xFF16A34A)),
      GestionContacto.whatsapp => (icon: Icons.chat, color: const Color(0xFF22C55E)),
      GestionContacto.visita => (icon: Icons.storefront_outlined, color: const Color(0xFF7C3AED)),
      GestionContacto.correo => (icon: Icons.mail_outline, color: const Color(0xFF2563EB)),
    };

/// El color de un texto sobre su propio fondo suave: más oscuro en el tema claro y más claro en el oscuro.
Color gestionLegible(Color base, Brightness brightness) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withLightness(brightness == Brightness.dark ? 0.72 : 0.28).toColor();
}

/// El estilo de un botón de texto (un enlace): azul con contraste suficiente en el tema claro y en el oscuro (el
/// naranja de la marca no llega a 4.5:1 sobre el fondo blanco).
ButtonStyle gestionEnlace(BuildContext context) => TextButton.styleFrom(
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF93C5FD)
          : const Color(0xFF1D4ED8),
    );
