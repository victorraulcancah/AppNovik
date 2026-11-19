import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/gestion_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/gestion_provider.dart';
import '../providers/shell_navigation.dart';
import '../utils/gestion_copy.dart';
import '../widgets/gestion_compras_tab.dart';
import '../widgets/gestion_documentos_tab.dart';
import '../widgets/gestion_ficha_view.dart';
import '../widgets/gestion_seguimiento_tab.dart';
import '../widgets/gestion_tareas_view.dart';

/// Módulo Gestión (seguimiento de clientes): sin cliente elegido, las tareas pendientes; con uno, su ficha
/// (resumen, seguimiento, compras y documentos). Se busca un cliente por nombre, documento o código. Permisos: `clientes.seguimiento`
/// para ver y `clientes.seguimiento.registrar` para registrar, editar y reprogramar gestiones.
class GestionPage extends StatefulWidget {
  const GestionPage({super.key});

  @override
  State<GestionPage> createState() => _GestionPageState();
}

class _GestionPageState extends State<GestionPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  String _text = '';
  bool _searching = false;
  String? _searchError;
  List<GestionClienteBuscado> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Al entrar: abre el cliente que pidió el Inicio (una tarea) o refresca lo que ya se veía.
  void _start() {
    final gestion = context.read<GestionProvider>();
    if (!gestion.canView) return;
    final pedido = context.read<ShellNavigation>().takePendingGestionCliente();
    if (pedido != null) {
      // Desde una tarea: el cliente se abre directo en Seguimiento, para registrar la gestión (o en la pestaña pedida).
      unawaited(gestion.openClient(pedido.clienteId, pedido.nombre, tab: pedido.pestana.index));
    } else if (gestion.hasClient) {
      unawaited(gestion.refreshClient());
    }
    unawaited(gestion.tareasLoaded ? gestion.loadTareas(silent: true) : gestion.ensureTareas());
    // Los resultados: los usan el formulario y los filtros del historial.
    unawaited(gestion.loadCatalogo());
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    _request++;
    setState(() {
      _text = query;
      _searchError = null;
      _results = [];
      _searching = false;
    });
    if (query.length < GestionProvider.minSearch) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final result = await context.read<GestionProvider>().buscarClientes(query);
    if (!mounted || request != _request) return;
    setState(() {
      _searching = false;
      result.fold(
        (failure) {
          _results = [];
          _searchError = failure.message;
        },
        (list) => _results = list,
      );
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _request++;
    _searchController.clear();
    setState(() {
      _text = '';
      _results = [];
      _searching = false;
      _searchError = null;
    });
  }

  void _pick(GestionClienteBuscado cliente) {
    FocusManager.instance.primaryFocus?.unfocus();
    _clearSearch();
    // Al elegir otro cliente se queda en la misma pestaña: útil para atender varios seguimientos seguidos.
    unawaited(context.read<GestionProvider>().openClient(cliente.id, cliente.nombre));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthProvider>().session;
    final gestion = context.watch<GestionProvider>();

    const header = AppPageHeader(
      icon: Icons.handshake_outlined,
      title: 'Gestión',
      subtitle: 'Seguimiento de clientes',
      trailing: AppAccountMenu(),
    );

    if (session != null && !session.can('clientes.seguimiento')) {
      return const Column(
        children: [
          header,
          Expanded(
            child: AppEmptyState(
              icon: Icons.lock_outline,
              title: 'Sin acceso',
              message: 'No tienes permiso para ver la gestión de clientes.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        header,
        AppSearchBar(
          hint: 'Buscar cliente por nombre, documento o código',
          controller: _searchController,
          onChanged: _onSearchChanged,
          voice: false,
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _text.isNotEmpty
                  ? _searchResults(context)
                  : gestion.hasClient
                      ? _GestionFicha(onBack: gestion.closeClient)
                      : GestionTareasView(
                          onOpen: (t) => unawaited(gestion.openClient(t.clienteId, t.cliente, tab: 1)),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  /// Lo que devolvió la búsqueda de clientes.
  Widget _searchResults(BuildContext context) {
    if (_text.length < GestionProvider.minSearch) {
      return const AppEmptyState(
        icon: Icons.search,
        title: 'Sigue escribiendo',
        message: 'Escribe al menos 2 letras para buscar.',
      );
    }
    if (_searchError != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo buscar',
        message: _searchError,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: () => _search(_text)),
      );
    }
    if (_searching || (_results.isEmpty && _debounce?.isActive == true)) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: AppSkeletonResults());
    }
    if (_results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off,
        title: 'Sin resultados',
        message: 'Ningún cliente coincide con lo que escribiste.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = _results[i];
        final scheme = Theme.of(context).colorScheme;
        return AppListCard(
          title: c.nombre,
          lines: [
            [?c.documento, ?c.codigo, ?c.ciudad].join(' · '),
          ].where((l) => l.isNotEmpty).toList(),
          trailingCaption: c.activo ? null : 'Inactivo',
          trailingCaptionColor: scheme.error,
          onTap: () => _pick(c),
        );
      },
    );
  }
}

/// La ficha del cliente abierto: cabecera y las pestañas Resumen y Seguimiento.
class _GestionFicha extends StatelessWidget {
  final VoidCallback onBack;

  const _GestionFicha({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final gestion = context.watch<GestionProvider>();
    final ficha = gestion.ficha;

    if (ficha == null) {
      final error = gestion.fichaError;
      if (error == null) return const AppSkeletonList(count: 3);
      // Un cliente ajeno a la cartera (o que no existe) no se puede mostrar: se lee el motivo del servidor.
      if (!gestion.fichaErrorDeRed) {
        return AppEmptyState(
          icon: Icons.person_off_outlined,
          title: 'No se puede mostrar este cliente',
          message: error,
          action: AppButton(label: 'Volver a las tareas', icon: Icons.arrow_back, onPressed: onBack),
        );
      }
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudo cargar la ficha',
        message: error,
        action: AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: gestion.retryClient),
      );
    }

    return RefreshIndicator(
      onRefresh: gestion.refreshClient,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: gestionEnlace(context),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Tareas pendientes'),
            ),
          ),
          GestionFichaHeader(ficha: ficha),
          const SizedBox(height: 12),
          AppTabBar(
            controller: gestion.tabs,
            tabs: const [
              AppTabItem(label: 'Resumen', icon: Icons.dashboard_outlined, child: SizedBox.shrink()),
              AppTabItem(label: 'Seguimiento', icon: Icons.timeline, child: SizedBox.shrink()),
              AppTabItem(label: 'Compras', icon: Icons.shopping_cart_outlined, child: SizedBox.shrink()),
              AppTabItem(label: 'Documentos', icon: Icons.description_outlined, child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 16),
          // Al cambiar de cliente cada pestaña vuelve a empezar; al cambiar de pestaña conserva lo escrito.
          KeyedSubtree(
            key: ValueKey(ficha.cliente.id),
            child: ListenableBuilder(
              listenable: gestion.tabs,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Visibility(
                    visible: gestion.tabs.index == 0,
                    maintainState: true,
                    child: GestionResumenTab(
                      ficha: ficha,
                      canRegister: gestion.canRegister,
                      onRegistrarPrimera: () => gestion.tabs.select(1),
                    ),
                  ),
                  Visibility(
                    visible: gestion.tabs.index == 1,
                    maintainState: true,
                    child: const GestionSeguimientoTab(),
                  ),
                  // Compras y Documentos piden sus datos al abrirse por primera vez; lo que traen queda en el provider.
                  if (gestion.tabs.index == GestionPestana.compras.index) const GestionComprasTab(),
                  if (gestion.tabs.index == GestionPestana.documentos.index) const GestionDocumentosTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
