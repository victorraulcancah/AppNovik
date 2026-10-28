import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final auth = context.read<AuthProvider>();
    await auth.loadSavedCredentials();
    final saved = auth.savedCredentials;
    if (!mounted || saved == null) return;
    setState(() {
      _usuarioController.text = saved.usuario;
      _passwordController.text = saved.password;
      _remember = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<AuthProvider>().login(
          _usuarioController.text,
          _passwordController.text,
          remember: _remember,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppLogo()),
        const SizedBox(height: 32),
        _form(),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: isTablet
                  ? Card(
                      elevation: 0,
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: content,
                      ),
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final auth = context.watch<AuthProvider>();
    final loading = auth.status == AuthStatus.loading;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Iniciar sesión', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ingresa con tu usuario y contraseña',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _usuarioController,
              label: 'Usuario',
              prefixIcon: Icons.person_outline,
              enabled: !loading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (v) => Validators.validateRequired(v, 'El usuario'),
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              controller: _passwordController,
              enabled: !loading,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.validateRequired(v, 'La contraseña'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _remember,
              onChanged: loading
                  ? null
                  : (v) => setState(() => _remember = v ?? false),
              title: const Text('Recordar mis credenciales'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: auth.errorMessage!),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Ingresar',
              icon: Icons.login,
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
