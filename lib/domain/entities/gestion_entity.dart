/// Cómo se hizo (o se hará) un contacto con el cliente. Las claves son las del backend.
enum GestionContacto {
  llamada('llamada', 'Llamada telefónica', 'Llamada'),
  whatsapp('whatsapp', 'WhatsApp', 'WhatsApp'),
  visita('visita', 'Visita presencial', 'Visita'),
  correo('correo', 'Correo electrónico', 'Correo');

  final String key;
  final String etiqueta;
  final String corto;

  const GestionContacto(this.key, this.etiqueta, this.corto);

  static GestionContacto? fromKey(Object? key) {
    for (final c in values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// El color de un resultado: `positivo` verde, `espera` azul, `objecion` naranja, `neutro` gris y
/// `perdido` rojo.
enum GestionTono {
  positivo,
  espera,
  neutro,
  objecion,
  perdido;

  static GestionTono fromKey(Object? key) {
    for (final t in values) {
      if (t.name == key) return t;
    }
    return GestionTono.neutro;
  }
}

/// Estado del cliente: el del reporte "Clientes con caída" (`sin_base` si el año anterior no compró en
/// ese tramo).
enum GestionEstado {
  critico,
  riesgo,
  seguimiento,
  normal,
  sinBase;

  static GestionEstado fromKey(Object? key) => switch (key) {
        'critico' => GestionEstado.critico,
        'riesgo' => GestionEstado.riesgo,
        'seguimiento' => GestionEstado.seguimiento,
        'normal' => GestionEstado.normal,
        _ => GestionEstado.sinBase,
      };
}

/// Un resultado que se puede elegir al registrar una gestión, con la guía de cuándo elegirlo.
class GestionResultado {
  final String clave;
  final String etiqueta;
  final GestionTono tono;
  final String cuando;

  const GestionResultado({
    required this.clave,
    required this.etiqueta,
    required this.tono,
    required this.cuando,
  });
}

class GestionCatalogo {
  final List<GestionResultado> resultados;

  const GestionCatalogo({this.resultados = const []});

  GestionResultado? resultado(String? clave) {
    for (final r in resultados) {
      if (r.clave == clave) return r;
    }
    return null;
  }
}

/// Un cliente que devuelve el buscador (también los dados de baja).
class GestionClienteBuscado {
  final int id;
  final String nombre;
  final String? documento;
  final String? codigo;
  final String? ciudad;
  final bool activo;

  const GestionClienteBuscado({
    required this.id,
    required this.nombre,
    this.documento,
    this.codigo,
    this.ciudad,
    this.activo = true,
  });
}

/// Una gestión programada que sigue sin hacerse (las "tareas pendientes").
class GestionTarea {
  final int id;
  final int clienteId;
  final String cliente;

  /// Clave del tipo de contacto (`llamada`, `whatsapp`, `visita`, `correo`).
  final String tipo;
  final String tipoEtiqueta;
  final String? accion;
  final DateTime fecha;
  final bool vencida;
  final int? ejecutivoId;
  final String? ejecutivo;

  const GestionTarea({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.tipo,
    required this.tipoEtiqueta,
    this.accion,
    required this.fecha,
    required this.vencida,
    this.ejecutivoId,
    this.ejecutivo,
  });
}

/// Las tareas pendientes de la cartera del vendedor o, con [equipo], las de todo el equipo.
class GestionTareas {
  final bool equipo;
  final List<GestionTarea> tareas;

  const GestionTareas({this.equipo = false, this.tareas = const []});
}

class GestionCliente {
  final int id;
  final String? codigo;
  final String nombre;
  final bool esEmpresa;
  final String? documento;
  final String? telefono;
  final String? email;

  /// Algunos datos de contacto no se muestran con el perfil del usuario.
  final bool contactoOculto;
  final String? direccion;
  final String? ciudad;
  final String? categoria;
  final String? vendedor;
  final String? condicionPago;
  final double limiteCredito;
  final bool activo;
  final GestionEstado estado;
  final String estadoEtiqueta;

  const GestionCliente({
    required this.id,
    this.codigo,
    required this.nombre,
    this.esEmpresa = false,
    this.documento,
    this.telefono,
    this.email,
    this.contactoOculto = false,
    this.direccion,
    this.ciudad,
    this.categoria,
    this.vendedor,
    this.condicionPago,
    this.limiteCredito = 0,
    this.activo = true,
    this.estado = GestionEstado.sinBase,
    this.estadoEtiqueta = 'Sin comparación',
  });
}

class GestionUltimaCompra {
  final int id;
  final DateTime fecha;
  final String documento;
  final double monto;

  const GestionUltimaCompra({
    required this.id,
    required this.fecha,
    required this.documento,
    required this.monto,
  });
}

class GestionKpis {
  /// `null` si el cliente nunca compró.
  final int? diasSinComprar;
  final GestionUltimaCompra? ultimaCompra;

  const GestionKpis({this.diasSinComprar, this.ultimaCompra});
}

/// Del 1 de enero a hoy contra el mismo tramo del año anterior: lo que muestran las tarjetas del Resumen.
class GestionPeriodo {
  final DateTime desde;
  final DateTime hasta;

  /// "1 ene - 21 oct 2026".
  final String etiqueta;
  final String etiquetaAnterior;
  final double ventas;
  final int compras;
  final double ticketPromedio;
  final double ventasAnterior;

  /// Positiva si vendió más que en el año anterior, negativa si cayó.
  final double variacion;

  /// Positiva = cayó (como en el reporte); `null` si el año anterior no compró en ese tramo.
  final double? caidaPct;

  const GestionPeriodo({
    required this.desde,
    required this.hasta,
    this.etiqueta = '',
    this.etiquetaAnterior = '',
    this.ventas = 0,
    this.compras = 0,
    this.ticketPromedio = 0,
    this.ventasAnterior = 0,
    this.variacion = 0,
    this.caidaPct,
  });
}

class GestionProducto {
  final String producto;
  final String? codigo;
  final double monto;
  final double porcentaje;

  const GestionProducto({
    required this.producto,
    this.codigo,
    required this.monto,
    required this.porcentaje,
  });
}

/// El siguiente contacto de una gestión: `programado` mientras falta hacerlo, `cumplido` cuando ya se hizo.
enum GestionSeguimiento {
  programado,
  cumplido;

  static GestionSeguimiento? fromKey(Object? key) {
    for (final s in values) {
      if (s.name == key) return s;
    }
    return null;
  }
}

/// Un contacto con el cliente: lo que se hizo, su resultado y, si se dejó, el siguiente contacto.
class GestionRegistro {
  final int id;
  final GestionContacto tipo;
  final String tipoEtiqueta;

  /// Clave del resultado (la del catálogo).
  final String resultado;
  final String resultadoEtiqueta;
  final GestionTono tono;
  final String? comentario;
  final String? registradoPor;
  final DateTime fecha;
  final DateTime? proximoSeguimiento;

  /// Cómo será el siguiente contacto; puede ser distinto del tipo de esta gestión.
  final GestionContacto? proximoTipo;
  final String? proximoTipoEtiqueta;

  /// Qué se hará en el siguiente contacto ("Enviar cotización").
  final String? proximaAccion;
  final GestionSeguimiento? seguimientoEstado;

  /// Solo en la "próxima gestión": el contacto programado ya pasó de su día.
  final bool vencida;

  const GestionRegistro({
    required this.id,
    required this.tipo,
    required this.tipoEtiqueta,
    required this.resultado,
    required this.resultadoEtiqueta,
    this.tono = GestionTono.neutro,
    this.comentario,
    this.registradoPor,
    required this.fecha,
    this.proximoSeguimiento,
    this.proximoTipo,
    this.proximoTipoEtiqueta,
    this.proximaAccion,
    this.seguimientoEstado,
    this.vencida = false,
  });
}

/// Todo lo de la cabecera y la pestaña Resumen.
class GestionFicha {
  final GestionCliente cliente;
  final GestionKpis kpis;
  final GestionPeriodo periodo;
  final GestionRegistro? ultimaGestion;
  final GestionRegistro? proximaGestion;
  final List<GestionProducto> productos;

  const GestionFicha({
    required this.cliente,
    required this.kpis,
    required this.periodo,
    this.ultimaGestion,
    this.proximaGestion,
    this.productos = const [],
  });
}

/// Las gestiones del cliente (de la más reciente a la más antigua) y lo que va del año.
class GestionHistorial {
  final List<GestionRegistro> gestiones;
  final GestionRegistro? proxima;

  /// Cuántas gestiones van desde el 1 de enero (la tarjeta "Total de gestiones").
  final int totalAnio;
  final DateTime? desdeAnio;

  const GestionHistorial({
    this.gestiones = const [],
    this.proxima,
    this.totalAnio = 0,
    this.desdeAnio,
  });
}

/// Lo que se manda para registrar una gestión.
class GestionNueva {
  final GestionContacto tipo;
  final String resultado;
  final String? comentario;

  /// Fecha y hora del siguiente contacto; `null` si no se programa uno.
  final DateTime? proximo;
  final GestionContacto? proximoTipo;
  final String? proximaAccion;

  const GestionNueva({
    required this.tipo,
    required this.resultado,
    this.comentario,
    this.proximo,
    this.proximoTipo,
    this.proximaAccion,
  });
}

/// Lo que se manda para corregir una gestión ya registrada.
///
/// Con [cumplida] el siguiente contacto es historia: solo se retoca su acción. Si no, [proximo] lo
/// programa (o lo corrige) y `null` lo quita.
class GestionEdicion {
  final GestionContacto tipo;
  final String resultado;
  final String? comentario;
  final bool cumplida;
  final DateTime? proximo;
  final GestionContacto? proximoTipo;
  final String? proximaAccion;

  const GestionEdicion({
    required this.tipo,
    required this.resultado,
    this.comentario,
    this.cumplida = false,
    this.proximo,
    this.proximoTipo,
    this.proximaAccion,
  });
}
