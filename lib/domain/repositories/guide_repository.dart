import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/guide_form_entity.dart';
import '../entities/other_document_entity.dart';

abstract class GuideRepository {
  /// Si la venta ya tiene guía y la dirección de llegada que le corresponde.
  Future<Either<Failure, GuideDefaultsEntity>> getDefaults(int saleId);

  /// Chofer registrado con ese DNI; `null` si no existe.
  Future<Either<Failure, DriverEntity?>> findDriver(String dni);

  /// Crea la guía (`POST /guia-remision`). Con boleta o factura se emite ante la SUNAT.
  Future<Either<Failure, OtherDocumentEntity>> createGuide(GuideFormEntity form);
}
