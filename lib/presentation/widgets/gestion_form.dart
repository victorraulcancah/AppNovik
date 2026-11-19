import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/gestion_entity.dart';
import '../components/components.dart';
import '../providers/gestion_provider.dart';
import '../utils/gestion_copy.dart';
import '../utils/success_snack.dart';
import 'gestion_widgets.dart';

/// Lo que se va llenando al registrar o editar una gestión: tipo de contacto, resultado, comentario y, si se
/// programa, el siguiente contacto (su tipo, fecha, hora y acción).
class GestionFormDraft extends ChangeNotifier {
  /// La hora del siguiente contacto si no se elige otra.
  static const horaPorDefecto = TimeOfDay(hour: 10, minute: 0);

  GestionFormDraft({
    this.tipo = GestionContacto.llamada,
    this.resultado,
    String comentario = '',
    this.programar = false,
    GestionContacto? proximoTipo,
    this.fecha,
    this.hora = horaPorDefecto,
    String accion = '',
    this.cumplida = false,
  })  : _proximoTipo = proximoTipo,
        comentario = TextEditingController(text: comentario),
        accion = TextEditingController(text: accion) {
    _actualizar();
  }

  GestionContacto tipo;
  String? resultado;
  final TextEditingController comentario;
  bool programar;
  GestionContacto? _proximoTipo;
  DateTime? fecha;
  TimeOfDay hora;
  final TextEditingController accion;

  /// El siguiente contacto de la gestión que se edita ya se cumplió: es historia y solo se retoca su acción.
  final bool cumplida;

  /// Se puede guardar: hay resultado y, si se programa un siguiente contacto, su fecha.
  final ValueNotifier<bool> canSave = ValueNotifier<bool>(false);

  /// El siguiente contacto sigue el tipo de la gestión hasta que se elige otro.
  GestionContacto get proximoTipo => _proximoTipo ?? tipo;

  bool get listo => resultado != null && (cumplida || !programar || fecha != null);

  /// Fecha y hora del siguiente contacto, o `null` si no se programa.
  DateTime? get proximo {
    final f = fecha;
    if (!programar || f == null) return null;
    return DateTime(f.year, f.month, f.day, hora.hour, hora.minute);
  }

  void _actualizar() => canSave.value = listo;

  /// Cambia algo del formulario y avisa a quien lo dibuja.
  void change(VoidCallback fn) {
    fn();
    _actualizar();
    notifyListeners();
  }

  void elegirProximoTipo(GestionContacto value) => change(() => _proximoTipo = value);

  /// Deja el formulario como nuevo (tras guardar una gestión).
  void reset() => change(() {
        tipo = GestionContacto.llamada;
        resultado = null;
        comentario.clear();
        programar = false;
        _proximoTipo = null;
        fecha = null;
        hora = horaPorDefecto;
        accion.clear();
      });

  GestionNueva toNueva() => GestionNueva(
        tipo: tipo,
        resultado: resultado!,
        comentario: comentario.text,
        proximo: proximo,
        proximoTipo: proximoTipo,
        proximaAccion: accion.text,
      );

  GestionEdicion toEdicion() => GestionEdicion(
        tipo: tipo,
        resultado: resultado!,
        comentario: comentario.text,
        cumplida: cumplida,
        // Un siguiente contacto cumplido es historia: solo se retoca su acción.
        proximo: cumplida ? null : proximo,
        proximoTipo: cumplida ? null : proximoTipo,
        proximaAccion: accion.text,
      );

  @override
  void dispose() {
    comentario.dispose();
    accion.dispose();
    canSave.dispose();
    super.dispose();
  }
}

/// Elige la fecha del siguiente contacto: desde hoy (una fecha que ya estaba, aunque venciera, se respeta).
Future<DateTime?> pickGestionFecha(BuildContext context, {DateTime? actual}) {
  final ahora = context.read<GestionProvider>().now();
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = actual == null ? null : DateTime(actual.year, actual.month, actual.day);
  return showDatePicker(
    context: context,
    initialDate: dia ?? hoy,
    firstDate: dia != null && dia.isBefore(hoy) ? dia : hoy,
    lastDate: DateTime(hoy.year + 5, 12, 31),
    helpText: 'Fecha del próximo seguimiento',
    selectableDayPredicate: (d) => !d.isBefore(hoy) || d == dia,
  );
}

