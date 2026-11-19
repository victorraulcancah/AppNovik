import 'dart:async';
import 'dart:convert';

import 'package:app_novik/core/constants/api_constants.dart';
import 'package:app_novik/core/errors/exceptions.dart';
import 'package:app_novik/core/errors/failures.dart';
import 'package:app_novik/core/utils/either.dart';
import 'package:app_novik/data/datasources/gestion_remote_datasource.dart';
import 'package:app_novik/data/datasources/theme_local_datasource.dart';
import 'package:app_novik/data/models/gestion_model.dart';
import 'package:app_novik/domain/entities/company_entity.dart';
import 'package:app_novik/domain/entities/document_entity.dart';
import 'package:app_novik/domain/entities/gestion_entity.dart';
import 'package:app_novik/domain/entities/inicio_entity.dart' show TaskEntity, TaskPeriod;
import 'package:app_novik/domain/entities/saved_credentials_entity.dart';
import 'package:app_novik/domain/entities/session_context_entity.dart';
import 'package:app_novik/domain/entities/user_entity.dart';
import 'package:app_novik/domain/repositories/auth_repository.dart';
import 'package:app_novik/domain/repositories/gestion_repository.dart';
import 'package:app_novik/domain/usecases/auth_usecases.dart';
import 'package:app_novik/domain/usecases/gestion_usecases.dart';
import 'package:app_novik/data/models/inicio_model.dart' show executiveSummaryFromJson;
import 'package:app_novik/presentation/pages/gestion_page.dart';
import 'package:app_novik/presentation/providers/auth_provider.dart';
import 'package:app_novik/presentation/providers/gestion_provider.dart';
import 'package:app_novik/presentation/providers/shell_navigation.dart';
import 'package:app_novik/presentation/providers/theme_provider.dart';
import 'package:app_novik/presentation/components/app_area_chart.dart';
import 'package:app_novik/presentation/components/app_charts.dart';
import 'package:app_novik/presentation/components/app_tabs.dart';
import 'package:app_novik/presentation/utils/contact_launcher.dart';
import 'package:app_novik/presentation/utils/gestion_receipt.dart';
import 'package:app_novik/presentation/widgets/gestion_abrir.dart';
import 'package:app_novik/presentation/widgets/gestion_form.dart';
import 'package:app_novik/presentation/widgets/inicio_executive_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/screen_look.dart';

/// Ruta base de la API según la URL con la que se compile (en producción lleva `/7power/public`).
final _apiPath = Uri.parse(ApiConstants.baseUrl).path;

/// Jueves 19 de noviembre de 2026: la semana termina el domingo 22.
final _now = DateTime(2026, 11, 19, 9, 30);

const _verTodo = {'clientes.seguimiento', 'clientes.seguimiento.registrar'};
const _soloVer = {'clientes.seguimiento'};

// ---------------------------------------------------------------------------------------------
// Datos de ejemplo
// ---------------------------------------------------------------------------------------------

const _resultados = [
  GestionResultado(
    clave: 'oportunidad',
    etiqueta: 'Oportunidad',
    tono: GestionTono.positivo,
    cuando: 'Interesado en comprar, solicita cotización.',
  ),
  GestionResultado(
    clave: 'seguimiento',
    etiqueta: 'Seguimiento',
    tono: GestionTono.espera,
    cuando: 'Solicita contactar después, sin necesidad de stock.',
  ),
  GestionResultado(
    clave: 'con_objeciones',
    etiqueta: 'Con objeciones',
    tono: GestionTono.objecion,
    cuando: 'Precio no competitivo, compra a la competencia.',
  ),
  GestionResultado(
    clave: 'sin_respuesta',
    etiqueta: 'Sin respuesta',
    tono: GestionTono.neutro,
    cuando: 'No contesta.',
  ),
  GestionResultado(
    clave: 'no_recuperable',
    etiqueta: 'No recuperable',
    tono: GestionTono.perdido,
    cuando: 'No está interesado, datos incorrectos, negocio cerrado.',
  ),
];

List<GestionTarea> _tareas() => [
      GestionTarea(
        id: 1,
        clienteId: 7,
        cliente: 'ACME SAC',
        tipo: 'llamada',
        tipoEtiqueta: 'Llamada telefónica',
        accion: 'Enviar cotización',
        fecha: DateTime(2026, 11, 12, 10),
        vencida: true,
        ejecutivoId: 4,
        ejecutivo: 'FRANCIS BULNES GONZALES',
      ),
      GestionTarea(
        id: 2,
        clienteId: 8,
        cliente: 'BETA SAC',
        tipo: 'whatsapp',
        tipoEtiqueta: 'WhatsApp',
        fecha: DateTime(2026, 11, 19, 15),
        vencida: false,
        ejecutivoId: 5,
        ejecutivo: 'LUIS VENDEDOR',
      ),
      GestionTarea(
        id: 3,
        clienteId: 9,
        cliente: 'GAMMA EIRL',
        tipo: 'visita',
        tipoEtiqueta: 'Visita presencial',
        fecha: DateTime(2026, 11, 21, 9),
        vencida: false,
        ejecutivoId: 4,
        ejecutivo: 'FRANCIS BULNES GONZALES',
      ),
      GestionTarea(
        id: 4,
        clienteId: 10,
        cliente: 'DELTA SAC',
        tipo: 'correo',
        tipoEtiqueta: 'Correo electrónico',
        accion: 'Mandar catálogo',
        fecha: DateTime(2026, 11, 27, 11),
        vencida: false,
      ),
    ];

GestionRegistro _registro({
  int id = 11,
  GestionContacto tipo = GestionContacto.llamada,
  String resultado = 'oportunidad',
  String etiqueta = 'Oportunidad',
  GestionTono tono = GestionTono.positivo,
  String? comentario = 'Pidió cotización',
  DateTime? fecha,
  DateTime? proximo,
  GestionContacto? proximoTipo,
  String? accion,
  GestionSeguimiento? estado,
  bool vencida = false,
}) =>
    GestionRegistro(
      id: id,
      tipo: tipo,
      tipoEtiqueta: tipo.etiqueta,
      resultado: resultado,
      resultadoEtiqueta: etiqueta,
      tono: tono,
      comentario: comentario,
      registradoPor: 'FRANCIS BULNES GONZALES',
      fecha: fecha ?? DateTime(2026, 11, 10, 10),
      proximoSeguimiento: proximo,
      proximoTipo: proximoTipo,
      proximoTipoEtiqueta: proximoTipo?.etiqueta,
      proximaAccion: accion,
      seguimientoEstado: estado,
      vencida: vencida,
    );

/// La gestión que dejó programado el siguiente contacto.
GestionRegistro _programada() => _registro(
      proximo: DateTime(2026, 11, 22, 10),
      proximoTipo: GestionContacto.whatsapp,
      accion: 'Enviar cotización',
      estado: GestionSeguimiento.programado,
    );

/// La de antes: su siguiente contacto ya se cumplió.
GestionRegistro _cumplida() => _registro(
      id: 10,
      tipo: GestionContacto.visita,
      resultado: 'sin_respuesta',
      etiqueta: 'Sin respuesta',
      tono: GestionTono.neutro,
      comentario: null,
      fecha: DateTime(2026, 10, 2, 15),
      proximo: DateTime(2026, 10, 9, 10),
      proximoTipo: GestionContacto.llamada,
      accion: 'Llamar de nuevo',
      estado: GestionSeguimiento.cumplido,
    );

GestionHistorial _historial() => GestionHistorial(
      gestiones: [_programada(), _cumplida()],
      proxima: _programada(),
      totalAnio: 2,
      desdeAnio: DateTime(2026),
    );

GestionFicha _ficha(
  int id, {
  String nombre = 'ACME SAC',
  String? telefono = '987 654 321',
  String? email = 'compras@acme.pe',
  bool contactoOculto = false,
  GestionEstado estado = GestionEstado.critico,
  bool conGestion = true,
  double? caida = 45,
}) =>
    GestionFicha(
      cliente: GestionCliente(
        id: id,
        codigo: 'C-001',
        nombre: nombre,
        esEmpresa: true,
        documento: '20123456789',
        telefono: telefono,
        email: email,
        contactoOculto: contactoOculto,
        direccion: 'Av. Principal 123',
        ciudad: 'Lima',
        categoria: 'Mayorista',
        vendedor: 'FRANCIS BULNES GONZALES',
        condicionPago: 'Crédito 30 días',
        limiteCredito: 5000,
        estado: estado,
        estadoEtiqueta: estado == GestionEstado.critico ? 'Crítico' : 'Sin comparación',
      ),
      kpis: GestionKpis(
        diasSinComprar: 12,
        ultimaCompra: GestionUltimaCompra(id: 5, fecha: DateTime(2026, 11, 7), documento: 'F001-1250', monto: 1234.5),
      ),
      periodo: GestionPeriodo(
        desde: DateTime(2026),
        hasta: DateTime(2026, 11, 19),
        etiqueta: '1 ene - 19 nov 2026',
        etiquetaAnterior: '1 ene - 19 nov 2025',
        ventas: 5500,
        compras: 11,
        ticketPromedio: 500,
        ventasAnterior: 10000,
        variacion: -4500,
        caidaPct: caida,
      ),
      ultimaGestion: conGestion ? _programada() : null,
      proximaGestion: conGestion ? _programada() : null,
      productos: const [
        GestionProducto(producto: 'Cable UTP', codigo: 'P-100', monto: 3000, porcentaje: 54.5),
        GestionProducto(producto: 'Otros', monto: 2500, porcentaje: 45.5),
      ],
    );

GestionCompras _compras({int anioListas = 2026, double? caida = 45}) => GestionCompras(
      periodo: GestionPeriodo(
        desde: DateTime(2026),
        hasta: DateTime(2026, 11, 19),
        etiqueta: '1 ene - 19 nov 2026',
        etiquetaAnterior: '1 ene - 19 nov 2025',
        ventas: 5500,
        compras: 11,
        ticketPromedio: 500,
        ventasAnterior: 10000,
        variacion: -4500,
        caidaPct: caida,
      ),
      anioActual: 2026,
      anioAnterior: 2025,
      anioListas: anioListas,
      hasta: '19/11',
      evolucion: [
        for (var m = 1; m <= 12; m++) GestionMes(mes: m, anterior: m * 100.0, actual: m <= 11 ? m * 50.0 : 0),
      ],
      acumulado: [
        for (var m = 1; m <= 12; m++)
          GestionMes(
            mes: m,
            anterior: m * 1000.0,
            actual: m <= 11 ? m * 500.0 : null,
            corte: m >= 11 ? 'al 19 nov' : null,
          ),
      ],
      ultimasCompras: [
        GestionUltimaCompra(id: 5, fecha: DateTime(2026, 11, 7), documento: 'F001-1250', monto: 1234.5),
        GestionUltimaCompra(id: 4, fecha: DateTime(2026, 10, 2), documento: 'B001-00123', monto: 80),
      ],
      topProductos: const [
        GestionTop(nombre: 'Cable UTP', codigo: 'P-100', monto: 3000, porcentaje: 54.5),
        GestionTop(nombre: 'Conector', codigo: 'P-200', monto: 1, porcentaje: 0.04),
        GestionTop(nombre: 'Otros', monto: 2500, porcentaje: 45.5),
      ],
      topMarcas: const [GestionTop(nombre: 'Marca X', monto: 4000, porcentaje: 72.7)],
      topCategorias: const [],
    );

List<GestionDocumento> _documentos() => [
      GestionDocumento(
        clave: 'cotizacion-21',
        id: 21,
        tipo: GestionDocumentoTipo.cotizacion,
        numero: 'C001-0021',
        nroDocumento: 21,
        fecha: DateTime(2026, 11, 5),
        monto: 800,
        estado: 'Pendiente',
        ejecutivo: 'FRANCIS BULNES GONZALES',
        almacen: 'Lima',
      ),
      GestionDocumento(
        clave: 'venta-5',
        id: 5,
        tipo: GestionDocumentoTipo.factura,
        numero: 'F001-1250',
        nroDocumento: 1250,
        fecha: DateTime(2026, 11, 7),
        monto: 1234.5,
        estado: 'Emitido',
        ejecutivo: 'FRANCIS BULNES GONZALES',
        almacen: 'Lima',
      ),
      GestionDocumento(
        clave: 'venta-6',
        id: 6,
        tipo: GestionDocumentoTipo.venta,
        numero: 'V001-0012',
        nroDocumento: 12,
        fecha: DateTime(2026, 10, 20),
        monto: 50,
        estado: 'Anulado',
      ),
    ];

DocumentEntity _comprobante(int id, {DocumentKind kind = DocumentKind.venta}) =>
    DocumentEntity(id: id, kind: kind, numero: '$id', comprobante: 'C$id');

// ---------------------------------------------------------------------------------------------
// Repositorio falso
// ---------------------------------------------------------------------------------------------

class _FakeGestionRepository implements GestionRepository {
  GestionCatalogo catalogo = const GestionCatalogo(resultados: _resultados);
  Failure? catalogoFailure;
  int catalogoCalls = 0;

