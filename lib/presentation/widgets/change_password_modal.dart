import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/account_repository.dart';
import '../../domain/usecases/account_usecases.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';

/// "Cambiar contraseña" del menú de la cuenta, como en la web: pide la contraseña actual, la nueva
/// (con sus requisitos y el nivel de seguridad) y su confirmación. Cada usuario cambia solo la suya.
Future<void> showChangePasswordModal(BuildContext context) async {
  final useCase = context.read<ChangePasswordUseCase>();
  final auth = context.read<AuthProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final formKey = GlobalKey<FormState>();
  final actual = TextEditingController();
  final nueva = TextEditingController();
  final confirmacion = TextEditingController();
  final error = ValueNotifier<String?>(null);
  // Lo que respondió el servidor (o la validación) por campo; se borra al volver a escribir ese campo.
  final fieldErrors = <String, String>{};

  // Al volver a escribir un campo, su aviso anterior ya no vale (si no, impediría enviar de nuevo).
  actual.addListener(() => fieldErrors.remove('actual'));
  nueva.addListener(() => fieldErrors.remove('nueva'));
  confirmacion.addListener(() => fieldErrors.remove('nueva_confirmation'));

  var saved = false;
  await showAppModal(
    context,
    title: 'Cambiar contraseña',
    subtitle: 'Ingresa la información solicitada.',
    icon: Icons.key_outlined,
    primaryLabel: 'Cambiar contraseña',
    formKey: formKey,
    error: error,
    onPrimary: () async {
      error.value = null;
      fieldErrors.clear();
      final result = await useCase(actual: actual.text, nueva: nueva.text, confirmacion: confirmacion.text);
      if (result.isRight) {
        saved = true;
        return;
      }
      final failure = result.left;
      if (failure is PasswordFieldFailure && failure.field.isNotEmpty) {
        // El motivo sale debajo del campo que no se aceptó.
        fieldErrors[failure.field] = failure.message;
        formKey.currentState?.validate();
      } else {
        error.value = failure.message;
      }
      throw StateError(failure.message);
    },
    child: AppDisposer(
      onDispose: [actual.dispose, nueva.dispose, confirmacion.dispose, error.dispose],
      child: _ChangePasswordForm(
        actual: actual,
        nueva: nueva,
        confirmacion: confirmacion,
        fieldErrors: fieldErrors,
      ),
    ),
  );

  if (!saved) return;
  // Si el celular recuerda la contraseña, que recuerde la nueva.
  auth.updateRememberedPassword(nueva.text);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Contraseña actualizada')));
}

class _ChangePasswordForm extends StatelessWidget {
  final TextEditingController actual;
  final TextEditingController nueva;
  final TextEditingController confirmacion;
  final Map<String, String> fieldErrors;

  const _ChangePasswordForm({
    required this.actual,
    required this.nueva,
    required this.confirmacion,
    required this.fieldErrors,
  });

  /// Primero lo que dijo el servidor para el campo; si no, lo que falta.
  String? _check(String field, String? Function() local) => fieldErrors[field] ?? local();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPasswordField(
          controller: actual,
          label: 'Contraseña actual *',
          textInputAction: TextInputAction.next,
          validator: (v) => _check('actual', () => (v ?? '').isEmpty ? 'Ingresa tu contraseña actual' : null),
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          controller: nueva,
          label: 'Nueva contraseña *',
          textInputAction: TextInputAction.next,
          validator: (v) => _check('nueva', () {
            final value = v ?? '';
            if (value.isEmpty) return 'Ingresa tu nueva contraseña';
            if (!passwordMeetsMandatory(value)) {
              return 'Debe tener 8 caracteres, una mayúscula, una minúscula y un número';
            }
            return null;
          }),
        ),
        const SizedBox(height: 10),
        // Los requisitos se marcan solos al escribir, y el nivel de seguridad sube con ellos.
        ListenableBuilder(
          listenable: nueva,
          builder: (context, _) {
            final strength = passwordStrength(nueva.text);
            final color = switch (strength.level) {
              'Débil' => Colors.red,
              'Media' => Colors.orange,
              'Fuerte' => Colors.green,
              _ => scheme.outlineVariant,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          for (var i = 0; i < 6; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i < strength.points ? color : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Nivel de seguridad: ${strength.level}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu nueva contraseña debe tener:',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final r in passwordRequirements)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: r.met(nueva.text) ? Colors.green : scheme.outlineVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r.text, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          controller: confirmacion,
          label: 'Confirmar nueva contraseña *',
          textInputAction: TextInputAction.done,
          validator: (v) => _check('nueva_confirmation', () {
            final value = v ?? '';
            if (value.isEmpty) return 'Vuelve a ingresar tu nueva contraseña';
            if (value != nueva.text) return 'Las contraseñas no coinciden';
            return null;
          }),
        ),
      ],
    );
  }
}
