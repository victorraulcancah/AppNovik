# Orden de módulos y diseño multiempresa

Basado en el código de `7power` (backend) y `7power-front` (web). Pendiente de validar contigo: ver "Preguntas abiertas".

## 1. Cómo funciona lo multiempresa en 7power

- **Cada usuario pertenece a una sola empresa** (`users.company_id`). El token de Sanctum identifica al usuario. Varias partes del backend filtran por `Auth::user()->company_id`, **pero no todas**: `GET /productos` y `GET /productos/search` exigen `company_id` como parámetro de la petición y filtran con ese valor sin comprobar que sea el de la empresa del usuario. La app debe enviar siempre el `company_id` de su sesión, y el backend debería validarlo (hoy un usuario autenticado podría pedir productos de otra empresa cambiando ese parámetro). Pendiente de corregir en 7power.
- Casi toda la información lleva `company_id`: productos, ventas, cotizaciones, stock, almacenes, clientes, listas de precios, marcas, categorías, despachos, etc. Los números de documento se numeran por empresa.
- **Perfil/plan de la empresa** (`profiles`): `documentos_max`, `almacenes_max`, `estado_cuenta_clientes`, `ecommerce`. Hay funciones que dependen del plan.
- **Módulos por empresa**: la tabla `module_company` define qué módulos tiene contratados cada empresa. Además cada usuario necesita el permiso `<nombre-del-módulo-en-slug>.index` (por rol).
- **Por usuario**: almacenes asignados, lista de precios predeterminada, métodos de pago.
- `POST /auth` devuelve todo esto de una vez: `user` (con `company`, `company.profile`, `paymentMethods`, `listPrice`, `warehouses`, `permissions`, `roles`) y `modulos` (ya filtrados por empresa y permiso).

### Qué implica para la app

1. Tras el login se llama a `POST /auth` y se guarda un **contexto de sesión** (usuario, empresa, plan, almacenes, lista de precios, módulos, permisos).
2. **El menú se construye con `modulos`**, no con una lista fija. Si una empresa no tiene "Reportes", la app no lo muestra.
3. Al cerrar sesión o cambiar de usuario se **borra toda caché local**, para que nunca se mezclen datos de dos empresas en el mismo dispositivo.
4. Mostrar el nombre/logo de la empresa activa (`GET /empresas/logo`).
5. Respetar los límites del plan (por ejemplo `almacenes_max`) y ocultar funciones que el plan no incluye.
6. Cada feature pasa por el mismo patrón de capas; el contexto de empresa vive en un `SessionProvider` común, no dentro de cada módulo.

## 2. Orden propuesto

| Etapa | Qué | Por qué |
|-------|-----|---------|
| 0 | **Base multiempresa**: `/auth`, sesión, menú por `modulos`/permisos, logo de empresa, cierre de sesión que limpia caché | Todo módulo depende de esto; es lo que evita errores graves entre empresas |
| 1 | **Producto** (solo lectura): lista, búsqueda, detalle, imagen, precio según la lista del usuario | Es la base de ventas y stock; solo lectura, riesgo bajo |
| 2 | **Stock** (solo lectura): stock por almacén, dashboard | Reutiliza productos y almacenes; valida el filtrado por almacén del usuario |
| 3 | **Ventas**: lista, detalle y estado de cuenta; luego crear venta | Necesita clientes, productos, stock y métodos de pago |
| 4 | **Documentos**: consulta y descarga (boletas, notas de crédito, guías de remisión) | Depende de ventas; dependen de la facturación de cada empresa |
| 5 | **Reportes**: empezar por `resumen-ejecutivo` y 2–3 reportes clave | Son muchos endpoints (`/ventas/reporte-*`); conviene hacerlos al final y con gráficos |

Cada módulo se entrega primero en **solo lectura** y después se agregan las acciones de crear/editar.

### Estado de Productos

Todas las acciones de la web en `/productos` están hechas. Cada una sale solo con su permiso (los mismos de la web):

