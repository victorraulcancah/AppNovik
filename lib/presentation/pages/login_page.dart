import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../theme/app_theme.dart';
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
    return isTablet ? _buildTablet() : _buildPhone();
  }

  /// Celular: cabecera oscura con la marca y el formulario debajo.
  Widget _buildPhone() {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(topPadding: MediaQuery.paddingOf(context).top),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: _form(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet: fondo oscuro con la tarjeta de login centrada.
  Widget _buildTablet() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _darkGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(nameColor: Colors.white),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _form(),
                    ),
                  ],
                ),
              ),
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
            Text(
              'Iniciar sesión',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: loading ? null : () => setState(() => _remember = !_remember),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: loading
                          ? null
                          : (v) => setState(() => _remember = v ?? false),
                    ),
                    const Expanded(child: Text('Recordar mis credenciales')),
                  ],
                ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(message: auth.errorMessage!),
            ],
            const SizedBox(height: 20),
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

const _darkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTheme.brandDark, AppTheme.brandDarkAlt],
);

class _Header extends StatelessWidget {
  final double topPadding;

  const _Header({required this.topPadding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPadding + 56, bottom: 48),
      decoration: const BoxDecoration(
        gradient: _darkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: const Center(child: AppLogo(nameColor: Colors.white)),
    );
  }
}
