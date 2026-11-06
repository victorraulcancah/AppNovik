import 'dart:typed_data';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_record_entity.dart';
import '../repositories/client_record_repository.dart';
import 'client_usecases.dart' show CreateClientUseCase;

class GetClientsUseCase {
  final ClientRecordRepository repository;
  GetClientsUseCase({required this.repository});

  Future<Either<Failure, ClientPageEntity>> call({
    required int companyId,
    required int page,
    required int pageSize,
    required ClientFiltersEntity filters,
  }) =>
      repository.getClients(companyId: companyId, page: page, pageSize: pageSize, filters: filters);
}

class GetClientFilterCatalogsUseCase {
  final ClientRecordRepository repository;
  GetClientFilterCatalogsUseCase({required this.repository});

  Future<Either<Failure, ClientFilterCatalogsEntity>> call() => repository.getFilterCatalogs();
}

class GetClientFormCatalogsUseCase {
  final ClientRecordRepository repository;
  GetClientFormCatalogsUseCase({required this.repository});

  Future<Either<Failure, ClientFormCatalogsEntity>> call({required int companyId}) =>
      repository.getFormCatalogs(companyId: companyId);
}

class ExportClientsUseCase {
  final ClientRecordRepository repository;
  ExportClientsUseCase({required this.repository});

  Future<Either<Failure, Uint8List>> call({
    required int companyId,
    required ClientFiltersEntity filters,
  }) =>
      repository.exportClients(companyId: companyId, filters: filters);
}

/// Crea o edita un cliente con las mismas exigencias de la web: al crear piden documento, nombre
/// (razón social en empresas), teléfono, correo y distrito, y cada dirección o contacto agregado
/// lleva sus datos; al editar no se bloquea por campos que quedaron vacíos de antes.
class SaveClientUseCase {
  final ClientRecordRepository repository;
  SaveClientUseCase({required this.repository});

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _url = RegExp(r'^https?://[^\s/$.?#].[^\s]*$', caseSensitive: false);

  /// Mensaje del primer problema, o `null` si se puede guardar. [originalEmail] es el correo que el
  /// cliente ya tenía: al editar no se exige el formato si no se tocó.
  static String? validate(ClientFormEntity f, {required bool editing, String? originalEmail}) {
    if (f.incluyeBasica) {
      final doc = f.dniRuc.trim();
      if (!editing || doc.isNotEmpty) {
        if (doc.isEmpty) return f.esEmpresa ? 'El RUC es obligatorio' : 'El DNI es obligatorio';
        if (!RegExp(r'^\d+$').hasMatch(doc) || doc.length != (f.esEmpresa ? 11 : 8)) {
          return f.esEmpresa ? 'El RUC debe tener 11 dígitos' : 'El DNI debe tener 8 dígitos';
        }
      }
      if (!editing) {
        if (f.esEmpresa && (f.razonSocial ?? '').trim().isEmpty) return 'La razón social es obligatoria';
        if (f.name.trim().isEmpty) {
          return f.esEmpresa ? 'El nombre del contacto es obligatorio' : 'El nombre es obligatorio';
        }
        if (f.telefono.trim().isEmpty) return 'El teléfono es obligatorio';
        if (f.email.trim().isEmpty) return 'El correo es obligatorio';
        if (f.departmentId.isEmpty || f.provinceId.isEmpty || f.districtId.isEmpty) {
          return 'Elige el departamento, la provincia y el distrito';
        }
      }
      final email = f.email.trim();
      if (email.isNotEmpty && !(editing && email == originalEmail) && !_email.hasMatch(email)) {
        return 'Debe ser un correo válido';
      }
      for (final url in [f.redes, f.pagina2, f.pagina3]) {
        final text = (url ?? '').trim();
        if (text.isNotEmpty && !_url.hasMatch(text)) return 'Ingresa una URL válida (con http:// o https://)';
      }
    }

    if (f.incluyeCondiciones && f.credito != null && f.credito! < 0) {
      return 'La línea de crédito no puede ser negativa';
    }

    final addresses = f.addresses;
    if (addresses != null && !editing) {
      for (final a in addresses) {
        if (a.direccion.trim().isEmpty) return 'Escribe la dirección de cada dirección agregada';
        if ((a.departmentId ?? '').isEmpty || (a.provinceId ?? '').isEmpty || (a.districtId ?? '').isEmpty) {
          return 'Elige el departamento, la provincia y el distrito de cada dirección agregada';
        }
      }
    }
    final contacts = f.contacts;
    if (contacts != null) {
      for (final c in contacts) {
        if (!editing && c.name.trim().isEmpty) return 'Escribe el nombre de cada contacto agregado';
        final email = (c.email ?? '').trim();
        if (email.isNotEmpty && !_email.hasMatch(email)) return 'El correo del contacto no es válido';
      }
    }
    return null;
  }