  List<GestionClienteBuscado> clientes = const [
    GestionClienteBuscado(id: 7, nombre: 'ACME SAC', documento: '20123456789', codigo: 'C-001', ciudad: 'Lima'),
    GestionClienteBuscado(id: 12, nombre: 'ACERO SUR', documento: '20999999999', activo: false),
  ];
  final searches = <String>[];
  Failure? searchFailure;

  bool equipo = false;
  List<GestionTarea> tareas = _tareas();
  Failure? tareasFailure;
  int tareasCalls = 0;

  GestionFicha Function(int id) fichaOf = _ficha;
  Failure? Function(int id)? fichaFailure;
  final fichaIds = <int>[];

  GestionHistorial historial = _historial();
  Failure? historialFailure;
  int historialCalls = 0;

  Failure? writeFailure;
  final registradas = <({int clienteId, GestionNueva gestion})>[];
  final editadas = <({int id, GestionEdicion gestion})>[];
  final reprogramadas = <({int id, DateTime proximo})>[];

  /// Para frenar la respuesta de una ficha y probar que una vieja no pisa a la nueva.
  Map<int, Completer<void>> fichaGates = {};

  @override
  Future<Either<Failure, GestionCatalogo>> getCatalogo() async {
    catalogoCalls++;
    final failure = catalogoFailure;
    return failure != null ? Either.left(failure) : Either.right(catalogo);
  }

  @override
  Future<Either<Failure, List<GestionClienteBuscado>>> buscarClientes(String query) async {
    searches.add(query);
    final failure = searchFailure;
    return failure != null ? Either.left(failure) : Either.right(clientes);
  }

  @override
  Future<Either<Failure, GestionTareas>> getTareas() async {
    tareasCalls++;
    final failure = tareasFailure;
    return failure != null ? Either.left(failure) : Either.right(GestionTareas(equipo: equipo, tareas: tareas));
  }

  @override
  Future<Either<Failure, GestionFicha>> getFicha(int clienteId) async {
    fichaIds.add(clienteId);
    final gate = fichaGates[clienteId];
    if (gate != null) await gate.future;
    final failure = fichaFailure?.call(clienteId);
    return failure != null ? Either.left(failure) : Either.right(fichaOf(clienteId));
  }

  @override
  Future<Either<Failure, GestionHistorial>> getGestiones(int clienteId) async {
    historialCalls++;
    final failure = historialFailure;
    return failure != null ? Either.left(failure) : Either.right(historial);
  }

  @override
  Future<Either<Failure, void>> registrar(int clienteId, GestionNueva gestion) async {
    registradas.add((clienteId: clienteId, gestion: gestion));
    final failure = writeFailure;
    return failure != null ? Either.left(failure) : Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> editar(int gestionId, GestionEdicion gestion) async {
    editadas.add((id: gestionId, gestion: gestion));
    final failure = writeFailure;
    return failure != null ? Either.left(failure) : Either.rightVoid();
  }

  @override
  Future<Either<Failure, void>> reprogramar(int gestionId, DateTime proximo) async {
    reprogramadas.add((id: gestionId, proximo: proximo));
    final failure = writeFailure;
    return failure != null ? Either.left(failure) : Either.rightVoid();
  }

  Failure? comprasFailure;
  double? comprasCaida = 45;
  final comprasAnios = <int?>[];

  @override
  Future<Either<Failure, GestionCompras>> getCompras(int clienteId, {int? anio}) async {
    comprasAnios.add(anio);
    final failure = comprasFailure;
    return failure != null ? Either.left(failure) : Either.right(_compras(anioListas: anio ?? 2026, caida: comprasCaida));
  }

  List<GestionDocumento> documentos = _documentos();
  Failure? documentosFailure;
  final documentosRangos = <({DateTime desde, DateTime hasta})>[];

  @override
  Future<Either<Failure, List<GestionDocumento>>> getDocumentos(
    int clienteId, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    documentosRangos.add((desde: desde, hasta: hasta));
    final failure = documentosFailure;
    return failure != null ? Either.left(failure) : Either.right(documentos);
  }

  Failure? abrirFailure;
  final ventasAbiertas = <int>[];
  final cotizacionesAbiertas = <({int companyId, int id, int nroDocumento})>[];

  @override
  Future<Either<Failure, DocumentEntity>> getVenta(int id) async {
    ventasAbiertas.add(id);
    final failure = abrirFailure;
    return failure != null ? Either.left(failure) : Either.right(_comprobante(id));
  }

  @override
  Future<Either<Failure, DocumentEntity>> getCotizacion({
    required int companyId,
    required int id,
    required int nroDocumento,
  }) async {
    cotizacionesAbiertas.add((companyId: companyId, id: id, nroDocumento: nroDocumento));
    final failure = abrirFailure;
    return failure != null ? Either.left(failure) : Either.right(_comprobante(id, kind: DocumentKind.cotizacion));
  }
}

// ---------------------------------------------------------------------------------------------
// Sesión y pantalla
// ---------------------------------------------------------------------------------------------

class _FakeThemeStorage implements ThemeLocalDataSource {
  @override
  Future<ThemeMode?> read() async => null;

  @override
  Future<void> write(ThemeMode mode) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> login(String usuario, String password) async =>
      Either.right(const UserEntity(id: 9, name: 'Ana', usuario: 'ana'));

  @override
  Future<Either<Failure, void>> logout() async => Either.rightVoid();

  @override
  Future<Either<Failure, SessionContextEntity?>> getSessionContext() async => Either.right(null);

  @override
  Future<String?> getToken() async => null;

  @override
  Future<Either<Failure, SavedCredentialsEntity?>> getSavedCredentials() async => Either.right(null);

  @override
  Future<Either<Failure, void>> saveCredentials(String usuario, String password) async => Either.rightVoid();

  @override
  Future<Either<Failure, void>> clearSavedCredentials() async => Either.rightVoid();
}

SessionContextEntity _session({int companyId = 1, int userId = 9, Set<String> permissions = _verTodo}) =>
    SessionContextEntity(
      user: UserEntity(id: userId, name: 'Ana', usuario: 'ana'),
      company: CompanyEntity(id: companyId, razonSocial: 'ACME'),
      modules: const [],
      permissions: permissions,
      roles: const [],
      warehouses: const [],
    );

AuthProvider _auth(SessionContextEntity session) {
  final repo = _FakeAuthRepository();
  return AuthProvider(
    loginUseCase: LoginUseCase(repository: repo),
    logoutUseCase: LogoutUseCase(repository: repo),
    getSessionContextUseCase: GetSessionContextUseCase(repository: repo),
    getSavedCredentialsUseCase: GetSavedCredentialsUseCase(repository: repo),
    saveCredentialsUseCase: SaveCredentialsUseCase(repository: repo),
    clearSavedCredentialsUseCase: ClearSavedCredentialsUseCase(repository: repo),
  )..session = session;
}

GestionProvider _provider(_FakeGestionRepository repo, {SessionContextEntity? session, VoidCallback? onExpired}) =>
    GestionProvider(
      getCatalogoUseCase: GetGestionCatalogoUseCase(repository: repo),
      searchClientsUseCase: SearchGestionClientesUseCase(repository: repo),
      getTareasUseCase: GetGestionTareasUseCase(repository: repo),
      getFichaUseCase: GetGestionFichaUseCase(repository: repo),
      getHistorialUseCase: GetGestionHistorialUseCase(repository: repo),
      registerUseCase: RegisterGestionUseCase(repository: repo),
      editUseCase: EditGestionUseCase(repository: repo),
      rescheduleUseCase: RescheduleGestionUseCase(repository: repo),
      getComprasUseCase: GetGestionComprasUseCase(repository: repo),
      getDocumentosUseCase: GetGestionDocumentosUseCase(repository: repo),
      getVentaUseCase: GetGestionVentaUseCase(repository: repo),
      getCotizacionUseCase: GetGestionCotizacionUseCase(repository: repo),
      onSessionExpired: onExpired,
      clock: () => _now,
    )..syncSession(session ?? _session());

typedef _Env = ({
  _FakeGestionRepository repo,
  GestionProvider provider,
  ShellNavigation navigation,
});

Future<_Env> _pump(
  WidgetTester tester, {
  Set<String> permissions = _verTodo,
  ScreenLook? look,
  Size size = const Size(400, 2600),
  void Function(_FakeGestionRepository repo)? setUp,
  ({int clienteId, String nombre})? pending,
  GestionPestana pestana = GestionPestana.seguimiento,
  bool settle = true,
}) async {
  if (look != null) {
    await prepareLook(tester, look);
  } else {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final repo = _FakeGestionRepository();
  setUp?.call(repo);
  final session = _session(permissions: permissions);
  final provider = _provider(repo, session: session);
  addTearDown(provider.dispose);
  final navigation = ShellNavigation();
  if (pending != null) navigation.goToGestionCliente(pending.clienteId, pending.nombre, pestana: pestana);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(storage: _FakeThemeStorage())),
        ChangeNotifierProvider<AuthProvider>.value(value: _auth(session)),
        ChangeNotifierProvider<ShellNavigation>.value(value: navigation),
        ChangeNotifierProvider<GestionProvider>.value(value: provider),
      ],
      child: lookApp(look, home: const Scaffold(body: GestionPage())),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return (repo: repo, provider: provider, navigation: navigation);
}

