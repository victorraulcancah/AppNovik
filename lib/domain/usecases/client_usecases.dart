import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/client_form_entity.dart';
import '../entities/sale_entity.dart';
import '../repositories/client_repository.dart';

class GetDepartmentsUseCase {
  final ClientRepository repository;
  GetDepartmentsUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call() => repository.getDepartments();
}

class GetProvincesUseCase {
  final ClientRepository repository;
  GetProvincesUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call(String departmentId) =>
      repository.getProvinces(departmentId);
}

class GetDistrictsUseCase {
  final ClientRepository repository;
  GetDistrictsUseCase({required this.repository});

  Future<Either<Failure, List<UbigeoItemEntity>>> call(String provinceId) =>
      repository.getDistricts(provinceId);
}

/// Consulta un DNI (8 dígitos) o un RUC (11 dígitos).
class LookupDocumentUseCase {
  final ClientRepository repository;
  LookupDocumentUseCase({required this.repository});

  Future<Either<Failure, DocumentLookupEntity>> call({
    required String tipo,
    required String number,
  }) {
    final text = number.trim();
    final esEmpresa = tipo == 'e';
    final length = esEmpresa ? 11 : 8;
    if (!RegExp(r'^\d+$').hasMatch(text) || text.length != length) {
      return Future.value(Either.left(
        ValidationFailure(esEmpresa ? 'El RUC debe tener 11 dígitos' : 'El DNI debe tener 8 dígitos'),
      ));
    }
    return repository.lookupDocument(tipo: tipo, number: text);
  }
}

/// Crea un cliente con las mismas exigencias de la web al crear: documento, nombre (o razón
/// social en empresas), teléfono, correo y distrito.
class CreateClientUseCase {
  final ClientRepository repository;
  CreateClientUseCase({required this.repository});

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Teléfono en formato internacional como lo guarda la web: `+51987654321`. Un número de
  /// 9 dígitos se toma como peruano.
  static String normalizePhone(String raw) {
    final text = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (text.startsWith('+')) return text;
    if (RegExp(r'^\d{9}$').hasMatch(text)) return '+51$text';
    return text;
  }

  /// Mensaje del primer problema, o `null` si se puede crear.
  static String? validate(NewClientFormEntity f) {
    final doc = f.dniRuc.trim();
    if (doc.isEmpty) return f.esEmpresa ? 'El RUC es obligatorio' : 'El DNI es obligatorio';
    if (!RegExp(r'^\d+$').hasMatch(doc) || doc.length != (f.esEmpresa ? 11 : 8)) {
      return f.esEmpresa ? 'El RUC debe tener 11 dígitos' : 'El DNI debe tener 8 dígitos';
    }
    if (f.esEmpresa && (f.razonSocial ?? '').trim().isEmpty) return 'La razón social es obligatoria';
    if (f.name.trim().isEmpty) {
      return f.esEmpresa ? 'El nombre del contacto es obligatorio' : 'El nombre es obligatorio';
    }
    if (f.telefono.trim().isEmpty) return 'El teléfono es obligatorio';
    if (f.email.trim().isEmpty) return 'El correo es obligatorio';
    if (!_email.hasMatch(f.email.trim())) return 'Debe ser un correo válido';
    if (f.departmentId.isEmpty || f.provinceId.isEmpty || f.districtId.isEmpty) {
      return 'Elige el departamento, la provincia y el distrito';
    }
    return null;
  }

  Future<Either<Failure, ClientEntity>> call({
    required int companyId,
    int? executiveId,
    required NewClientFormEntity form,
  }) {
    final problem = validate(form);
    if (problem != null) return Future.value(Either.left(ValidationFailure(problem)));

    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    final normalized = NewClientFormEntity(
      tipo: form.tipo,
      dniRuc: form.dniRuc.trim(),
      name: form.name.trim(),
      lastName: clean(form.lastName),
      razonSocial: form.esEmpresa ? clean(form.razonSocial) : null,
      telefono: normalizePhone(form.telefono),
      email: form.email.trim(),
      departmentId: form.departmentId,
      provinceId: form.provinceId,
      districtId: form.districtId,
      calle: clean(form.calle),
      direccion: clean(form.direccion),
    );
    return repository.createClient(
      companyId: companyId,
      executiveId: executiveId,
      form: normalized,
    );
  }
}