- **Crear** (`productos.store`) y **Editar** (`productos.update`).
- **Descargar plantilla** (`productos.acciones-adicionales`): las plantillas de Excel de la web (`Plantilla Productos/Marcas/Categorías.xlsx`) vienen dentro de la app (`assets/docs/`) y se comparten con el menú del sistema.
- **Subir productos** (`productos.store` o `productos.import`): se elige un `.xlsx` con el selector de archivos del sistema (`file_picker`) y se sube a `POST /productos/import` (formulario con `file` y `company_id`). El servidor importa las filas buenas y devuelve las que fallaron; la app las lista una por una ("Error en fila N") y recarga la lista.
- **Exportar** (`productos.export`): `POST /productos/export`, el Excel "Lista de Productos" se comparte con el menú del sistema.
- **Importar marcas** (`brand.store`) y **Importar categorías** (`category.store`): igual que subir productos, a `/marcas/import` y `/categorias/import`; después se vuelven a pedir los catálogos del formulario.
- Si el servidor rechaza el archivo (no es `.xlsx`, vacío...), el modal sigue abierto con el motivo. Sin ningún permiso de acciones, el botón Acciones no aparece.

### Estado de Stock

- **Botón Acciones** (abajo a la derecha, igual que en Productos y Documentos): **Exportar** (`POST /almacenes/export` con el almacén, la lista de precios y la búsqueda; Excel que se comparte con el menú del sistema) y **Totales**.
- **Totales** (modal): *Costo Total* y *Total Venta* del almacén. Solo con el permiso `almacenes.show.totales` y rol Admin Global, Ceo Empresa o Contador, como la web. Sin ese acceso, el botón flotante es solo **Exportar**.
- Los cards informativos son un componente reutilizable: `showAppSummary` / `AppMetricCard` (`components/app_summary.dart`), usado también por los totales de Documentos.

### Comprobante en PDF (Documentos)

El ERP **no tiene API** para el PDF de una venta o cotización: la web lo dibuja en el navegador con `boleta.tsx` / `boleta-ticket.tsx` (`comprobante-de-pago`). La app replica esos componentes con el paquete `pdf` (A4 y ticket 80 mm, mismas secciones y reglas de cabecera, fuente Roboto embebida por las tildes). Las franjas grises van en color sólido porque el PDF ignora la transparencia. Solo existen en el backend los PDF de estado de cuenta y de deudas.

### Estado de Documentos

Replicado de `novik.test/documentos` (ventas y cotizaciones), sin probar contra el servidor:

- **Filtros avanzados** (los mismos parámetros que la web: `fecha_desde`, `fecha_hasta`, `sucursales[]`, `vendedores[]`, `clientes[]`, `tipo_documento`, `estado_documento`; en cotizaciones `estado_cotizacion` y `reserva`). Cada lista conserva los suyos; por defecto, los documentos de hoy. Etiquetas con ✕ y "Restablecer". El vendedor sin permiso `reportes.ventas.ver-otros-vendedores` solo se ve a sí mismo.
- **Botón Acciones** (abajo a la derecha, como en Productos): **Descargar Excel** y **Totales**. No hay etiquetas de filtros ni totales sueltos en la lista; los filtros se cambian y restablecen desde el embudo.
- **Totales** (modal): periodo, cantidad de documentos y total en soles y en dólares de todo lo filtrado (las eliminadas no cuentan).
- **Exportar Excel** (`POST /ventas/export` y `/cotizaciones/export`) con lo que se ve; se comparte con el menú del sistema.
- **Acciones por documento**: ver detalle; **comprobante en PDF** (A4 o ticket de 80 mm, descargar/compartir/imprimir, con las reglas de cabecera de la web: datos del almacén, del vendedor o de la empresa); **CDR** de SUNAT; **eliminar** venta sin comprobante (`PUT /ventas/{id}` `estado:false`) o cotización (`DELETE`); **nota de crédito** sobre boleta/factura. Permisos como la web (`documentos.ventas.destroy`, `documentos.cotizaciones.destroy`).
- **Pendiente**: guía de remisión, convertir una cotización en venta, y las otras pestañas (traslados de stock, guías de remisión, notas de crédito, entradas de stock).

### Estado de Reportes