/// Toca una pestaña de la ficha (la barra se desplaza de lado): primero la deja a la vista.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(AppTabBar), matching: find.text(label));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// Toca una etiqueta de la fila de filtros (que se desplaza de lado): primero la deja a la vista.
Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ChoiceChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Elige un tipo de contacto en el primer selector de la pantalla (el de la gestión, no el del siguiente contacto).
Future<void> _tipo(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(GestionTipoSelector).first, matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Abre un cliente desde la lista de tareas (en Seguimiento).
Future<void> _openFromTask(WidgetTester tester, String cliente) async {
  await tester.tap(find.textContaining(cliente));
  await tester.pumpAndSettle();
}

void main() {
  late Future<bool> Function(Uri uri) originalOpen;
  late List<Uri> opened;
  late Future<void> Function(BuildContext, DocumentEntity) originalReceipt;
  // Los comprobantes que se abrieron (el PDF no corre en las pruebas).
  late List<DocumentEntity> receipts;

  setUp(() {
    originalOpen = ContactLauncher.open;
    originalReceipt = GestionReceipt.open;
    opened = [];
    receipts = [];
    ContactLauncher.open = (uri) async {
      opened.add(uri);
      return true;
    };
    GestionReceipt.open = (context, document) async => receipts.add(document);
  });

  tearDown(() {
    ContactLauncher.open = originalOpen;
    GestionReceipt.open = originalReceipt;
  });

  // -------------------------------------------------------------------------------------------
  group('Modelo', () {
    test('las tareas traen el ejecutivo y las fechas son hora local, sin pasar a UTC', () {
      final tareas = gestionTareasFromJson({
        'success': true,
        'equipo': true,
        'data': [
          {
            'id': 3,
            'cliente_id': 7,
            'cliente': 'ACME SAC',
            'tipo': 'llamada',
            'tipo_etiqueta': 'Llamada telefónica',
            'accion': 'Enviar cotización',
            'fecha': '2026-11-12 10:00:00',
            'vencida': true,
            'ejecutivo_id': 4,
            'ejecutivo': 'FRANCIS BULNES',
          },
          {'id': 4, 'cliente_id': 8, 'cliente': 'BETA', 'tipo': 'visita', 'fecha': '2026-11-20 08:30:00'},
        ],
      });

      expect(tareas.equipo, isTrue);
      final primera = tareas.tareas.first;
      expect(primera.clienteId, 7);
      expect(primera.accion, 'Enviar cotización');
      expect(primera.vencida, isTrue);
      expect(primera.ejecutivoId, 4);
      expect(primera.fecha, DateTime(2026, 11, 12, 10));
      expect(primera.fecha.isUtc, isFalse);
      expect(tareas.tareas.last.ejecutivoId, isNull);
      expect(tareas.tareas.last.ejecutivo, isNull);
    });

    test('la ficha lee el cliente, el periodo, la última compra y las gestiones', () {
      final ficha = gestionFichaFromJson({
        'cliente': {
          'id': 7,
          'codigo': 'C-001',
          'nombre': 'ACME SAC',
          'tipo': 'Empresa',
          'documento': '20123456789',
          'telefono': null,
          'email': null,
          'contacto_oculto': true,
          'limite_credito': '5000.50',
          'activo': true,
          'estado': {'clave': 'sin_base', 'etiqueta': 'Sin comparación'},
        },
        'kpis': {
          'dias_sin_comprar': 12,
          'ultima_compra': {'id': 5, 'fecha': '2026-11-07', 'documento': 'F001-1250', 'monto': 1234.5},
        },
        'periodo': {
          'desde': '2026-01-01',
          'hasta': '2026-11-19',
          'etiqueta': '1 ene - 19 nov 2026',
          'etiqueta_anterior': '1 ene - 19 nov 2025',
          'ventas': 5500,
          'compras': 11,
          'ticket_promedio': 500,
          'ventas_anterior': 0,
          'variacion': 5500,
          'caida_pct': null,
        },
        'ultima_gestion': null,
        'proxima_gestion': {
          'id': 11,
          'tipo_contacto': 'llamada',
          'tipo_etiqueta': 'Llamada telefónica',
          'resultado': 'oportunidad',
          'resultado_etiqueta': 'Oportunidad',
          'tono': 'positivo',
          'fecha': '2026-11-10 10:00:00',
          'proximo_seguimiento': '2026-11-22 10:00:00',
          'proximo_tipo_contacto': 'whatsapp',
          'proximo_tipo_etiqueta': 'WhatsApp',
          'proxima_accion': 'Enviar cotización',
          'seguimiento_estado': 'programado',
          'vencida': false,
        },
        'productos_principales': [
          {'producto': 'Cable UTP', 'codigo': 'P-100', 'monto': 3000, 'porcentaje': 54.5},
        ],
      });

      expect(ficha.cliente.esEmpresa, isTrue);
      expect(ficha.cliente.telefono, isNull);
      expect(ficha.cliente.contactoOculto, isTrue);
      expect(ficha.cliente.limiteCredito, 5000.5);
      expect(ficha.cliente.estado, GestionEstado.sinBase);
      expect(ficha.kpis.diasSinComprar, 12);
      expect(ficha.kpis.ultimaCompra?.documento, 'F001-1250');
      expect(ficha.periodo.caidaPct, isNull);
      expect(ficha.ultimaGestion, isNull);
      expect(ficha.proximaGestion?.proximoTipo, GestionContacto.whatsapp);
      expect(ficha.proximaGestion?.seguimientoEstado, GestionSeguimiento.programado);
      expect(ficha.proximaGestion?.proximoSeguimiento, DateTime(2026, 11, 22, 10));
      expect(ficha.productos.single.codigo, 'P-100');
    });

    test('registrar manda solo lo que hay y el tipo del siguiente contacto sigue al de la gestión', () {
      expect(
        gestionNuevaToJson(const GestionNueva(tipo: GestionContacto.visita, resultado: 'sin_respuesta', comentario: '  ')),
        {'tipo_contacto': 'visita', 'resultado': 'sin_respuesta'},
      );
      expect(
        gestionNuevaToJson(
          GestionNueva(
            tipo: GestionContacto.llamada,
            resultado: 'oportunidad',
            comentario: ' Interesado ',
            proximo: DateTime(2026, 11, 25, 9, 5),
            proximaAccion: ' Enviar cotización ',
          ),
        ),
        {
          'tipo_contacto': 'llamada',
          'resultado': 'oportunidad',
          'comentario': 'Interesado',
          'proximo_seguimiento': '2026-11-25 09:05:00',
          'proximo_tipo_contacto': 'llamada',
          'proxima_accion': 'Enviar cotización',
        },
      );
    });

    test('editar: quitar el siguiente contacto manda null; uno cumplido solo manda la acción', () {
      expect(
        gestionEdicionToJson(const GestionEdicion(tipo: GestionContacto.llamada, resultado: 'oportunidad')),
        {'tipo_contacto': 'llamada', 'resultado': 'oportunidad', 'proximo_seguimiento': null},
      );
      expect(
        gestionEdicionToJson(
          GestionEdicion(
            tipo: GestionContacto.llamada,
            resultado: 'oportunidad',
            proximo: DateTime(2026, 11, 25, 10),
            proximoTipo: GestionContacto.correo,
          ),
        ),
        {
          'tipo_contacto': 'llamada',
          'resultado': 'oportunidad',
          'proximo_seguimiento': '2026-11-25 10:00:00',
          'proximo_tipo_contacto': 'correo',
        },
      );
      expect(
        gestionEdicionToJson(
          const GestionEdicion(
            tipo: GestionContacto.visita,
            resultado: 'sin_respuesta',
            cumplida: true,
            proximaAccion: 'Llamar',
          ),
        ),
        {'tipo_contacto': 'visita', 'resultado': 'sin_respuesta', 'proxima_accion': 'Llamar'},
      );
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Datasource', () {
    http.Response ok(Object body) => http.Response(jsonEncode(body), 200);

    test('el catálogo, la búsqueda, las tareas, la ficha y las gestiones usan las rutas y el token de la web', () async {
      final requests = <http.Request>[];
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((request) async {
          requests.add(request);
          return ok({'success': true, 'data': [], 'resultados': [], 'cliente': {}});
        }),
      );

      await ds.getCatalogo('tok');
      await ds.buscarClientes('tok', 'acme sac');
      await ds.getTareas('tok');
      await ds.getFicha('tok', 7);
      await ds.getGestiones('tok', 7);

      expect(requests.map((r) => r.method), everyElement('GET'));
      expect(requests.map((r) => r.url.path), [
        '$_apiPath/seguimiento-clientes/catalogo',
        '$_apiPath/seguimiento-clientes/buscar',
        '$_apiPath/seguimiento-clientes/tareas',
        '$_apiPath/seguimiento-clientes/7/ficha',
        '$_apiPath/seguimiento-clientes/7/gestiones',
      ]);
      expect(requests[1].url.queryParameters, {'q': 'acme sac'});
      expect(requests.map((r) => r.headers['Authorization']), everyElement('Bearer tok'));
    });

    test('registrar hace POST con el cuerpo de la web', () async {
      late http.Request request;
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((r) async {
          request = r;
          return http.Response('{"success":true}', 201);
        }),
      );

      await ds.registrar(
        't',
        7,
        GestionNueva(
          tipo: GestionContacto.whatsapp,
          resultado: 'seguimiento',
          proximo: DateTime(2026, 12, 1, 10),
          proximoTipo: GestionContacto.llamada,
          proximaAccion: 'Llamar',
        ),
      );

      expect(request.method, 'POST');
      expect(request.url.path, '$_apiPath/seguimiento-clientes/7/gestiones');
      expect(jsonDecode(request.body), {
        'tipo_contacto': 'whatsapp',
        'resultado': 'seguimiento',
        'proximo_seguimiento': '2026-12-01 10:00:00',
        'proximo_tipo_contacto': 'llamada',
        'proxima_accion': 'Llamar',
      });
    });

    test('editar y reprogramar hacen PUT a la gestión', () async {
      final requests = <http.Request>[];
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('{"success":true}', 200);
        }),
      );

      await ds.editar('t', 11, const GestionEdicion(tipo: GestionContacto.correo, resultado: 'oportunidad'));
      await ds.reprogramar('t', 11, DateTime(2026, 12, 3, 16, 30));

      expect(requests.map((r) => r.method), ['PUT', 'PUT']);
      expect(requests[0].url.path, '$_apiPath/seguimiento-clientes/gestiones/11');
      expect(jsonDecode(requests[0].body), {
        'tipo_contacto': 'correo',
        'resultado': 'oportunidad',
        'proximo_seguimiento': null,
      });
      expect(requests[1].url.path, '$_apiPath/seguimiento-clientes/gestiones/11/reprogramar');
      expect(jsonDecode(requests[1].body), {'proximo_seguimiento': '2026-12-03 16:30:00'});
    });

    test('un 403 (cliente ajeno a la cartera) y un 404 llegan con el mensaje del servidor', () async {
      final ds403 = GestionRemoteDataSourceImpl(
        client: MockClient(
          (_) async => http.Response('{"success":false,"message":"Este cliente no es de tu cartera"}', 403),
        ),
      );
      await expectLater(
        ds403.getFicha('t', 7),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Este cliente no es de tu cartera')),
      );

      final ds404 = GestionRemoteDataSourceImpl(
        client: MockClient((_) async => http.Response('{"success":false,"message":"Cliente no encontrado"}', 404)),
      );
      await expectLater(
        ds404.getGestiones('t', 99),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Cliente no encontrado')),
      );

      // Sin cuerpo útil, un texto de siempre.
      final sinTexto = GestionRemoteDataSourceImpl(client: MockClient((_) async => http.Response('', 403)));
      await expectLater(
        sinTexto.getTareas('t'),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'No tienes permiso para esta acción')),
      );
    });

    test('un 422 llega como error de validación con el primer mensaje de errors{campo: [mensaje]}', () async {
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'The given data was invalid.',
              'errors': {
                'proximo_seguimiento': ['La fecha del siguiente contacto no puede ser de un día ya pasado'],
              },
            }),
            422,
          ),
        ),
      );

      await expectLater(
        ds.registrar('t', 7, const GestionNueva(tipo: GestionContacto.llamada, resultado: 'oportunidad')),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'La fecha del siguiente contacto no puede ser de un día ya pasado',
          ),
        ),
      );
    });

    test('un 401 es sesión vencida y el mensaje de validación sin errors usa message', () async {
      final ds401 = GestionRemoteDataSourceImpl(client: MockClient((_) async => http.Response('{"message":"x"}', 401)));
      await expectLater(ds401.getTareas('t'), throwsA(isA<AuthException>()));

      expect(gestionErrorMessage('{"message":"Texto"}'), 'Texto');
      expect(gestionErrorMessage('{"errors":{"a":["Uno","Dos"]}}'), 'Uno');
      expect(gestionErrorMessage('no es json'), isNull);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Abrir otra app', () {
    test('el WhatsApp es de un celular peruano de 9 dígitos, con o sin el 51 y con cualquier separador', () {
      expect(ContactLauncher.whatsappNumber('987 654 321'), '51987654321');
      expect(ContactLauncher.whatsappNumber('+51 987-654-321'), '51987654321');
      expect(ContactLauncher.whatsappNumber('51987654321'), '51987654321');
      expect(ContactLauncher.whatsappNumber('(01) 234-5678'), isNull);
      expect(ContactLauncher.whatsappNumber('87654321'), isNull);
      expect(ContactLauncher.whatsappNumber(null), isNull);
    });

    test('llamar deja solo dígitos y +; escribir arma el mailto; WhatsApp va a wa.me', () async {
      await ContactLauncher.call('(+51) 987 654-321');
      await ContactLauncher.email('compras@acme.pe');
      await ContactLauncher.whatsapp('51987654321');

      expect(opened.map((u) => u.toString()), [
        'tel:+51987654321',
        'mailto:compras@acme.pe',
        'https://wa.me/51987654321',
      ]);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Provider', () {
    Future<GestionProvider> loaded(_FakeGestionRepository repo, {SessionContextEntity? session}) async {
      final provider = _provider(repo, session: session);
      addTearDown(provider.dispose);
      await provider.loadTareas();
      return provider;
    }

    test('las tareas del periodo: hoy deja las de hoy y las vencidas; semana hasta el domingo; mes hasta fin de mes', () async {
      final provider = await loaded(_FakeGestionRepository());

      expect(provider.periodo, TaskPeriod.hoy);
      expect(provider.tareasDelPeriodo.map((t) => t.id), [1, 2]);
      provider.setPeriodo(TaskPeriod.semana);
      expect(provider.tareasDelPeriodo.map((t) => t.id), [1, 2, 3]);
      provider.setPeriodo(TaskPeriod.mes);
      expect(provider.tareasDelPeriodo.map((t) => t.id), [1, 2, 3, 4]);
    });

    test('el tipo filtra y los conteos son los del periodo', () async {
      final provider = await loaded(_FakeGestionRepository());

      expect(provider.conteoTareas('todas'), 2);
      expect(provider.conteoTareas('llamada'), 1);
      expect(provider.conteoTareas('visita'), 0);
      provider.setPeriodo(TaskPeriod.mes);
      expect(provider.conteoTareas('todas'), 4);
      expect(provider.conteoTareas('correo'), 1);

      provider.setTipoTareas('whatsapp');
      expect(provider.tareasVisibles.map((t) => t.id), [2]);
      provider.setTipoTareas('todas');
      expect(provider.tareasVisibles, hasLength(4));
    });

    test('los ejecutivos salen con sus tareas del mes por orden alfabético y filtran, también "sin ejecutivo"', () async {
      final repo = _FakeGestionRepository()..equipo = true;
      final provider = await loaded(repo);

      expect(provider.equipo, isTrue);
      expect(provider.ejecutivos.map((e) => (e.nombre, e.tareas)), [
        ('FRANCIS BULNES GONZALES', 2),
        ('LUIS VENDEDOR', 1),
        ('Sin ejecutivo', 1),
      ]);

      provider.setPeriodo(TaskPeriod.mes);
      provider.setEjecutivo(5);
      expect(provider.tareasVisibles.map((t) => t.id), [2]);
      provider.setEjecutivo(GestionProvider.sinEjecutivo);
      expect(provider.tareasVisibles.map((t) => t.id), [4]);
      provider.setEjecutivo(null);
      expect(provider.tareasVisibles, hasLength(4));
    });

    test('un ejecutivo que ya no tiene tareas deja de filtrar al refrescar', () async {
      final repo = _FakeGestionRepository()..equipo = true;
      final provider = await loaded(repo);
      provider.setEjecutivo(5);

      repo.tareas = [for (final t in _tareas()) if (t.ejecutivoId != 5) t];
      await provider.loadTareas(silent: true);

      expect(provider.ejecutivo, isNull);
    });

    test('un fallo al refrescar no borra las tareas que ya se veían', () async {
      final repo = _FakeGestionRepository();
      final provider = await loaded(repo);

      repo.tareasFailure = const NetworkFailure('Sin conexión a internet');
      await provider.loadTareas(silent: true);

      expect(provider.tareas, hasLength(4));
      expect(provider.tareasError, isNull);
    });

    test('un fallo de la primera carga deja el mensaje', () async {
      final repo = _FakeGestionRepository()..tareasFailure = const ServerFailure('Error del servidor');
      final provider = await loaded(repo);

      expect(provider.tareasLoaded, isFalse);
      expect(provider.tareasError, 'Error del servidor');
    });

    test('los permisos salen de la sesión: ver y registrar', () {
      final repo = _FakeGestionRepository();
      expect(_provider(repo, session: _session()).canRegister, isTrue);
      final soloVer = _provider(repo, session: _session(permissions: _soloVer));
      expect(soloVer.canView, isTrue);
      expect(soloVer.canRegister, isFalse);
      expect(_provider(repo, session: _session(permissions: const {})).canView, isFalse);
    });

    test('sin permiso de registrar no se guarda nada ni se llama al servidor', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo, session: _session(permissions: _soloVer));
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');

      final registrar = await provider.registrar(
        const GestionNueva(tipo: GestionContacto.llamada, resultado: 'oportunidad'),
      );
      final editar = await provider.editar(
        11,
        const GestionEdicion(tipo: GestionContacto.llamada, resultado: 'oportunidad'),
      );
      final reprogramar = await provider.reprogramar(11, DateTime(2026, 12));

      expect(registrar.isLeft && editar.isLeft && reprogramar.isLeft, isTrue);
      expect(repo.registradas, isEmpty);
      expect(repo.editadas, isEmpty);
      expect(repo.reprogramadas, isEmpty);
    });

    test('abrir un cliente pide su ficha y su historial; el filtro de fechas arranca del 1 de enero a hoy', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);

      await provider.openClient(7, 'ACME SAC', tab: 1);

      expect(provider.clienteId, 7);
      expect(provider.ficha?.cliente.nombre, 'ACME SAC');
      expect(provider.historial.gestiones, hasLength(2));
      expect(provider.tabs.index, 1);
      expect(provider.rango.start, DateTime(2026));
      expect(provider.rango.end, DateTime(2026, 11, 19));
      expect(provider.filtrando, isFalse);

      provider.closeClient();
      expect(provider.hasClient, isFalse);
      expect(provider.tabs.index, 0);
    });

    test('abrir otro cliente se queda en la misma pestaña; volver a abrir el mismo no lo recarga', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);

      await provider.openClient(7, 'ACME SAC', tab: 1);
      await provider.openClient(8, 'BETA SAC');
      expect(provider.tabs.index, 1);
      expect(repo.fichaIds, [7, 8]);

      await provider.openClient(8, 'BETA SAC');
      expect(repo.fichaIds, [7, 8]);
    });

    test('la respuesta tardía de un cliente anterior no pisa al que se abrió después', () async {
      final repo = _FakeGestionRepository()..fichaGates = {7: Completer<void>()};
      final provider = _provider(repo);
      addTearDown(provider.dispose);

      final primero = provider.openClient(7, 'ACME SAC');
      await provider.openClient(8, 'BETA SAC');
      repo.fichaGates[7]!.complete();
      await primero;

      expect(provider.clienteId, 8);
      expect(provider.ficha?.cliente.id, 8);
    });

    test('los filtros del historial: tipo, resultado y fechas, y se quitan', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');

      expect(provider.gestionesVisibles.map((g) => g.id), [11, 10]);
      provider.setFiltroTipo(GestionContacto.visita);
      expect(provider.gestionesVisibles.map((g) => g.id), [10]);
      provider.setFiltroTipo(null);
      provider.setFiltroResultado('oportunidad');
      expect(provider.gestionesVisibles.map((g) => g.id), [11]);
      provider.setFiltroResultado(null);
      // Un rango que termina el mismo día de la gestión la incluye (hasta el final del día).
      provider.setRango(DateTimeRange(start: DateTime(2026, 11, 10), end: DateTime(2026, 11, 10)));
      expect(provider.gestionesVisibles.map((g) => g.id), [11]);
      expect(provider.filtrando, isTrue);

      provider.clearFiltros();
      expect(provider.filtrando, isFalse);
      expect(provider.gestionesVisibles, hasLength(2));
    });

    test('registrar refresca la ficha, el historial y las tareas', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');
      await provider.loadTareas();

      final result = await provider.registrar(
        const GestionNueva(tipo: GestionContacto.llamada, resultado: 'oportunidad', comentario: 'ok'),
      );

      expect(result.isRight, isTrue);
      expect(repo.registradas.single.clienteId, 7);
      expect(repo.fichaIds, [7, 7]);
      expect(repo.historialCalls, 2);
      expect(repo.tareasCalls, 2);
    });

    test('si el servidor rechaza el registro no se refresca nada y se devuelve el motivo', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');

      repo.writeFailure = const ValidationFailure('La fecha no puede ser de un día ya pasado');
      final result = await provider.registrar(
        const GestionNueva(tipo: GestionContacto.llamada, resultado: 'oportunidad'),
      );

      expect(result.left.message, 'La fecha no puede ser de un día ya pasado');
      expect(repo.fichaIds, [7]);
      expect(repo.historialCalls, 1);
    });

    test('un token vencido (401) avisa para cerrar la sesión', () async {
      var vencida = 0;
      final repo = _FakeGestionRepository()..tareasFailure = const AuthenticationFailure('Sesión expirada');
      final provider = _provider(repo, onExpired: () => vencida++);
      addTearDown(provider.dispose);

      await provider.loadTareas();

      expect(vencida, 1);
    });

    test('al cambiar de empresa se descarta todo', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo, session: _session(companyId: 1));
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');
      await provider.loadTareas();
      await provider.loadCatalogo();

      provider.syncSession(_session(companyId: 2));

      expect(provider.hasClient, isFalse);
      expect(provider.ficha, isNull);
      expect(provider.tareas, isEmpty);
      expect(provider.tareasLoaded, isFalse);
      expect(provider.catalogo, isNull);
      // Misma empresa y usuario: no descarta.
      await provider.loadTareas();
      provider.syncSession(_session(companyId: 2));
      expect(provider.tareasLoaded, isTrue);
    });

    test('buscar pide al servidor desde 2 letras', () async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo);
      addTearDown(provider.dispose);

      expect((await provider.buscarClientes(' a ')).right, isEmpty);
      expect(repo.searches, isEmpty);
      expect((await provider.buscarClientes(' ac ')).right, hasLength(2));
      expect(repo.searches, ['ac']);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Tareas pendientes', () {
    testWidgets('Mis tareas pendientes de hoy: cada fila con su tipo, cliente, acción y cuándo', (tester) async {
      await _pump(tester);

      expect(find.text('Gestión'), findsOneWidget);
      expect(find.text('Mis tareas pendientes (2)'), findsOneWidget);
      expect(find.text('Llamar – ACME SAC'), findsOneWidget);
      expect(find.text('Enviar cotización'), findsOneWidget);
      expect(find.text('Vencida 12/11'), findsOneWidget);
      expect(find.text('WhatsApp – BETA SAC'), findsOneWidget);
      expect(find.text('Hoy 15:00'), findsOneWidget);
      // Lo de la semana y el mes todavía no.
      expect(find.textContaining('GAMMA'), findsNothing);
      expect(find.textContaining('DELTA'), findsNothing);
      for (final chip in ['Todas (2)', 'Llamadas (1)', 'Visitas (0)', 'WhatsApp (1)', 'Correo (0)']) {
        expect(find.text(chip), findsOneWidget);
      }
      // Quien no ve al equipo no elige ejecutivo.
      expect(find.text('Ejecutivo comercial'), findsNothing);
      expect(find.text('O elige cualquier cliente'), findsOneWidget);
    });

    testWidgets('Semana y Mes suman tareas; el tipo las filtra; "Hoy" vuelve', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas pendientes (3)'), findsOneWidget);
      expect(find.text('Visita – GAMMA EIRL'), findsOneWidget);
      expect(find.text('21/11 09:00'), findsOneWidget);

      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas pendientes (4)'), findsOneWidget);
      expect(find.text('Correo – DELTA SAC'), findsOneWidget);

      await _tapChip(tester, 'Correo (1)');
      expect(find.text('Correo – DELTA SAC'), findsOneWidget);
      expect(find.text('Llamar – ACME SAC'), findsNothing);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas pendientes (2)'), findsOneWidget);
    });

    testWidgets('sin tareas dice que no hay gestiones pendientes para el periodo', (tester) async {
      await _pump(tester, setUp: (repo) => repo.tareas = const []);

      expect(find.text('Mis tareas pendientes (0)'), findsOneWidget);
      expect(find.text('No hay gestiones pendientes para hoy.'), findsOneWidget);

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();
      expect(find.text('No hay gestiones pendientes para la semana.'), findsOneWidget);
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(find.text('No hay gestiones pendientes para el mes.'), findsOneWidget);
    });

    testWidgets('el equipo ve el ejecutivo de cada tarea y puede filtrar por ejecutivo', (tester) async {
      await _pump(tester, setUp: (repo) => repo.equipo = true);

      expect(find.text('Tareas pendientes del equipo (2)'), findsOneWidget);
      expect(find.text('FRANCIS BULNES GONZALES · Enviar cotización'), findsOneWidget);
      expect(find.text('LUIS VENDEDOR'), findsOneWidget);
      expect(find.text('Todos los ejecutivos'), findsOneWidget);

      await tester.tap(find.text('Todos los ejecutivos'));
      await tester.pumpAndSettle();
      // El selector lista a los ejecutivos con sus tareas del mes.
      expect(find.text('LUIS VENDEDOR (1)'), findsOneWidget);
      expect(find.text('Sin ejecutivo (1)'), findsOneWidget);
      await tester.tap(find.text('LUIS VENDEDOR (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Tareas pendientes del equipo (1)'), findsOneWidget);
      expect(find.text('WhatsApp – BETA SAC'), findsOneWidget);
      expect(find.text('Llamar – ACME SAC'), findsNothing);
      expect(find.text('LUIS VENDEDOR (1)'), findsOneWidget);
    });

    testWidgets('si las tareas no cargan, el mensaje y reintentar', (tester) async {
      final env = await _pump(tester, setUp: (repo) => repo.tareasFailure = const NetworkFailure('Sin conexión a internet'));

      expect(find.text('No se pudieron cargar las tareas'), findsOneWidget);
      expect(find.text('Sin conexión a internet'), findsOneWidget);

      env.repo.tareasFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas pendientes (2)'), findsOneWidget);
    });

    testWidgets('tocar una tarea abre la ficha del cliente en la pestaña Seguimiento', (tester) async {
      final env = await _pump(tester);

      await _openFromTask(tester, 'ACME SAC');

      expect(env.repo.fichaIds, [7]);
      expect(env.provider.tabs.index, 1);
      expect(find.text('Registrar nueva gestión'), findsOneWidget);
      expect(find.text('Historial de gestiones'), findsOneWidget);
      // Sigue la ficha, no las tareas.
      expect(find.text('Mis tareas pendientes (2)'), findsNothing);
    });

    testWidgets('sin permiso de ver Gestión: pantalla de acceso', (tester) async {
      final env = await _pump(tester, permissions: const {});

      expect(find.text('Sin acceso'), findsOneWidget);
      expect(env.repo.tareasCalls, 0);
    });

    testWidgets('un pedido del Inicio abre el cliente directo en Seguimiento', (tester) async {
      final env = await _pump(tester, pending: (clienteId: 8, nombre: 'BETA SAC'));

      expect(env.navigation.pendingGestionCliente, isNull);
      expect(env.repo.fichaIds, [8]);
      expect(env.provider.tabs.index, 1);
      expect(find.text('Registrar nueva gestión'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Buscador de cliente', () {
    testWidgets('con menos de 2 letras no busca; con 2, tras 400 ms, trae los clientes (también los inactivos)', (tester) async {
      final env = await _pump(tester);

      await tester.enterText(find.byType(SearchBar), 'a');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Escribe al menos 2 letras para buscar.'), findsOneWidget);
      expect(env.repo.searches, isEmpty);

      await tester.enterText(find.byType(SearchBar), 'ac');
      await tester.pump(const Duration(milliseconds: 300));
      expect(env.repo.searches, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(env.repo.searches, ['ac']);
      expect(find.text('ACME SAC'), findsOneWidget);
      expect(find.text('20123456789 · C-001 · Lima'), findsOneWidget);
      expect(find.text('ACERO SUR'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      // No hay micrófono: la búsqueda por voz no va en este buscador.
      expect(find.byTooltip('Buscar por voz'), findsNothing);
    });

    testWidgets('elegir un cliente abre su ficha en Resumen y limpia la búsqueda', (tester) async {
      final env = await _pump(tester);
      await tester.enterText(find.byType(SearchBar), 'acme');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACME SAC'));
      await tester.pumpAndSettle();

      expect(env.repo.fichaIds, [7]);
      expect(env.provider.tabs.index, 0);
      expect(find.text('Información general'), findsOneWidget);
      expect(tester.widget<SearchBar>(find.byType(SearchBar)).controller?.text, isEmpty);
    });

    testWidgets('sin resultados y con error', (tester) async {
      final env = await _pump(tester, setUp: (repo) => repo.clientes = const []);
      await tester.enterText(find.byType(SearchBar), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      env.repo.searchFailure = const NetworkFailure('Sin conexión a internet');
      await tester.enterText(find.byType(SearchBar), 'zzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo buscar'), findsOneWidget);
      expect(find.text('Sin conexión a internet'), findsOneWidget);
    });

    testWidgets('"Tareas pendientes" cierra la ficha y vuelve a las tareas', (tester) async {
      final env = await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));
      expect(find.text('Registrar nueva gestión'), findsOneWidget);

      await tester.tap(find.text('Tareas pendientes'));
      await tester.pumpAndSettle();

      expect(find.text('Mis tareas pendientes (2)'), findsOneWidget);
      expect(env.provider.hasClient, isFalse);
      expect(env.provider.tabs.index, 0);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Ficha del cliente', () {
    testWidgets('la cabecera: nombre, estado, datos, contacto y la tarjeta de estado', (tester) async {
      await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();

      expect(find.text('ACME SAC'), findsWidgets);
      expect(find.text('Crítico'), findsWidgets);
      expect(find.text('C-001  |  RUC 20123456789  |  Mayorista  |  Lima'), findsOneWidget);
      // En la cabecera y en la información general del Resumen.
      expect(find.text('987 654 321'), findsNWidgets(2));
      expect(find.text('compras@acme.pe'), findsNWidgets(2));
      expect(find.text('Av. Principal 123'), findsNWidgets(2));
      expect(find.text('Algunos datos de contacto no se muestran con tu perfil.'), findsNothing);
      // Tarjeta de estado: lo que cayó contra el año anterior, con el rango.
      expect(find.text('71 % o más'), findsOneWidget);
      expect(find.text('-S/ 4,500'), findsOneWidget);
      expect(find.text('-45.0 % frente a 1 ene - 19 nov 2025'), findsOneWidget);
    });

    testWidgets('tocar el teléfono llama, el correo escribe y el WhatsApp abre el chat', (tester) async {
      await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));

      await tester.tap(find.text('987 654 321'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('compras@acme.pe'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Escribir por WhatsApp'));
      await tester.pumpAndSettle();

      expect(opened.map((u) => u.toString()), [
        'tel:987654321',
        'mailto:compras@acme.pe',
        'https://wa.me/51987654321',
      ]);
    });

    testWidgets('si no se pudo abrir la otra app lo avisa', (tester) async {
      ContactLauncher.open = (_) async => false;
      await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));

      await tester.tap(find.text('987 654 321'));
      await tester.pump();

      expect(find.text('No se pudo abrir el teléfono'), findsOneWidget);
    });

    testWidgets('teléfono y correo nulos no se ofrecen; con contacto oculto sale el aviso', (tester) async {
      await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaOf = (id) => _ficha(id, telefono: null, email: null, contactoOculto: true),
      );

      expect(find.text('987 654 321'), findsNothing);
      expect(find.text('compras@acme.pe'), findsNothing);
      expect(find.byTooltip('Escribir por WhatsApp'), findsNothing);
      expect(find.text('Algunos datos de contacto no se muestran con tu perfil.'), findsOneWidget);
    });

    testWidgets('un teléfono fijo no ofrece WhatsApp', (tester) async {
      await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaOf = (id) => _ficha(id, telefono: '(01) 234-5678'),
      );

      expect(find.text('(01) 234-5678'), findsOneWidget);
      expect(find.byTooltip('Escribir por WhatsApp'), findsNothing);
    });

    testWidgets('sin comparación: el año anterior no compró', (tester) async {
      await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaOf = (id) => _ficha(id, estado: GestionEstado.sinBase, caida: null),
      );

      expect(find.text('Sin comparación'), findsWidgets);
      expect(find.text('No compró del 1 ene - 19 nov 2025'), findsOneWidget);
    });

    testWidgets('el signo de interrogación explica cada estado', (tester) async {
      await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));

      await tester.tap(find.byTooltip('¿Qué significa cada estado?'));
      await tester.pumpAndSettle();

      expect(find.text('Se comparan las ventas de 2026 con el mismo periodo de 2025'), findsOneWidget);
      for (final texto in ['71 % o más', '26 % - 70 %', '11 % - 25 %', '0 % - 10 %', 'Sin base']) {
        expect(find.text(texto), findsWidgets);
      }
      expect(find.text('Caída severa o dejó de comprar.'), findsOneWidget);
    });

    testWidgets('Resumen: las cuatro tarjetas, la información general y las demás secciones', (tester) async {
      await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();

      expect(find.text('Sin comprar'), findsOneWidget);
      expect(find.text('12 días'), findsOneWidget);
      expect(find.textContaining('Última compra F001-1250 · S/ 1,234.50'), findsOneWidget);
      expect(find.text('S/ 5,500'), findsOneWidget);
      expect(find.text('1 ene - 19 nov 2025: S/ 10,000'), findsOneWidget);
      expect(find.text('N.º de compras'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('S/ 500.00'), findsOneWidget);
      // Información general.
      expect(find.text('Información general'), findsOneWidget);
      expect(find.text('Razón social'), findsOneWidget);
      expect(find.text('Ejecutivo comercial'), findsOneWidget);
      expect(find.text('Crédito 30 días'), findsOneWidget);
      expect(find.text('S/ 5,000'), findsOneWidget);
      expect(find.text('Activo · Crítico'), findsOneWidget);
      // Última gestión, próximo contacto, última compra y productos.
      expect(find.text('Última gestión'), findsOneWidget);
      expect(find.text('Próximo contacto'), findsOneWidget);
      expect(find.text('Programado'), findsOneWidget);
      expect(find.text('WhatsApp · Enviar cotización'), findsOneWidget);
      expect(find.text('Última compra'), findsOneWidget);
      expect(find.text('Principales productos (año actual)'), findsOneWidget);
      expect(find.textContaining('P-100'), findsOneWidget);
      expect(find.text('S/ 3,000 · 54.5 %'), findsOneWidget);
      // Las cuatro pestañas, en el orden de la web.
      final etiquetas = ['Resumen', 'Seguimiento', 'Compras', 'Documentos'];
      final izquierda = [
        for (final e in etiquetas) tester.getTopLeft(find.descendant(of: find.byType(AppTabBar), matching: find.text(e))).dx,
      ];
      expect(izquierda, orderedEquals([...izquierda]..sort()));
    });

    testWidgets('Resumen sin gestiones ofrece registrar la primera (solo con permiso de registrar)', (tester) async {
      await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) {
          repo.fichaOf = (id) => _ficha(id, conGestion: false);
          repo.historial = const GestionHistorial();
        },
      );
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay gestiones con este cliente'), findsOneWidget);
      expect(find.text('No hay un contacto programado.'), findsOneWidget);
      await tester.tap(find.text('Registrar la primera gestión'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar nueva gestión'), findsWidgets);
    });

    testWidgets('Resumen sin gestiones no ofrece registrar la primera sin permiso de registrar', (tester) async {
      await _pump(
        tester,
        permissions: _soloVer,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaOf = (id) => _ficha(id, conGestion: false),
      );
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar la primera gestión'), findsNothing);
    });

    testWidgets('un cliente ajeno a la cartera (403) muestra el mensaje del servidor y vuelve a las tareas', (tester) async {
      final env = await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaFailure = (_) => const ServerFailure('Este cliente no es de tu cartera'),
      );

      expect(find.text('No se puede mostrar este cliente'), findsOneWidget);
      expect(find.text('Este cliente no es de tu cartera'), findsOneWidget);
      expect(find.text('Resumen'), findsNothing);

      await tester.tap(find.text('Volver a las tareas'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas pendientes (2)'), findsOneWidget);
      expect(env.provider.hasClient, isFalse);
    });

    testWidgets('un fallo de conexión ofrece reintentar la ficha', (tester) async {
      final env = await _pump(
        tester,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.fichaFailure = (_) => const NetworkFailure('Sin conexión a internet'),
      );

      expect(find.text('No se pudo cargar la ficha'), findsOneWidget);
      expect(find.text('No se puede mostrar este cliente'), findsNothing);

      env.repo.fichaFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Resumen'), findsOneWidget);
      expect(find.text('Registrar nueva gestión'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Seguimiento: consulta', () {
    testWidgets('las cuatro tarjetas y el historial con cada gestión', (tester) async {
      await _pump(tester, permissions: _soloVer, pending: (clienteId: 7, nombre: 'ACME SAC'));

      expect(find.text('Último contacto'), findsOneWidget);
      expect(find.text('10 nov 2026'), findsWidgets);
      expect(find.text('hace 9 días • Llamada'), findsOneWidget);
      expect(find.text('Próxima gestión'), findsOneWidget);
      expect(find.text('22 nov 2026'), findsOneWidget);
      expect(find.text('10:00 a. m. · WhatsApp · Enviar cotización'), findsOneWidget);
      expect(find.text('Total de gestiones'), findsOneWidget);
      expect(find.text('desde 01 ene 2026'), findsOneWidget);
      // Debajo del resultado, cuándo se elige ese resultado.
      expect(find.text('Interesado en comprar, solicita cotización.'), findsOneWidget);

      expect(find.text('Historial de gestiones'), findsOneWidget);
      expect(find.text('Llamada · 10/11/2026 10:00 a. m.'), findsOneWidget);
      expect(find.text('Pidió cotización'), findsOneWidget);
      expect(find.text('Visita · 02/10/2026 03:00 p. m.'), findsOneWidget);
      expect(find.text('Por: FRANCIS B.'), findsNWidgets(2));
    });

    testWidgets('sin permiso de registrar: solo lectura, sin formulario, sin editar ni reprogramar', (tester) async {
      await _pump(tester, permissions: _soloVer, pending: (clienteId: 7, nombre: 'ACME SAC'));

      expect(find.text('Registrar nueva gestión'), findsOneWidget);
      expect(find.text('No tienes permiso para registrar gestiones.'), findsOneWidget);
      expect(find.text('Guardar gestión'), findsNothing);
      expect(find.text('Tipo de contacto'), findsNothing);
      expect(find.byTooltip('Acciones'), findsNothing);
    });

    testWidgets('tocar una gestión abre su detalle', (tester) async {
      await _pump(tester, permissions: _soloVer, pending: (clienteId: 7, nombre: 'ACME SAC'));

      await tester.tap(find.text('Pidió cotización'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle de la gestión'), findsOneWidget);
      expect(find.text('Registrado por'), findsOneWidget);
      expect(find.text('Tipo del próximo contacto'), findsOneWidget);
      expect(find.text('Próxima acción'), findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    });

    testWidgets('los filtros del historial: tipo, resultado y quitar filtros', (tester) async {
      // El catálogo trae los resultados del filtro.
      await _pump(tester, permissions: _soloVer, pending: (clienteId: 7, nombre: 'ACME SAC'));

      await _tapChip(tester, 'Visita');
      expect(find.text('Llamada · 10/11/2026 10:00 a. m.'), findsNothing);
      expect(find.text('Visita · 02/10/2026 03:00 p. m.'), findsOneWidget);

      await _tapChip(tester, 'Oportunidad');
      expect(find.text('No hay gestiones con esos filtros'), findsOneWidget);

      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Llamada · 10/11/2026 10:00 a. m.'), findsOneWidget);
      expect(find.text('Quitar filtros'), findsNothing);
    });

    testWidgets('un cliente sin gestiones lo dice y las tarjetas quedan en blanco', (tester) async {
      await _pump(
        tester,
        permissions: _soloVer,
        pending: (clienteId: 7, nombre: 'ACME SAC'),
        setUp: (repo) => repo.historial = const GestionHistorial(),
      );

      expect(find.text('Todavía no hay gestiones con este cliente'), findsOneWidget);
      expect(find.text('sin gestiones'), findsNWidgets(2));
      expect(find.text('sin contacto programado'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Seguimiento: registrar', () {
    Future<_Env> abrir(WidgetTester tester, {void Function(_FakeGestionRepository repo)? setUp}) =>
        _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'), setUp: setUp);

    Future<void> elegirResultado(WidgetTester tester, String etiqueta) async {
      await tester.tap(find.text('Selecciona el resultado'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(etiqueta)));
      await tester.pumpAndSettle();
    }

    testWidgets('el formulario: tipo Llamada por defecto, resultado obligatorio y botón deshabilitado hasta elegirlo', (tester) async {
      await abrir(tester);

      expect(find.text('Tipo de contacto'), findsOneWidget);
      for (final tipo in ['Llamada', 'WhatsApp', 'Visita', 'Correo']) {
        expect(find.descendant(of: find.byType(GestionTipoSelector), matching: find.text(tipo)), findsWidgets);
      }
      expect(find.text('¿Cuándo elegir cada uno?'), findsOneWidget);
      expect(find.text('Se registra la gestión de hoy.'), findsOneWidget);
      expect(find.text('Guardar gestión y programar'), findsNothing);
      final guardar = find.widgetWithText(FilledButton, 'Guardar gestión');
      expect(tester.widget<FilledButton>(guardar).onPressed, isNull);

      await elegirResultado(tester, 'Sin respuesta');
      // Debajo del campo se lee cuándo elegir ese resultado.
      expect(find.text('No contesta.'), findsOneWidget);
      expect(tester.widget<FilledButton>(guardar).onPressed, isNotNull);
    });

    testWidgets('la guía lista cuándo elegir cada resultado', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('¿Cuándo elegir cada uno?'));
      await tester.pumpAndSettle();

      expect(find.text('Resultados de una gestión'), findsOneWidget);
      expect(find.text('No contesta.'), findsOneWidget);
      expect(find.text('No está interesado, datos incorrectos, negocio cerrado.'), findsOneWidget);
    });

    testWidgets('guardar manda tipo, resultado y comentario, avisa, vacía el formulario y refresca', (tester) async {
      final env = await abrir(tester);
      await _tipo(tester, 'WhatsApp');
      await elegirResultado(tester, 'Con objeciones');
      await tester.enterText(find.widgetWithText(TextField, 'Comentario'), '  Dice que está caro  ');

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar gestión'));
      await tester.pumpAndSettle();

      final enviada = env.repo.registradas.single;
      expect(enviada.clienteId, 7);
      expect(enviada.gestion.tipo, GestionContacto.whatsapp);
      expect(enviada.gestion.resultado, 'con_objeciones');
      expect(enviada.gestion.comentario!.trim(), 'Dice que está caro');
      expect(enviada.gestion.proximo, isNull);
      expect(find.text('Gestión guardada'), findsOneWidget);
      // Refresca la ficha, el historial y las tareas.
      expect(env.repo.fichaIds, [7, 7]);
      expect(env.repo.historialCalls, 2);
      expect(env.repo.tareasCalls, 2);
      // El formulario queda como nuevo.
      expect(find.text('Selecciona el resultado'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Comentario')).controller?.text, isEmpty);
    });

    testWidgets('programar el siguiente contacto: el tipo sigue al de la gestión, la fecha es obligatoria y la hora es 10:00', (tester) async {
      final env = await abrir(tester);
      await _tipo(tester, 'Correo');
      await elegirResultado(tester, 'Seguimiento');

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Tipo de próximo contacto'), findsOneWidget);
      expect(find.text('10:00 a. m.'), findsOneWidget);
      final guardar = find.widgetWithText(FilledButton, 'Guardar gestión y programar');
      expect(tester.widget<FilledButton>(guardar).onPressed, isNull);

      await tester.tap(find.text('Elige la fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('25')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('25/11/2026'), findsOneWidget);
      expect(tester.widget<FilledButton>(guardar).onPressed, isNotNull);

      await tester.enterText(find.widgetWithText(TextField, '¿Qué harás en ese contacto? (opcional)'), 'Enviar cotización');
      await tester.tap(guardar);
      await tester.pumpAndSettle();

      final enviada = env.repo.registradas.single.gestion;
      expect(enviada.tipo, GestionContacto.correo);
      expect(enviada.proximo, DateTime(2026, 11, 25, 10));
      expect(enviada.proximoTipo, GestionContacto.correo);
      expect(enviada.proximaAccion, 'Enviar cotización');
      expect(find.text('Gestión guardada y seguimiento programado'), findsOneWidget);
    });

    testWidgets('el tipo del siguiente contacto se puede cambiar y la hora se elige con el reloj', (tester) async {
      final env = await abrir(tester);
      await elegirResultado(tester, 'Oportunidad');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      // Dentro del panel azul: los cuatro tipos; se elige Visita para el siguiente contacto.
      await tester.tap(find.descendant(of: find.byType(GestionProximoPanel), matching: find.text('Visita')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elige la fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10:00 a. m.'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar gestión y programar'));
      await tester.pumpAndSettle();

      final enviada = env.repo.registradas.single.gestion;
      expect(enviada.tipo, GestionContacto.llamada);
      expect(enviada.proximoTipo, GestionContacto.visita);
      expect(enviada.proximo, DateTime(2026, 11, 19, 10));
    });

    testWidgets('un error del servidor se muestra y no pierde lo escrito', (tester) async {
      final env = await abrir(tester);
      env.repo.writeFailure = const ValidationFailure('La fecha del siguiente contacto no puede ser de un día ya pasado');
      await elegirResultado(tester, 'Oportunidad');
      await tester.enterText(find.widgetWithText(TextField, 'Comentario'), 'Texto importante');

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar gestión'));
      await tester.pumpAndSettle();

      expect(find.text('La fecha del siguiente contacto no puede ser de un día ya pasado'), findsOneWidget);
      expect(find.text('Gestión guardada'), findsNothing);
      expect(find.text('Oportunidad'), findsWidgets);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Comentario')).controller?.text, 'Texto importante');

      // Corregido el problema se guarda de nuevo, y el mensaje desaparece.
      env.repo.writeFailure = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar gestión'));
      await tester.pumpAndSettle();
      expect(find.text('La fecha del siguiente contacto no puede ser de un día ya pasado'), findsNothing);
      expect(env.repo.registradas, hasLength(2));
    });

    testWidgets('un 403 de cartera ajena también se muestra', (tester) async {
      final env = await abrir(tester);
      env.repo.writeFailure = const ServerFailure('Este cliente no es de tu cartera');
      await elegirResultado(tester, 'Sin respuesta');

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar gestión'));
      await tester.pumpAndSettle();

      expect(find.text('Este cliente no es de tu cartera'), findsOneWidget);
    });

    testWidgets('el comentario admite hasta 500 letras y la acción 150', (tester) async {
      await abrir(tester);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Comentario')).maxLength, 500);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, '¿Qué harás en ese contacto? (opcional)')).maxLength,
        150,
      );
    });

    testWidgets('si los resultados no cargan se puede reintentar', (tester) async {
      final env = await abrir(tester, setUp: (repo) => repo.catalogoFailure = const NetworkFailure('Sin conexión a internet'));

      expect(find.textContaining('No se pudieron cargar los resultados'), findsOneWidget);

      env.repo.catalogoFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona el resultado'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Seguimiento: editar y reprogramar', () {
    Future<_Env> abrir(WidgetTester tester, {void Function(_FakeGestionRepository repo)? setUp}) =>
        _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'), setUp: setUp);

    /// El menú de la primera fila (la gestión programada) o de la segunda (la cumplida).
    Future<void> menu(WidgetTester tester, {int fila = 0}) async {
      await tester.tap(find.byTooltip('Acciones').at(fila));
      await tester.pumpAndSettle();
    }

    testWidgets('Editar sale en todas las gestiones y Reprogramar solo en la que quedó programada', (tester) async {
      await abrir(tester);

      await menu(tester);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Reprogramar'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await menu(tester, fila: 1);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Reprogramar'), findsNothing);
    });

    testWidgets('Editar la gestión: lo ya registrado, y guardar manda los cambios', (tester) async {
      final env = await abrir(tester);
      await menu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar la gestión'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Comentario').last).controller?.text, 'Pidió cotización');
      // El siguiente contacto ya estaba programado: el interruptor está prendido con su acción.
      expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);
      expect(find.text('22/11/2026'), findsWidgets);

      await tester.enterText(find.widgetWithText(TextField, 'Comentario').last, 'Cambió de idea');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final edicion = env.repo.editadas.single;
      expect(edicion.id, 11);
      expect(edicion.gestion.comentario, 'Cambió de idea');
      expect(edicion.gestion.cumplida, isFalse);
      expect(edicion.gestion.proximo, DateTime(2026, 11, 22, 10));
      expect(edicion.gestion.proximoTipo, GestionContacto.whatsapp);
      expect(edicion.gestion.proximaAccion, 'Enviar cotización');
      expect(find.text('Gestión actualizada'), findsOneWidget);
      expect(env.repo.fichaIds, [7, 7]);
    });

    testWidgets('apagar el interruptor quita el siguiente contacto', (tester) async {
      final env = await abrir(tester);
      await menu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(env.repo.editadas.single.gestion.proximo, isNull);
    });

    testWidgets('si el siguiente contacto ya se cumplió queda en solo lectura, salvo la acción', (tester) async {
      final env = await abrir(tester);
      await menu(tester, fila: 1);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Siguiente contacto (ya cumplido)'), findsOneWidget);
      expect(find.text('09/10/2026 · 10:00 a. m. · Llamada telefónica'), findsOneWidget);
      final ventana = find.byType(BottomSheet);
      expect(find.descendant(of: ventana, matching: find.byType(Switch)), findsNothing);
      expect(find.descendant(of: ventana, matching: find.text('¿Deseas programar un próximo seguimiento?')), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, '¿Qué se iba a hacer?'), 'Mandar catálogo');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final edicion = env.repo.editadas.single;
      expect(edicion.id, 10);
      expect(edicion.gestion.cumplida, isTrue);
      expect(edicion.gestion.proximaAccion, 'Mandar catálogo');
      expect(edicion.gestion.proximo, isNull);
    });

    testWidgets('el aviso aparece al programar en una gestión que no es la programada', (tester) async {
      await abrir(
        tester,
        setUp: (repo) {
          // La gestión de arriba no tiene siguiente contacto; la programada es otra.
          repo.historial = GestionHistorial(
            gestiones: [_registro(id: 12, fecha: DateTime(2026, 11, 18, 9)), _programada()],
            proxima: _programada(),
            totalAnio: 2,
          );
        },
      );
      await menu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ya tiene un contacto programado'), findsNothing);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'El cliente ya tiene un contacto programado para el 22/11/2026; al guardar, ese pasa a cumplido y queda este.',
        ),
        findsOneWidget,
      );
      // Sin fecha no se puede guardar.
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar cambios')).onPressed, isNull);
    });

    testWidgets('un error al editar deja la ventana abierta con el motivo', (tester) async {
      final env = await abrir(tester);
      env.repo.writeFailure = const ValidationFailure('No se pudo actualizar la gestión');
      await menu(tester);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Editar la gestión'), findsOneWidget);
      expect(find.text('No se pudo actualizar la gestión'), findsOneWidget);
      expect(find.text('Gestión actualizada'), findsNothing);
    });

    testWidgets('Reprogramar el siguiente contacto: nueva fecha y hora', (tester) async {
      final env = await abrir(tester);
      await menu(tester);
      await tester.tap(find.text('Reprogramar'));
      await tester.pumpAndSettle();

      expect(find.text('Reprogramar el siguiente contacto'), findsOneWidget);
      expect(find.text('22/11/2026'), findsWidgets);
      await tester.tap(find.widgetWithText(InkWell, '22/11/2026').last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('28')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(env.repo.reprogramadas.single.id, 11);
      expect(env.repo.reprogramadas.single.proximo, DateTime(2026, 11, 28, 10));
      expect(find.text('Seguimiento reprogramado'), findsOneWidget);
      expect(env.repo.fichaIds, [7, 7]);
    });

    testWidgets('si el contacto programado ya venció, hay que elegir una fecha nueva', (tester) async {
      await abrir(
        tester,
        setUp: (repo) {
          final vencida = _registro(
            proximo: DateTime(2026, 11, 12, 10),
            proximoTipo: GestionContacto.llamada,
            estado: GestionSeguimiento.programado,
            vencida: true,
          );
          repo.historial = GestionHistorial(gestiones: [vencida], proxima: vencida, totalAnio: 1);
        },
      );
      await menu(tester);
      await tester.tap(find.text('Reprogramar'));
      await tester.pumpAndSettle();

      expect(find.text('Elige la nueva fecha'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Compras y Documentos: modelo y datasource', () {
    test('las compras leen los gráficos (el acumulado se corta con null), las listas y los top 10', () {
      final compras = gestionComprasFromJson({
        'periodo': {
          'desde': '2026-01-01',
          'hasta': '2026-11-19',
          'etiqueta': '1 ene - 19 nov 2026',
          'etiqueta_anterior': '1 ene - 19 nov 2025',
          'ventas': 5500,
          'compras': 11,
          'ticket_promedio': 500,
          'ventas_anterior': 10000,
          'variacion': -4500,
          'caida_pct': 45,
        },
        'anio_actual': 2026,
        'anio_anterior': 2025,
        'anio_listas': 2025,
        'hasta': '19/11',
        'evolucion': [
          {'mes': 1, 'anterior': 100, 'actual': 50.5},
        ],
        'acumulado': [
          {'mes': 11, 'anterior': 9000, 'actual': 4000, 'corte': 'al 19 nov'},
          {'mes': 12, 'anterior': 10000, 'actual': null, 'corte': null},
        ],
        'ultimas_compras': [
          {'id': 5, 'fecha': '2026-11-07', 'documento': 'F001-1250', 'monto': 1234.5},
        ],
        'top_productos': [
          {'nombre': 'Cable UTP', 'codigo': 'P-100', 'monto': 3000, 'porcentaje': 54.5},
          {'nombre': 'Otros', 'codigo': null, 'monto': 2500, 'porcentaje': 45.5},
        ],
        'top_marcas': [],
        'top_categorias': [
          {'nombre': 'Cables', 'monto': 10, 'porcentaje': 100},
        ],
      });

      expect(compras.anioListas, 2025);
      expect(compras.hasta, '19/11');
      expect(compras.periodo.caidaPct, 45);
      expect(compras.evolucion.single.actual, 50.5);
      expect(compras.acumulado.last.actual, isNull);
      expect(compras.acumulado.first.corte, 'al 19 nov');
      expect(compras.ultimasCompras.single.fecha, DateTime(2026, 11, 7));
      expect(compras.topProductos.first.codigo, 'P-100');
      expect(compras.topProductos.last.esOtros, isTrue);
      expect(compras.topMarcas, isEmpty);
      expect(compras.topCategorias.single.codigo, isNull);
    });

    test('los documentos distinguen cotizaciones de ventas y leen el estado', () {
      final lista = gestionDocumentosFromJson({
        'success': true,
        'data': [
          {
            'clave': 'cotizacion-21',
            'id': 21,
            'tipo': 'cotizacion',
            'numero': 'C001-0021',
            'nro_documento': 21,
            'fecha': '2026-11-05',
            'monto': 800,
            'estado': 'Anulada',
            'ejecutivo': null,
            'almacen': 'Lima',
          },
          {'clave': 'venta-5', 'id': 5, 'tipo': 'boleta', 'numero': 'B001-00123', 'fecha': '2026-11-07', 'monto': 80.5, 'estado': 'Emitido'},
        ],
      });

      expect(lista.first.esCotizacion, isTrue);
      expect(lista.first.anulado, isTrue);
      expect(lista.first.ejecutivo, isNull);
      expect(lista.first.fecha, DateTime(2026, 11, 5));
      expect(lista.last.tipo, GestionDocumentoTipo.boleta);
      expect(lista.last.esCotizacion, isFalse);
      expect(lista.last.anulado, isFalse);
      expect(gestionDiaApi(DateTime(2026, 3, 4)), '2026-03-04');
    });

    test('compras pide el año solo si se eligió y documentos manda desde y hasta', () async {
      final requests = <http.Request>[];
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await ds.getCompras('tok', 7);
      await ds.getCompras('tok', 7, anio: 2025);
      await ds.getDocumentos('tok', 7, desde: DateTime(2026), hasta: DateTime(2026, 11, 19));

      expect(requests.map((r) => r.url.path), [
        '$_apiPath/seguimiento-clientes/7/compras',
        '$_apiPath/seguimiento-clientes/7/compras',
        '$_apiPath/seguimiento-clientes/7/documentos',
      ]);
      expect(requests[0].url.queryParameters, isEmpty);
      expect(requests[1].url.queryParameters, {'anio': '2025'});
      expect(requests[2].url.queryParameters, {'desde': '2026-01-01', 'hasta': '2026-11-19'});
      expect(requests.map((r) => r.headers['Authorization']), everyElement('Bearer tok'));
    });

    test('un 403 de compras o documentos llega con el mensaje del servidor', () async {
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient(
          (_) async => http.Response('{"success":false,"message":"Este cliente no es de tu cartera"}', 403),
        ),
      );

      await expectLater(
        ds.getCompras('t', 7),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Este cliente no es de tu cartera')),
      );
      await expectLater(
        ds.getDocumentos('t', 7, desde: DateTime(2026), hasta: DateTime(2026, 2)),
        throwsA(isA<ServerException>().having((e) => e.message, 'message', 'Este cliente no es de tu cartera')),
      );
    });

    test('una venta se pide por su id, suelta o dentro de data', () async {
      final paths = <String>[];
      var dentro = false;
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((r) async {
          paths.add(r.url.path);
          final venta = {'id': 5, 'nro_documento': 12, 'estado': 1};
          return http.Response(jsonEncode(dentro ? {'data': venta} : venta), 200);
        }),
      );

      final suelta = await ds.getVenta('t', 5);
      dentro = true;
      final envuelta = await ds.getVenta('t', 5);

      expect(paths, ['$_apiPath/ventas/5', '$_apiPath/ventas/5']);
      expect(suelta.id, 5);
      expect(suelta.kind, DocumentKind.venta);
      expect(envuelta.id, 5);
    });

    test('la cotización se busca por su número en la lista de la empresa y se toma la del id (no hay GET /cotizaciones/{id})', () async {
      late Uri uri;
      final ds = GestionRemoteDataSourceImpl(
        client: MockClient((r) async {
          uri = r.url;
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 121, 'nro_documento': 121},
                {'id': 21, 'nro_documento': 21},
              ],
            }),
            200,
          );
        }),
      );

      final cotizacion = await ds.getCotizacion('t', companyId: 3, id: 21, nroDocumento: 21);

      expect(uri.path, '$_apiPath/cotizaciones');
      expect(uri.queryParameters, {'company_id': '3', 'search_input': '21'});
      expect(cotizacion?.id, 21);
      expect(cotizacion?.kind, DocumentKind.cotizacion);

      final vacia = GestionRemoteDataSourceImpl(client: MockClient((_) async => http.Response('{"data":[]}', 200)));
      expect(await vacia.getCotizacion('t', companyId: 3, id: 21, nroDocumento: 21), isNull);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Compras y Documentos: provider', () {
    Future<(_FakeGestionRepository, GestionProvider)> abierto({Set<String> permissions = _verTodo}) async {
      final repo = _FakeGestionRepository();
      final provider = _provider(repo, session: _session(permissions: permissions));
      addTearDown(provider.dispose);
      await provider.openClient(7, 'ACME SAC');
      return (repo, provider);
    }

    test('las compras se piden una sola vez y el año elegido solo cambia las listas', () async {
      final (repo, provider) = await abierto();

      await provider.ensureCompras();
      await provider.ensureCompras();
      expect(repo.comprasAnios, [null]);
      expect(provider.compras?.anioListas, 2026);

      await provider.setAnioCompras(2025);
      expect(repo.comprasAnios, [null, 2025]);
      expect(provider.compras?.anioListas, 2025);
      expect(provider.anioCompras, 2025);
    });

    test('si falla al cambiar de año se queda con lo que se veía, en el año que se veía, y avisa', () async {
      final (repo, provider) = await abierto();
      await provider.loadCompras();

      repo.comprasFailure = const NetworkFailure('Sin conexión a internet');
      await provider.setAnioCompras(2025);

      expect(provider.compras?.anioListas, 2026);
      expect(provider.anioCompras, 2026);
      expect(provider.comprasError, 'Sin conexión a internet');
    });

    test('un fallo de la primera carga de compras deja el mensaje', () async {
      final (repo, provider) = await abierto();
      repo.comprasFailure = const ServerFailure('Este cliente no es de tu cartera');

      await provider.ensureCompras();

      expect(provider.compras, isNull);
      expect(provider.comprasError, 'Este cliente no es de tu cartera');
    });

    test('los documentos arrancan del 1 de enero a hoy; cambiar el rango vuelve a "Todos" y pide ese rango', () async {
      final (repo, provider) = await abierto();

      await provider.ensureDocumentos();
      expect(repo.documentosRangos.single, (desde: DateTime(2026), hasta: DateTime(2026, 11, 19)));
      provider.setVistaDocumentos('ventas');

      await provider.setRangoDocumentos(DateTimeRange(start: DateTime(2025), end: DateTime(2025, 12, 31)));

      expect(provider.vistaDocumentos, 'todos');
      expect(repo.documentosRangos.last, (desde: DateTime(2025), hasta: DateTime(2025, 12, 31)));
    });

    test('las vistas cuentan cotizaciones y ventas (factura, boleta y ticket) y filtran', () async {
      final (_, provider) = await abierto();
      await provider.ensureDocumentos();

      expect(provider.conteoDocumentos('todos'), 3);
      expect(provider.conteoDocumentos('cotizaciones'), 1);
      expect(provider.conteoDocumentos('ventas'), 2);
      provider.setVistaDocumentos('cotizaciones');
      expect(provider.documentosVisibles.map((d) => d.numero), ['C001-0021']);
      provider.setVistaDocumentos('ventas');
      expect(provider.documentosVisibles.map((d) => d.numero), ['F001-1250', 'V001-0012']);
    });

    test('un fallo de documentos deja el mensaje y reintentar lo trae', () async {
      final (repo, provider) = await abierto();
      repo.documentosFailure = const ServerFailure('Este cliente no es de tu cartera');

      await provider.ensureDocumentos();
      expect(provider.documentos, isNull);
      expect(provider.documentosError, 'Este cliente no es de tu cartera');

      repo.documentosFailure = null;
      await provider.loadDocumentos();
      expect(provider.documentos, hasLength(3));
      expect(provider.documentosError, isNull);
    });

    test('al abrir otro cliente se descartan sus compras, documentos, año y rango', () async {
      final (_, provider) = await abierto();
      await provider.setAnioCompras(2025);
      await provider.setRangoDocumentos(DateTimeRange(start: DateTime(2025), end: DateTime(2025, 12, 31)));

      await provider.openClient(8, 'BETA SAC');

      expect(provider.compras, isNull);
      expect(provider.anioCompras, isNull);
      expect(provider.documentos, isNull);
      expect(provider.rangoDocumentos.start, DateTime(2026));
    });

    test('abrir una venta pide /ventas/{id}; una cotización, con la empresa, el id y su número', () async {
      final (repo, provider) = await abierto();

      final venta = await provider.abrirDocumento(cotizacion: false, id: 5);
      final cotizacion = await provider.abrirDocumento(cotizacion: true, id: 21, nroDocumento: 21);

      expect(venta.right.kind, DocumentKind.venta);
      expect(cotizacion.right.kind, DocumentKind.cotizacion);
      expect(repo.ventasAbiertas, [5]);
      expect(repo.cotizacionesAbiertas.single, (companyId: 1, id: 21, nroDocumento: 21));
      expect(provider.abriendoDocumento, isFalse);
    });

    test('si no se pudo abrir devuelve el motivo del servidor', () async {
      final (repo, provider) = await abierto();
      repo.abrirFailure = const ServerFailure('Este cliente no es de tu cartera');

      final result = await provider.abrirDocumento(cotizacion: false, id: 5);

      expect(result.left.message, 'Este cliente no es de tu cartera');
      expect(provider.abriendoDocumento, isFalse);
    });

    test('también con solo ver: las pestañas Compras y Documentos no piden registrar', () async {
      final (_, provider) = await abierto(permissions: _soloVer);

      await provider.ensureCompras();
      await provider.ensureDocumentos();

      expect(provider.compras, isNotNull);
      expect(provider.documentos, hasLength(3));
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Pestaña Compras', () {
    Future<_Env> abrir(WidgetTester tester, {void Function(_FakeGestionRepository repo)? setUp, Set<String> permissions = _verTodo}) =>
        _pump(
          tester,
          permissions: permissions,
          pending: (clienteId: 7, nombre: 'ACME SAC'),
          pestana: GestionPestana.compras,
          setUp: setUp,
        );

    testWidgets('un pedido con la pestaña abre la ficha directo en Compras y las pide una vez', (tester) async {
      final env = await abrir(tester);

      expect(env.provider.tabs.index, 2);
      expect(env.repo.comprasAnios, [null]);
      expect(env.repo.documentosRangos, isEmpty);
    });

    testWidgets('las cuatro tarjetas del periodo', (tester) async {
      await abrir(tester);

      expect(find.text('Ventas 2025'), findsOneWidget);
      expect(find.text('Ventas 2026'), findsOneWidget);
      expect(find.text('01/01 - 19/11'), findsNWidgets(3));
      expect(find.text('S/ 10,000'), findsOneWidget);
      expect(find.text('S/ 5,500'), findsOneWidget);
      expect(find.text('mismo tramo del año anterior'), findsOneWidget);
      expect(find.text('del 1 de enero a hoy'), findsOneWidget);
      expect(find.text('N.º de compras'), findsOneWidget);
      expect(find.text('ticket promedio S/ 500.00'), findsOneWidget);
      expect(find.text('Contra el año anterior'), findsOneWidget);
      expect(find.text('-45.0 %'), findsOneWidget);
      expect(find.text('antes: S/ 10,000'), findsOneWidget);
    });

    testWidgets('si el año anterior no compró, la variación no se compara', (tester) async {
      await abrir(tester, setUp: (repo) => repo.comprasCaida = null);

      expect(find.text('—'), findsOneWidget);
      expect(find.text('no compró entonces'), findsOneWidget);
    });

    testWidgets('si vendió más que el año anterior, la variación sale con +', (tester) async {
      await abrir(tester, setUp: (repo) => repo.comprasCaida = -12.5);

      expect(find.text('+12.5 %'), findsOneWidget);
    });

    testWidgets('los dos gráficos, con los dos años y el día hasta el que se suma el año anterior', (tester) async {
      await abrir(tester);

      expect(find.text('Evolución de compras'), findsOneWidget);
      expect(find.text('Ventas al 19/11 | 2025 vs. 2026'), findsOneWidget);
      expect(find.text('Ventas acumulada al 19/11 | 2025 vs. 2026'), findsOneWidget);
      expect(find.byType(AppGroupedBarChart), findsOneWidget);
      expect(find.byType(AppAreaChart), findsOneWidget);
      final barras = tester.widget<AppGroupedBarChart>(find.byType(AppGroupedBarChart));
      expect(barras.labels.first, 'ENE');
      expect(barras.labels, hasLength(12));
      expect(barras.previous[1], 200);
      // El año actual todavía no tiene el último mes: la línea se corta, no cae a cero.
      final area = tester.widget<AppAreaChart>(find.byType(AppAreaChart));
      expect(area.series.first.values, hasLength(12));
      expect(area.series.last.values, hasLength(11));
      expect(find.text('2025 se suma al 19 nov, el mismo día que 2026.'), findsOneWidget);
    });

    testWidgets('las últimas compras y los top 10 del año, con "Otros", el % y el código del producto', (tester) async {
      await abrir(tester);

      expect(find.text('Últimas compras'), findsOneWidget);
      expect(find.text('solo 2026'), findsOneWidget);
      expect(find.text('F001-1250'), findsOneWidget);
      expect(find.text('S/ 1,234.50'), findsOneWidget);
      expect(find.text('07 nov 2026'), findsOneWidget);
      expect(find.text('B001-00123'), findsOneWidget);

      expect(find.text('Top 10 productos 2026'), findsOneWidget);
      expect(find.textContaining('P-100'), findsOneWidget);
      expect(find.text('54.5 %'), findsOneWidget);
      // Menos de 0.1 % se escribe "<0.1".
      expect(find.text('<0.1 %'), findsOneWidget);
      expect(find.text('Otros'), findsOneWidget);
      expect(find.text('Top 10 marcas 2026'), findsOneWidget);
      expect(find.text('Marca X'), findsOneWidget);
      expect(find.text('Top 10 categorías 2026'), findsOneWidget);
      expect(find.text('Sin compras en 2026'), findsOneWidget);
    });

    testWidgets('elegir el año anterior vuelve a pedir las listas de ese año', (tester) async {
      final env = await abrir(tester);

      await tester.tap(find.descendant(of: find.byType(SegmentedButton<int>), matching: find.text('2025')));
      await tester.pumpAndSettle();

      expect(env.repo.comprasAnios, [null, 2025]);
      expect(find.text('solo 2025'), findsOneWidget);
      expect(find.text('Top 10 productos 2025'), findsOneWidget);
      expect(find.text('Sin compras en 2025'), findsOneWidget);
    });

    testWidgets('tocar una compra abre su comprobante', (tester) async {
      final env = await abrir(tester);

      await tester.tap(find.text('F001-1250'));
      await tester.pumpAndSettle();

      expect(env.repo.ventasAbiertas, [5]);
      expect(receipts.single.id, 5);
      expect(receipts.single.kind, DocumentKind.venta);
    });

    testWidgets('si no se puede abrir el comprobante lo dice y no abre nada', (tester) async {
      await abrir(tester, setUp: (repo) => repo.abrirFailure = const ServerFailure('No tienes permiso para esta acción'));

      await tester.tap(find.text('F001-1250'));
      await tester.pumpAndSettle();

      expect(find.text('No tienes permiso para esta acción'), findsOneWidget);
      expect(receipts, isEmpty);
    });

    testWidgets('un cliente ajeno a la cartera (403) muestra el mensaje y se puede reintentar', (tester) async {
      final env = await abrir(tester, setUp: (repo) => repo.comprasFailure = const ServerFailure('Este cliente no es de tu cartera'));

      expect(find.text('Este cliente no es de tu cartera'), findsOneWidget);
      expect(find.text('Evolución de compras'), findsNothing);

      env.repo.comprasFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Evolución de compras'), findsOneWidget);
    });

    testWidgets('con solo ver también se ven las compras', (tester) async {
      await abrir(tester, permissions: _soloVer);

      expect(find.text('Evolución de compras'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Pestaña Documentos', () {
    Future<_Env> abrir(WidgetTester tester, {void Function(_FakeGestionRepository repo)? setUp, Set<String> permissions = _verTodo}) =>
        _pump(
          tester,
          permissions: permissions,
          pending: (clienteId: 7, nombre: 'ACME SAC'),
          pestana: GestionPestana.documentos,
          setUp: setUp,
        );

    testWidgets('Todos, Cotizaciones y Ventas con sus conteos, y cada documento con sus datos', (tester) async {
      final env = await abrir(tester);

      expect(env.provider.tabs.index, 3);
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Cotizaciones (1)'), findsOneWidget);
      expect(find.text('Ventas (2)'), findsOneWidget);
      expect(find.text('01/01/2026 – 19/11/2026'), findsOneWidget);
      expect(find.text('C001-0021'), findsOneWidget);
      expect(find.text('F001-1250'), findsOneWidget);
      expect(find.text('V001-0012'), findsOneWidget);
      expect(find.text('Ejecutivo: FRANCIS BULNES GONZALES'), findsNWidgets(2));
      expect(find.text('Lima'), findsNWidgets(2));
      expect(find.text('S/ 800.00'), findsOneWidget);
      expect(find.text('05/11/2026'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Emitido'), findsOneWidget);
      expect(find.text('Anulado'), findsOneWidget);
      expect(find.text('3 documentos'), findsOneWidget);
      expect(env.repo.comprasAnios, isEmpty);
    });

    testWidgets('el documento anulado va en rojo y los demás no', (tester) async {
      await abrir(tester);

      GestionDocumentoLink link(String numero) =>
          tester.widget<GestionDocumentoLink>(find.widgetWithText(GestionDocumentoLink, numero));
      expect(link('V001-0012').anulado, isTrue);
      expect(link('F001-1250').anulado, isFalse);
      expect(link('C001-0021').anulado, isFalse);
    });

    testWidgets('las vistas filtran la lista', (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Cotizaciones (1)'));
      await tester.pumpAndSettle();
      expect(find.text('C001-0021'), findsOneWidget);
      expect(find.text('F001-1250'), findsNothing);
      expect(find.text('1 documentos'), findsOneWidget);

      await _tapChip(tester, 'Ventas (2)');
      await tester.pumpAndSettle();
      expect(find.text('C001-0021'), findsNothing);
      expect(find.text('V001-0012'), findsOneWidget);
    });

    testWidgets('tocar una venta abre su comprobante por su id', (tester) async {
      final env = await abrir(tester);

      await tester.tap(find.text('F001-1250'));
      await tester.pumpAndSettle();

      expect(env.repo.ventasAbiertas, [5]);
      expect(env.repo.cotizacionesAbiertas, isEmpty);
      expect(receipts.single.kind, DocumentKind.venta);
    });

    testWidgets('tocar una cotización abre su comprobante buscándola en la empresa', (tester) async {
      final env = await abrir(tester);

      await tester.tap(find.text('C001-0021'));
      await tester.pumpAndSettle();

      expect(env.repo.cotizacionesAbiertas.single, (companyId: 1, id: 21, nroDocumento: 21));
      expect(env.repo.ventasAbiertas, isEmpty);
      expect(receipts.single.kind, DocumentKind.cotizacion);
    });

    testWidgets('si la cotización no se encuentra lo dice', (tester) async {
      await abrir(tester, setUp: (repo) => repo.abrirFailure = const ServerFailure('No se encontró la cotización'));

      await tester.tap(find.text('C001-0021'));
      await tester.pumpAndSettle();

      expect(find.text('No se encontró la cotización'), findsOneWidget);
      expect(receipts, isEmpty);
    });

    testWidgets('un atajo de fechas pide ese rango y vuelve a Todos', (tester) async {
      final env = await abrir(tester);
      await _tapChip(tester, 'Ventas (2)');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Año pasado'));
      await tester.pumpAndSettle();

      expect(env.repo.documentosRangos.last, (desde: DateTime(2025), hasta: DateTime(2025, 12, 31)));
      expect(find.text('01/01/2025 – 31/12/2025'), findsOneWidget);
      expect(env.provider.vistaDocumentos, 'todos');
    });

    testWidgets('se elige el rango con el selector de fechas', (tester) async {
      final env = await abrir(tester);

      await tester.tap(find.text('01/01/2026 – 19/11/2026'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(env.repo.documentosRangos, hasLength(2));
    });

    testWidgets('sin documentos en el rango lo dice', (tester) async {
      await abrir(tester, setUp: (repo) => repo.documentos = const []);

      expect(find.text('No hay documentos en este rango de fechas'), findsOneWidget);
      expect(find.text('Todos (0)'), findsOneWidget);
    });

    testWidgets('un cliente ajeno a la cartera (403) muestra el mensaje y se puede reintentar', (tester) async {
      final env = await abrir(tester, setUp: (repo) => repo.documentosFailure = const ServerFailure('Este cliente no es de tu cartera'));

      expect(find.text('Este cliente no es de tu cartera'), findsOneWidget);

      env.repo.documentosFailure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('C001-0021'), findsOneWidget);
    });

    testWidgets('con solo ver también se ven los documentos', (tester) async {
      await abrir(tester, permissions: _soloVer);

      expect(find.text('Todos (3)'), findsOneWidget);
    });

    testWidgets('cambiar de pestaña con el tab bar pide cada una al abrirla', (tester) async {
      final env = await _pump(tester, pending: (clienteId: 7, nombre: 'ACME SAC'));
      expect(env.repo.comprasAnios, isEmpty);

      await _tapTab(tester, 'Compras');
      await tester.pumpAndSettle();
      expect(env.repo.comprasAnios, [null]);
      expect(find.text('Evolución de compras'), findsOneWidget);

      await _tapTab(tester, 'Documentos');
      await tester.pumpAndSettle();
      expect(env.repo.documentosRangos, hasLength(1));
      expect(find.text('Evolución de compras'), findsNothing);

      // Volver a Compras no la pide otra vez: lo traído queda.
      await _tapTab(tester, 'Compras');
      await tester.pumpAndSettle();
      expect(env.repo.comprasAnios, [null]);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Inicio', () {
    testWidgets('tocar una tarea del Inicio abre la ficha de ese cliente en Gestión', (tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <TaskEntity>[];
      final data = executiveSummaryFromJson({
        'tareas': [
          {
            'id': 1,
            'cliente_id': 7,
            'cliente': 'ACME SAC',
            'tipo': 'llamada',
            'tipo_etiqueta': 'Llamada telefónica',
            'fecha': '2026-11-19 15:00:00',
            'vencida': false,
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InicioExecutiveView(data: data, now: _now, onOpenTask: opened.add),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Llamar – ACME SAC'));

      expect(opened.single.clienteId, 7);
    });

    test('pedir un cliente deja el pedido pendiente, pide el módulo gestion y atenderlo lo limpia', () {
      final nav = ShellNavigation();
      var avisos = 0;
      nav.addListener(() => avisos++);

      nav.goToGestionCliente(7, 'ACME SAC');

      expect(nav.requested, 'gestion');
      expect(nav.pendingGestionCliente, (clienteId: 7, nombre: 'ACME SAC', pestana: GestionPestana.seguimiento));
      expect(avisos, 1);
      expect(nav.takePendingGestionCliente(), (clienteId: 7, nombre: 'ACME SAC', pestana: GestionPestana.seguimiento));
      expect(nav.pendingGestionCliente, isNull);
      expect(nav.takePendingGestionCliente(), isNull);
    });

    test('el pedido admite la pestaña, como el ?pestana= de la web, y una clave desconocida cae en Resumen', () {
      final nav = ShellNavigation()..goToGestionCliente(7, 'ACME SAC', pestana: GestionPestana.documentos);

      expect(nav.pendingGestionCliente?.pestana, GestionPestana.documentos);
      expect(GestionPestana.fromKey('compras'), GestionPestana.compras);
      expect(GestionPestana.fromKey('otra'), GestionPestana.resumen);
      expect(GestionPestana.values.map((p) => p.key), ['resumen', 'seguimiento', 'compras', 'documentos']);
    });
  });

  // -------------------------------------------------------------------------------------------
  group('Modo oscuro, letra grande y 320 px', () {
    for (final look in screenLooks) {
      testWidgets('tareas pendientes del equipo: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, look: look, setUp: (repo) => repo.equipo = true);

        expect(find.text('Tareas pendientes del equipo (2)'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('ficha, pestaña Resumen: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, look: look.tall(4200), pending: (clienteId: 7, nombre: 'ACME SAC'));
        await tester.tap(find.text('Resumen'));
        await tester.pumpAndSettle();

        expect(find.text('Principales productos (año actual)'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('ficha, pestaña Seguimiento con el formulario: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, look: look.tall(4200), pending: (clienteId: 7, nombre: 'ACME SAC'));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.text('Guardar gestión y programar'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('ficha, pestaña Compras: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          look: look.tall(6000),
          pending: (clienteId: 7, nombre: 'ACME SAC'),
          pestana: GestionPestana.compras,
        );

        expect(find.text('Top 10 categorías 2026'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('ficha, pestaña Documentos: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          look: look.tall(4200),
          pending: (clienteId: 7, nombre: 'ACME SAC'),
          pestana: GestionPestana.documentos,
        );

        expect(find.text('3 documentos'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });

      testWidgets('ficha, Seguimiento en solo lectura: ${look.label}', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, look: look.tall(3600), permissions: _soloVer, pending: (clienteId: 7, nombre: 'ACME SAC'));

        expect(find.text('No tienes permiso para registrar gestiones.'), findsOneWidget);
        await expectLooksRight(tester, look);
        handle.dispose();
      });
    }

    testWidgets('en tablet la ficha se centra y no se estira', (tester) async {
      await _pump(tester, size: const Size(1100, 2600), pending: (clienteId: 7, nombre: 'ACME SAC'));

      final ancho = tester.getSize(find.byType(ListView).last).width;
      expect(ancho, lessThanOrEqualTo(760));
      expect(tester.takeException(), isNull);
    });
  });
}
