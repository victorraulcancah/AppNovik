import '../../domain/entities/company_entity.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/guide_form_entity.dart';
import '../../domain/entities/other_document_entity.dart';

/// Número que tendría la guía si se creara ahora: serie y número siguiente de la empresa, igual
/// que la vista previa de la web (`TG01-0001 (provisional)`). Solo se muestra, no se reserva.
String guidePreviewNumber(CompanyEntity company) {
  final serie = (company.guiaSerie ?? 1).toString().padLeft(2, '0');
  final numero = ((company.guiaNumero ?? 0) + 1).toString().padLeft(4, '0');
  return 'TG$serie-$numero (provisional)';
}

String? _text(String? value) {
  final v = value?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// La guía de remisión tal como saldría con lo escrito hasta ahora en el formulario, para
/// dibujarla en PDF antes de crearla. No hay validación (se previsualiza aunque falten datos,
/// como en la web) ni se emite nada: las fechas que faltan son las de hoy.
///
/// [ubigeoSalida] y [ubigeoLlegada] son los nombres `Distrito, Provincia, Departamento`.
OtherDocumentEntity buildGuidePreview({
  required GuideFormEntity form,
  required DocumentEntity sale,
  required CompanyEntity company,
  String? ubigeoSalida,
  String? ubigeoLlegada,
  required DateTime now,
}) {
  final privada = form.tipo == GuideKind.privada;
  return OtherDocumentEntity(
    kind: OtherDocumentKind.guia,
    id: 0,
    numero: guidePreviewNumber(company),
    creado: now,
    comprobanteNumero: sale.numero,
    comprobante: sale,
    guia: GuideInfo(
      pesoTotal: form.pesoTotal ?? 0,
      direccionSalida: _text(form.direccionSalida),
      direccionLlegada: _text(form.direccionLlegada),
      ubigeoSalida: _text(ubigeoSalida),
      ubigeoLlegada: _text(ubigeoLlegada),
      fechaEmision: form.fechaEmision ?? now,
      fechaTraslado: form.fechaTraslado ?? now,
      tipoGuia: form.tipo.code,
      codTraslado: form.codTraslado,
      documentoTransportista: _text(form.docTransportista),
      transportista: _text(form.razonSocialTransportista),
      // Cada tipo de guía solo lleva sus datos (la pública su registro MTC, la privada su chofer).
      matricula: privada ? null : _text(form.matricula),
      dniChofer: privada ? _text(form.dniChofer) : null,
      placaChofer: privada ? _text(form.placaChofer) : null,
      observaciones: _text(form.observaciones),
    ),
  );
}