- **Versión 1 (hecha, sin probar contra el servidor)**: *Resumen ejecutivo* (`GET /ventas/resumen-ejecutivo`, permiso `reportes.index`). Rango: hoy, este mes (predeterminado), mes pasado, este año o fechas a elección. Muestra ventas contra el mismo rango del año pasado, n.º de ventas, ticket promedio, meta del mes con su semáforo, evolución por mes (año actual contra el anterior), mejores clientes, productos más vendidos, venta por departamento y cotizaciones pendientes.
- Es el resumen **del propio usuario** (las ventas que se le atribuyen); el backend responde 403 al Jefe de Almacén.
- **Pendiente**: el resto de las pestañas de la web (Producto, Ventas General, Vendedor, Sucursales, Marcas, Categorías, Clientes, Tracking, Clientes con caída, Productos sin ventas...), exportar a Excel, y las tarjetas del resumen que dependen de Gestión y seguimiento (tareas de hoy, clientes que necesitan atención, cumpleaños).

### Estado de Ventas

- **Paso 1 (hecho, sin probar contra el servidor)**: venta al contado en soles. Permiso `ventas.store`. Comprobante (Ticket de Venta; boleta y factura solo si la empresa tiene certificado), almacén, lista de precios en soles, cliente (`/clientes/search`), productos (`/productos/search`, con stock por almacén y precio por lista) y `POST /ventas`.
- **Modal "Crear venta"** (como el de la web; se abre con *Registrar venta* y es lo que crea la venta): **fecha de emisión** (ticket: hasta 30 días atrás; boleta y factura: hoy y 2 días antes; solo se envía `created_at` si se elige otro día), **método de entrega** (Entrega Inmediata / Despacho; por defecto el del usuario), **uno o más métodos de pago** con su monto (se puede agregar y quitar; deben sumar el total; CONTRAENTREGA incluida) y observaciones. Si el servidor rechaza la venta, el modal sigue abierto con el motivo. La cotización mantiene su flujo (observaciones y reserva de stock).
- **Tipo de documento** siempre elegible: Ticket de Venta, boleta y factura (estas dos solo con certificado) y **cotización** (`POST /cotizaciones`, con reserva de stock opcional hasta una fecha). La factura no se emite a una persona. Boleta menor a S/ 700 puede ir **sin documento del cliente** (cliente varios).
- **Tipo de cambio** comercial vigente (`GET /tipo-cambio/comercial`) con su fuente, fecha y margen, y botón para actualizarlo. Aún no se vende en dólares.
- **Crear cliente** (permiso `clientes.store`): tipo, DNI/RUC con consulta a RENIEC/SUNAT, nombre, teléfono, correo, departamento/provincia/distrito, calle y dirección. Un Vendedor o el Ceo queda como ejecutivo comercial del cliente. Pendiente de la ficha completa de la web (direcciones adicionales, contactos, crédito, lista de precios, mapa).
- **Buscador de productos** (modal): búsqueda en el servidor por nombre, código, marca o categoría; filtros por categoría y marca (en 7power no hay subcategorías ni submarcas); marcar varios productos con su cantidad y agregarlos de una vez. Muestra stock del almacén, precio de la lista, categoría y unidad (cada producto tiene una sola unidad de medida). Los productos sin stock quedan bloqueados salvo los de "vender sin stock" y los servicios, y la cantidad no pasa de lo disponible (descontando lo que ya está en la venta).
- **Paso 2 (pendiente)**: crédito/plazo y cuotas (esas formas de pago aún no aparecen en el modal), ventas en dólares (tipo de cambio 3.000–4.300), puntos, descuentos, ítems libres y vendedor encargado.
- La app no repite la venta si falla la red: avisa que se revise Documentos antes de reintentar, porque el servidor pudo haberla registrado.

## 3. Preguntas abiertas

1. **¿Un mismo usuario puede trabajar con más de una empresa?** Hoy el backend no lo permite (un usuario = una empresa). Si hace falta, habría que cambiar el backend o aceptar dos logins distintos en la app.
2. **¿Quién es el usuario principal de la app?** Vendedores (productos, stock, ventas) o gerentes (reportes). Cambia qué módulo va primero.
3. **"Stock"**: ¿solo el módulo Stock, o también "Stock Inteligente" (análisis, órdenes de compra, reposición) de la web?
4. **Nombres**: en el backend los módulos se llaman `Productos`, `Stock`, `Ventas`, `Documentos` y `Reportes`. Confirmar que "producto" es `Productos`.
5. **Punto de Venta, Clientes, Despachos, Deudas**: no están en tu lista; Ventas necesita clientes, así que habrá que decidir si entran como parte de Ventas.