Future<TimeOfDay?> pickGestionHora(BuildContext context, TimeOfDay actual) =>
    showTimePicker(context: context, initialTime: actual, helpText: 'Hora del próximo seguimiento');

/// Los 4 tipos de contacto (llamada, WhatsApp, visita y correo) como botones.
class GestionTipoSelector extends StatelessWidget {
  final GestionContacto value;
  final ValueChanged<GestionContacto> onChanged;

  const GestionTipoSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        for (final tipo in GestionContacto.values) ...[
          if (tipo != GestionContacto.values.first) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: tipo == value,
              label: tipo.etiqueta,
              child: Material(
                color: tipo == value ? scheme.primaryContainer : scheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: tipo == value ? scheme.primary : scheme.outlineVariant,
                    width: tipo == value ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(tipo),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(gestionContactoStyle(tipo).icon, size: 22, color: gestionContactoStyle(tipo).color),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              tipo.corto,
                              maxLines: 1,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: tipo == value ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Un título pequeño sobre un campo del formulario.
class _Etiqueta extends StatelessWidget {
  final String text;

  const _Etiqueta(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Elegir uno de los resultados: cada uno con su punto de color y cuándo elegirlo. Devuelve la clave, o
/// `null` si se cerró sin elegir.
Future<String?> showGestionResultadoPicker(BuildContext context, GestionCatalogo catalogo, String? actual) async {
  String? elegido;
  await showAppModal(
    context,
    title: 'Resultado',
    subtitle: 'Cómo terminó el contacto',
    icon: Icons.flag_outlined,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: Builder(
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final scheme = theme.colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in catalogo.resultados)
              Semantics(
                button: true,
                selected: r.clave == actual,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    elegido = r.clave;
                    Navigator.of(modalContext).pop(true);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: r.clave == actual ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: _Punto(color: gestionTonoColor(r.tono)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.etiqueta, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                              Text(
                                r.cuando,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (r.clave == actual) Icon(Icons.check, color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  return elegido;
}

class _Punto extends StatelessWidget {
  final Color color;

  const _Punto({required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// "Resultados de una gestión: cuándo elegir cada uno".
Future<void> showGestionGuia(BuildContext context, GestionCatalogo? catalogo) {
  return showAppModal(
    context,
    title: 'Resultados de una gestión',
    subtitle: '¿Cuándo seleccionarlo?',
    icon: Icons.help_outline,
    primaryLabel: null,
    secondaryLabel: 'Cerrar',
    child: Builder(
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final resultados = catalogo?.resultados ?? const <GestionResultado>[];
        if (resultados.isEmpty) return const Text('Los resultados todavía no se cargaron.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in resultados)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestionPill.resultado(r.tono, r.etiqueta),
                    const SizedBox(height: 4),
                    Text(r.cuando, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// El campo de resultado del formulario (obligatorio): se elige de una lista y debajo se lee cuándo elegirlo.
class GestionResultadoField extends StatelessWidget {
  final GestionFormDraft draft;

  const GestionResultadoField({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final catalogo = gestion.catalogo;
    final elegido = catalogo?.resultado(draft.resultado);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: gestionEnlace(context).merge(
              TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            onPressed: () => showGestionGuia(context, catalogo),
            child: const Text('¿Cuándo elegir cada uno?'),
          ),
        ),
        if (catalogo == null && gestion.catalogoError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'No se pudieron cargar los resultados. ${gestion.catalogoError}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
              TextButton(
                style: gestionEnlace(context),
                onPressed: gestion.loadCatalogo,
                child: const Text('Reintentar'),
              ),
            ],
          )
        else
          AppPickerField(
            label: 'Resultado',
            value: elegido?.etiqueta ?? (catalogo == null ? 'Cargando…' : 'Selecciona el resultado'),
            icon: Icons.arrow_drop_down,
            onTap: catalogo == null
                ? null
                : () async {
                    final clave = await showGestionResultadoPicker(context, catalogo, draft.resultado);
                    if (clave != null) draft.change(() => draft.resultado = clave);
                  },
          ),
        if (elegido != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _Punto(color: gestionTonoColor(elegido.tono)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    elegido.cuando,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// El siguiente contacto de una gestión: un interruptor permite programar cuándo y cómo (llamada, WhatsApp,
/// visita o correo) se vuelve a contactar al cliente. Va en azul para distinguirlo de la gestión.
class GestionProximoPanel extends StatelessWidget {
  final GestionFormDraft draft;

  /// Algo que el usuario debe saber antes de guardar (por ejemplo, que reemplaza otro contacto programado).
  final String? aviso;

  const GestionProximoPanel({super.key, required this.draft, this.aviso});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    const azul = Color(0xFF2563EB);

    // Un Material (no un Container con color) para que el interruptor dibuje su fondo y su efecto al tocarlo.
    return Material(
      color: azul.withValues(alpha: dark ? 0.14 : 0.07),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: azul.withValues(alpha: dark ? 0.45 : 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: draft.programar,
            onChanged: (on) => draft.change(() => draft.programar = on),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            secondary: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0x262563EB),
              child: Icon(Icons.event_outlined, size: 18, color: azul),
            ),
            title: Text(
              '¿Deseas programar un próximo seguimiento?',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Aquí defines qué tipo de contacto harás y cuándo.'),
          ),
          if (draft.programar)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Etiqueta('Tipo de próximo contacto'),
                  GestionTipoSelector(value: draft.proximoTipo, onChanged: draft.elegirProximoTipo),
                  const SizedBox(height: 12),
                  AppPickerField(
                    label: 'Fecha del próximo seguimiento',
                    value: draft.fecha == null ? 'Elige la fecha' : gestionDia(draft.fecha!),
                    icon: Icons.calendar_today_outlined,
                    onTap: () async {
                      final dia = await pickGestionFecha(context, actual: draft.fecha);
                      if (dia != null) draft.change(() => draft.fecha = dia);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppPickerField(
                    label: 'Hora (opcional)',
                    value: gestionHoraDe(draft.hora),
                    icon: Icons.schedule,
                    onTap: () async {
                      final hora = await pickGestionHora(context, draft.hora);
                      if (hora != null) draft.change(() => draft.hora = hora);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: draft.accion,
                    maxLength: 150,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: '¿Qué harás en ese contacto? (opcional)',
                      hintText: 'Ej.: Enviar cotización',
                    ),
                  ),
                  if (aviso != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: dark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(aviso!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Los campos de una gestión: tipo de contacto, resultado, comentario (hasta 500 letras) y el siguiente contacto.
/// Los usan el formulario "Registrar nueva gestión" y la ventana "Editar la gestión".
class GestionFormFields extends StatelessWidget {
  final GestionFormDraft draft;

  /// Con una gestión editada cuyo siguiente contacto ya se cumplió: se ve lo que se prometió, solo la acción se
  /// puede retocar.
  final GestionRegistro? cumplida;

  /// Aviso bajo el panel del siguiente contacto.
  final String? aviso;

  const GestionFormFields({super.key, required this.draft, this.cumplida, this.aviso});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hecha = cumplida;

    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Etiqueta('Tipo de contacto'),
          GestionTipoSelector(value: draft.tipo, onChanged: (t) => draft.change(() => draft.tipo = t)),
          const SizedBox(height: 16),
          GestionResultadoField(draft: draft),
          const SizedBox(height: 16),
          TextField(
            controller: draft.comentario,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText: 'Escribe un breve comentario...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          if (hecha != null && hecha.proximoSeguimiento != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Siguiente contacto (ya cumplido)',
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      gestionDiaHora(hecha.proximoSeguimiento!),
                      if (hecha.proximoTipoEtiqueta != null) hecha.proximoTipoEtiqueta!,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: draft.accion,
                    maxLength: 150,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: '¿Qué se iba a hacer?',
                      hintText: 'Ej.: Enviar cotización',
                    ),
                  ),
                ],
              ),
            )
          else
            GestionProximoPanel(draft: draft, aviso: aviso),
        ],
      ),
    );
  }
}

/// "Editar la gestión": los mismos campos del registro. Si el siguiente contacto ya se cumplió queda en solo
/// lectura (salvo la acción); si no, se puede programar uno nuevo, cambiarlo o quitarlo. Devuelve `true` si se
/// guardó.
Future<bool?> showGestionEditar(BuildContext context, GestionRegistro g) async {
  final gestion = context.read<GestionProvider>();
  // Los resultados por si todavía no se habían pedido.
  unawaited(gestion.loadCatalogo());
  final cumplida = g.seguimientoEstado == GestionSeguimiento.cumplido;
  final programado = g.proximoSeguimiento;
  final draft = GestionFormDraft(
    tipo: g.tipo,
    resultado: g.resultado,
    comentario: g.comentario ?? '',
    programar: programado != null,
    proximoTipo: g.proximoTipo ?? g.tipo,
    fecha: programado == null ? null : DateTime(programado.year, programado.month, programado.day),
    hora: programado == null
        ? GestionFormDraft.horaPorDefecto
        : TimeOfDay(hour: programado.hour, minute: programado.minute),
    accion: g.proximaAccion ?? '',
    cumplida: cumplida,
  );
  final error = ValueNotifier<String?>(null);
  // El cliente tiene un solo contacto programado: programar este reemplaza al de otra gestión.
  final otra = gestion.historial.proxima;

  final guardada = await showAppModal(
    context,
    title: 'Editar la gestión',
    subtitle: gestionDiaHora(g.fecha),
    icon: Icons.edit_outlined,
    primaryLabel: 'Guardar cambios',
    primaryEnabled: draft.canSave,
    error: error,
    // El cuerpo cambia al programar o quitar el siguiente contacto: la ventana mide siempre lo mismo.
    fixedHeight: true,
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: ListenableBuilder(
        listenable: draft,
        builder: (context, _) => GestionFormFields(
          draft: draft,
          cumplida: cumplida ? g : null,
          aviso: draft.programar && otra?.proximoSeguimiento != null && otra!.id != g.id
              ? 'El cliente ya tiene un contacto programado para el ${gestionDia(otra.proximoSeguimiento!)}; al guardar, ese pasa a cumplido y queda este.'
              : null,
        ),
      ),
    ),
    onPrimary: () async {
      error.value = null;
      final result = await gestion.editar(g.id, draft.toEdicion());
      if (result.isLeft) {
        // La ventana sigue abierta con el mensaje del servidor y lo escrito.
        error.value = result.left.message;
        throw StateError(result.left.message);
      }
    },
  );
  if (guardada == true && context.mounted) showSuccessSnack(context, 'Gestión actualizada');
  return guardada;
}

/// "Reprogramar el siguiente contacto": nueva fecha (no pasada) y hora. Devuelve `true` si se guardó.
Future<bool?> showGestionReprogramar(BuildContext context, GestionRegistro g) async {
  final gestion = context.read<GestionProvider>();
  final actual = g.proximoSeguimiento;
  final hoy = gestion.now();
  final vigente = actual != null && !DateTime(actual.year, actual.month, actual.day).isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  final draft = GestionFormDraft(
    resultado: g.resultado,
    programar: true,
    fecha: vigente ? DateTime(actual.year, actual.month, actual.day) : null,
    hora: actual == null ? GestionFormDraft.horaPorDefecto : TimeOfDay(hour: actual.hour, minute: actual.minute),
  );
  final error = ValueNotifier<String?>(null);

  final guardada = await showAppModal(
    context,
    title: 'Reprogramar el siguiente contacto',
    subtitle: [
      if (g.proximoTipo != null) g.proximoTipo!.corto,
      if (g.proximaAccion != null) g.proximaAccion!,
    ].join(' · '),
    icon: Icons.event_repeat_outlined,
    primaryLabel: 'Guardar',
    primaryEnabled: draft.canSave,
    error: error,
    child: AppDisposer(
      onDispose: [draft.dispose, error.dispose],
      child: ListenableBuilder(
        listenable: draft,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPickerField(
              label: 'Nueva fecha',
              value: draft.fecha == null ? 'Elige la nueva fecha' : gestionDia(draft.fecha!),
              icon: Icons.calendar_today_outlined,
              onTap: () async {
                final dia = await pickGestionFecha(context, actual: draft.fecha);
                if (dia != null) draft.change(() => draft.fecha = dia);
              },
            ),
            const SizedBox(height: 12),
            AppPickerField(
              label: 'Hora',
              value: gestionHoraDe(draft.hora),
              icon: Icons.schedule,
              onTap: () async {
                final hora = await pickGestionHora(context, draft.hora);
                if (hora != null) draft.change(() => draft.hora = hora);
              },
            ),
          ],
        ),
      ),
    ),
    onPrimary: () async {
      error.value = null;
      final result = await gestion.reprogramar(g.id, draft.proximo!);
      if (result.isLeft) {
        error.value = result.left.message;
        throw StateError(result.left.message);
      }
    },
  );
  if (guardada == true && context.mounted) showSuccessSnack(context, 'Seguimiento reprogramado');
  return guardada;
}
