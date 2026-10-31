import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/guide_form_entity.dart';
import '../entities/other_document_entity.dart';
import '../repositories/guide_repository.dart';

class GetGuideDefaultsUseCase {
  final GuideRepository repository;
  GetGuideDefaultsUseCase({required this.repository});

  Future<Either<Failure, GuideDefaultsEntity>> call(int saleId) => repository.getDefaults(saleId);
}

class FindDriverUseCase {
  final GuideRepository repository;
  FindDriverUseCase({required this.repository});

  Future<Either<Failure, DriverEntity?>> call(String dni) {
    final clean = dni.replaceAll('-', '');
    if (clean.length != 8) return Future.value(Either.right(null));
    return repository.findDriver(clean);
  }
}

/// Crea una guía de remisión. Valida lo que la web y el backend exigen antes de llamar a la API.
class CreateGuideUseCase {
  final GuideRepository repository;
  CreateGuideUseCase({required this.repository});

  /// Mensaje del primer problema de [f], o `null` si se puede enviar.
  static String? validate(GuideFormEntity f) {
    if (f.boletaId == null && f.saleId == null) return 'Debe seleccionar una boleta o una venta';
    if (f.docTransportista.trim().isEmpty) return 'Escribe el DNI o RUC del transportista';
    if (f.razonSocialTransportista.trim().isEmpty) {
      return 'Escribe la razón social del transportista';
    }
    final peso = f.pesoTotal;
    if (peso == null || peso <= 0) return 'El peso total debe ser mayor a 0';

    bool missing(String? v) => v == null || v.trim().isEmpty;
    if (f.tipo == GuideKind.publica) {
      if (missing(f.matricula)) return 'Escribe el registro MTC del transportista';
    } else {
      if (missing(f.dniChofer)) return 'Escribe el DNI del chofer';
      if (missing(f.placaChofer)) return 'Escribe la placa del vehículo';
      if (missing(f.nombreChofer)) return 'Escribe el nombre del chofer';
      if (missing(f.apellidoChofer)) return 'Escribe el apellido del chofer';
      if (missing(f.licenciaChofer)) return 'Escribe la licencia de conducir';
    }

    if (f.ubigeoSalida.isEmpty) return 'Elige el departamento, la provincia y el distrito de salida';
    if (f.direccionSalida.trim().isEmpty) return 'Escribe la dirección de salida';
    if (f.ubigeoLlegada.isEmpty) return 'Elige el departamento, la provincia y el distrito de llegada';
    if (f.direccionLlegada.trim().isEmpty) return 'Escribe la dirección de llegada';
    if ((f.observaciones ?? '').length > 500) return 'Las observaciones admiten hasta 500 caracteres';
    return null;
  }

  Future<Either<Failure, OtherDocumentEntity>> call(GuideFormEntity form) async {
    final problem = validate(form);
    if (problem != null) return Either.left(ValidationFailure(problem));
    return repository.createGuide(form);
  }
}