  Future<Either<Failure, ClientRecordEntity>> call({
    required int companyId,
    required ClientFormEntity form,
    int? id,
    String? originalEmail,
  }) {
    final editing = id != null;
    final problem = validate(form, editing: editing, originalEmail: originalEmail);
    if (problem != null) return Future.value(Either.left(ValidationFailure(problem)));

    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    final normalized = ClientFormEntity(
      tipo: form.tipo,
      dniRuc: form.dniRuc.trim(),
      name: form.name.trim(),
      lastName: clean(form.lastName),
      razonSocial: form.esEmpresa ? clean(form.razonSocial) : null,
      telefono: form.telefono.trim().isEmpty ? '' : CreateClientUseCase.normalizePhone(form.telefono),
      email: form.email.trim(),
      giro: clean(form.giro),
      extranjero: form.extranjero,
      estado: form.estado,
      departmentId: form.departmentId,
      provinceId: form.provinceId,
      districtId: form.districtId,
      calle: clean(form.calle),
      direccion: clean(form.direccion),
      lote: clean(form.lote),
      indicaciones: clean(form.indicaciones),
      ejecutivoId: form.ejecutivoId,
      redes: clean(form.redes),
      pagina2: clean(form.pagina2),
      pagina3: clean(form.pagina3),
      cumple: clean(form.cumple),
      nota: clean(form.nota),
      incluyeCondiciones: form.incluyeCondiciones,
      listPriceId: form.listPriceId,
      paymentMethodId: form.paymentMethodId,
      credito: form.credito,
      addresses: form.addresses,
      contacts: form.contacts,
      incluyeBasica: form.incluyeBasica,
    );
    return repository.saveClient(companyId: companyId, form: normalized, id: id);
  }
}

class GetClientCategoriesUseCase {
  final ClientRecordRepository repository;
  GetClientCategoriesUseCase({required this.repository});

  Future<Either<Failure, CategoriesConfigEntity>> call() => repository.getCategories();
}

/// Guarda la configuración de categorías, o además las calcula ya ([calculate]). Como en la web,
/// el ciclo elegido necesita al menos un "Desde" para tener con qué calcular.
class SaveClientCategoriesUseCase {
  final ClientRecordRepository repository;
  SaveClientCategoriesUseCase({required this.repository});

  static String? validate(List<ClientCategoryEntity> categorias, String ciclo) {
    if (categorias.any((c) => c.rangoDe(ciclo).desde != null)) return null;
    return 'Llena los rangos del ciclo ${categoryCycleName(ciclo)} antes de guardar o calcular';
  }

  /// Devuelve el recálculo si se hizo (al cambiar el ciclo, o al pedir [calculate]).
  Future<Either<Failure, CategoryCalcEntity?>> call({
    required List<ClientCategoryEntity> categorias,
    required String ciclo,
    bool calculate = false,
  }) async {
    final problem = validate(categorias, ciclo);
    if (problem != null) return Either.left(ValidationFailure(problem));

    // Primero se guardan los rangos de cada ciclo: el cálculo usa los guardados.
    final saved = await repository.saveCategories(categorias: categorias, ciclo: ciclo);
    if (saved.isLeft || !calculate) return saved;

    final calc = await repository.calculateCategories(ciclo: ciclo);
    return calc.isLeft ? Either.left(calc.left) : Either.right(calc.right);
  }
}

String categoryCycleName(String ciclo) => switch (ciclo) {
      'mensual' => 'Mensual',
      'trimestral' => 'Trimestral',
      'cuatrimestral' => 'Cuatrimestral',
      'anual' => 'Anual',
      _ => ciclo,
    };
