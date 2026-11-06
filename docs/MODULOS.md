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

### Descargas de archivos

Toda descarga o exportación (Excel de Stock, Productos y Documentos, plantillas, CDR de SUNAT y el PDF del comprobante) **se guarda en el dispositivo** con el "Guardar como" del sistema (`FilePicker.saveFile`: carpeta Descargas, Drive...). Al guardar sale un aviso con "Compartir" por si se prefiere mandarlo por WhatsApp o correo. El PDF tiene además su botón de compartir.

### Estado de Inicio

Módulo **Inicio**: el Dashboard de la web. Siempre aparece (no depende de un módulo contratado) y es la primera pestaña. Según el rol muestra su resumen: Vendedor → **Ejecutivo** (`/ventas/resumen-ejecutivo`), JEFE COMERCIAL → **Jefe** (`/ventas/resumen-equipo`), Ceo Empresa → **CEO** (`/ventas/resumen-ceo`). Con más de un perfil sale un switch "CEO | Jefe | Ejecutivo" que arranca en el cargo más alto. El Jefe de Almacén (que no ve importes) y los roles sin perfil comercial ven la pantalla de siempre: "Resumen de Ventas MES / AÑO" con el total y el de cada almacén (`/ventas/reporte-almacenes`).

- **Rango**: los mismos atajos de Reportes (Este mes por defecto) o fechas a mano; el CEO también filtra por almacén (`sucursal`). La pantalla general siempre es el mes en curso.
- **Ejecutivo**: saludo según la hora; ventas contra la meta del mes con semáforo (rojo < 50 %, ámbar hasta 100 %, verde desde ahí) y mensaje motivador por tramo (ayuda con todos los tramos); N.º de ventas y ticket con variación contra el año pasado; evolución mensual; ventas por cliente, productos y departamento; oportunidades comerciales (clientes con caída, cotizaciones pendientes, productos sin ventas); Mis tareas (Hoy / Semana / Mes, con filtro por tipo de contacto); clientes con mayor caída; cotizaciones pendientes con prioridad; cumpleaños.
- **Jefe**: ventas del equipo contra la meta de la empresa, evolución, cumplimiento de metas por vendedor, productos más vendidos y departamentos, oportunidades, gestiones del equipo (hechas / programadas por tipo y periodo), clientes y productos con mayor caída, cotizaciones pendientes del equipo (soles y dólares).
- **CEO**: ventas del periodo con comparativos y proyección de cierre; evolución; indicadores estratégicos YTD (la utilidad arranca oculta); cumplimiento por vendedor; departamentos; ventas por canal (dona); cuentas por cobrar (por vencer y vencido); cobro por vendedor; ingresos por entidad bancaria (soles/dólares y filtro de métodos); productos y clientes con mayor caída; nuevos clientes.
- **Menú**: con más de cinco módulos la barra inferior del celular muestra los primeros cuatro y un botón **Más** con la lista del resto; en tablet el riel lateral los muestra todos.
- **Pendiente**: los enlaces que en la web abren otro reporte o la ficha del cliente, y las ayudas (?) de cada tarjeta. "Cotizaciones pendientes" lleva a Documentos (sin filtrar por pendientes) si el usuario tiene el módulo y el permiso.

### Estado de Clientes

- **Oculto por ahora**: el módulo está construido pero no aparece en el menú. Para mostrarlo, quitar `'clientes'` de `_ocultos` en `main_shell_page.dart`.
- **Lista**: tarjetas con nombre o razón social, DNI/RUC, código, departamento, ejecutivo, crédito, insignia de categoría (con el color de su código) y estado. Búsqueda (cada palabra debe aparecer en algún campo), paginación, contadores Todos/Personas/Empresas que filtran, y panel de filtros: tipo, estado, categoría (sin/con o varias), ejecutivo (sin/con o varios) y departamento. El teléfono solo se ve con `clientes.show-telefono`. Un Vendedor ve su cartera (lo resuelve el backend).
- **Detalle**: datos generales, crédito (línea, utilizada, disponible), direcciones, contactos y adicional.
- **Crear y editar** (`POST/PUT /clientes`): pestañas según permisos (`clientes.store` o `clientes.update.informacion-basica`, `.direcciones`, `.contactos`; condiciones de venta con `clientes.condiciones-de-venta` o rol Ceo Empresa). Consulta de DNI/RUC, teléfono internacional, ubigeo, direcciones adicionales con una predeterminada, contactos, lista de precios, método de pago, línea de crédito, categoría automática (solo lectura), URLs, cumpleaños y notas. Un Vendedor no elige ejecutivo ni estado. Al editar no se guarda sin cambios. Lo que el usuario no puede editar no se manda.
- **Categorías**: con `clientes.categorizar`, ciclo (mensual, trimestral, cuatrimestral, anual), rangos por ciclo, guardar y calcular ahora. El Vendedor sin ese permiso las ve en modo lectura.
- **Excel** (`clientes.export`): baja lo que se está viendo.
- **Pendiente**: cumpleaños, seguimiento del cliente, mapa de la pestaña Ubicación (no hay paquete de mapas; la latitud y longitud existentes no se pierden al editar), el "+" para crear una lista de precios desde el formulario, el filtro "Clientes" y subir clientes con Excel.

### Identidad y animaciones

- **Logo e ícono**: la "N" blanca sobre un cuadrado naranja con degradado (el mismo de `AppLogo`, en el login). Android lleva ícono adaptable (con capa para íconos temáticos de Android 13) y redondo; iOS lleva todo el juego de tamaños sin transparencia. Los PNG se generan con un script de Pillow a partir de `assets/fonts/Roboto-Bold.ttf`; si cambia el logo hay que regenerarlos (Android: `res/mipmap-*`, `res/drawable-*/splash_logo.png`; iOS: `AppIcon.appiconset` y `LaunchImage.imageset`).
- **Pantalla de arranque** (antes de que cargue Flutter): fondo azul marino de la marca (`splash_background` en Android, `LaunchScreen.storyboard` en iOS) con el logo al centro. `AppLoadingScreen` dibuja el mismo logo en el mismo lugar (96) y lo hace latir, así el paso de una a otra no se nota.
- **Animaciones** (`components/app_motion.dart`): `AppEntrance` (fundido + leve subida, con retraso para escalonar), `AppPulse` (latido) y `AppFadeSwitcher` (fundido al cambiar de contenido). Se usan en el login (logo y formulario), en el cambio entre módulos del menú, entre login y app, y en las diez primeras tarjetas de `AppCardList` (entran escalonadas una sola vez; una lista nueva, por búsqueda o filtro, vuelve a entrar). Las pantallas usan fundido con avance suave en Android y deslizamiento nativo en iOS (`pageTransitionsTheme`). Con "quitar animaciones" del sistema todo aparece directo.
- **Carga con esqueletos**: mientras carga la primera página de Productos, Stock, Documentos (las seis listas) las pantallas muestran tarjetas grises con brillo (`AppSkeletonList`) en vez de un círculo suelto.
- **Cifras que corren**: las tarjetas de Reportes cuentan hasta su valor (`AppCountUp`).
- **Gráficas que se dibujan** (`AppReveal`): la gráfica de área de Reportes se descubre de izquierda a derecha, las barras agrupadas crecen desde la base (cada grupo un poco después del anterior) y las barras de ranking se llenan hasta su proporción. Se repiten solo cuando cambian los datos; con "quitar animaciones" salen completas y no hay ninguna animación continua.
- **Esqueletos en detalles y modales**: además de `AppSkeletonList`, hay `AppSkeletonDetail` (filas de dato y valor), `AppSkeletonForm` (campos), `AppSkeletonResults` (resultados de búsqueda) y `AppSkeletonReport` (cifras, gráfica y tarjetas). Se usan en la carga de Reportes, la hoja de búsqueda, los catálogos del formulario de producto, el formulario de la guía y el formulario de cliente con sus modales de filtros y categorías. Los indicadores de carga dentro de botones y campos se mantienen.
- **Contraste**: los títulos de las tarjetas de total (`AppMetricCard`) ajustan su color hasta un contraste de al menos 4.5 sobre la tarjeta, en modo claro y oscuro; la franja de color no cambia. El aro de los puntos marcados en la gráfica de área sigue el color de fondo.
- **Detalles**: los avisos (snackbars) salen flotando con esquinas redondeadas y el cambio de módulo da un toque de vibración suave.
- **Respuesta al tocar** (`AppPressScale`): botones, tarjetas de lista y botones de acción se hunden un poco mientras se presionan; si el dedo se arrastra (scroll) dejan de hundirse. Los botones de acción tienen ahora un área táctil de 48 px.
- **Éxito** (`AppSuccessCheck`, `showSuccessSnack`): al registrar una venta o cotización el modal muestra un check que se dibuja y vibra; al crear o editar un cliente, crear una guía o nota de crédito y subir archivos, el aviso lleva el mismo check.
- **Estados vacíos y de error**: ícono en un círculo de color (de la marca, o de error en los "no se pudo cargar") con entrada suave.
- **Sin conexión** (`AppConnectionBanner`, `ConnectionMonitor`): si una petición falla por la red, sale un aviso rojo arriba de toda la app; se quita solo cuando el servidor vuelve a responder. Solo reconoce las peticiones que pasan por `sendApiRequest`; el login tiene su propio mensaje.

### Estado de Productos

Todas las acciones de la web en `/productos` están hechas. Cada una sale solo con su permiso (los mismos de la web):

- **Crear** (`productos.store`) y **Editar** (`productos.update`): un solo formulario como el de la web, con sus mismos campos y orden (tipo, código, SKU, descripción, estado, unidad de medida, cantidad, marca, código de barras, categoría, vender sin stock, proveedor, duplicar, canal, giro de negocio, adicional y foto). En el celular los campos van uno bajo otro; en tableta, de dos en dos como en la web. El **+** junto a unidad de medida, marca, categoría, canal y giro crea el elemento al vuelo (`POST /medidas`, `/marcas`, `/categorias`, `/canales`, `/giros-negocio`) y lo deja elegido. **Foto** (JPG, PNG o WEBP de menos de 2 MB): se sube con el selector del sistema; al editar se ve la imagen actual y se puede eliminar. Se guarda como la web: formulario multipart a `POST /productos` (o `/productos/{id}` con `_method=put`). Sin las pestañas General/Clasificación/Más opciones que tenía antes.
- **Descargar plantilla** (`productos.acciones-adicionales`): las plantillas de Excel de la web (`Plantilla Productos/Marcas/Categorías.xlsx`) vienen dentro de la app (`assets/docs/`) y se guardan en el dispositivo.
- **Subir productos** (`productos.store` o `productos.import`): se elige un `.xlsx` con el selector de archivos del sistema (`file_picker`) y se sube a `POST /productos/import` (formulario con `file` y `company_id`). El servidor importa las filas buenas y devuelve las que fallaron; la app las lista una por una ("Error en fila N") y recarga la lista.
- **Exportar** (`productos.export`): `POST /productos/export`, el Excel "Lista de Productos" se guarda en el dispositivo.
- **Importar marcas** (`brand.store`) y **Importar categorías** (`category.store`): igual que subir productos, a `/marcas/import` y `/categorias/import`; después se vuelven a pedir los catálogos del formulario.
- Si el servidor rechaza el archivo (no es `.xlsx`, vacío...), el modal sigue abierto con el motivo. Sin ningún permiso de acciones, el botón Acciones no aparece.

### Estado de Stock

- **Botón Acciones** (abajo a la derecha, igual que en Productos y Documentos): **Exportar** (`POST /almacenes/export` con el almacén, la lista de precios y la búsqueda; Excel que se guarda en el dispositivo) y **Totales**.
- **Totales** (modal): *Costo Total* y *Total Venta* del almacén. Solo con el permiso `almacenes.show.totales` y rol Admin Global, Ceo Empresa o Contador, como la web. Sin ese acceso, el botón flotante es solo **Exportar**.
- Los cards informativos son un componente reutilizable: `showAppSummary` / `AppMetricCard` (`components/app_summary.dart`), usado también por los totales de Documentos.

### Comprobante en PDF (Documentos)

El ERP **no tiene API** para el PDF de una venta o cotización: la web lo dibuja en el navegador con `boleta.tsx` / `boleta-ticket.tsx` (`comprobante-de-pago`). La app replica esos componentes con el paquete `pdf` (A4 y ticket 80 mm, mismas secciones y reglas de cabecera, fuente Roboto embebida por las tildes). Las franjas grises van en color sólido porque el PDF ignora la transparencia. Solo existen en el backend los PDF de estado de cuenta y de deudas.

### Estado de Documentos

Replicado de `novik.test/documentos` (ventas y cotizaciones), sin probar contra el servidor:

- **Filtros avanzados** (los mismos parámetros que la web: `fecha_desde`, `fecha_hasta`, `sucursales[]`, `vendedores[]`, `clientes[]`, `tipo_documento`, `estado_documento`; en cotizaciones `estado_cotizacion` y `reserva`). Cada lista conserva los suyos; por defecto, los documentos de hoy. Etiquetas con ✕ y "Restablecer". El vendedor sin permiso `reportes.ventas.ver-otros-vendedores` solo se ve a sí mismo.
- **Botón Acciones** (abajo a la derecha, como en Productos): **Descargar Excel** y **Totales**. No hay etiquetas de filtros ni totales sueltos en la lista; los filtros se cambian y restablecen desde el embudo.
- **Totales** (modal): periodo, cantidad de documentos y total en soles y en dólares de todo lo filtrado (las eliminadas no cuentan).
- **Exportar Excel** (`POST /ventas/export` y `/cotizaciones/export`) con lo que se ve; se guarda en el dispositivo.
- **Acciones por documento**: ver detalle; **comprobante en PDF** (A4 o ticket de 80 mm, descargar/compartir/imprimir, con las reglas de cabecera de la web: datos del almacén, del vendedor o de la empresa); **CDR** de SUNAT; **eliminar** venta sin comprobante (`PUT /ventas/{id}` `estado:false`) o cotización (`DELETE`); **nota de crédito** sobre boleta/factura. Permisos como la web (`documentos.ventas.destroy`, `documentos.cotizaciones.destroy`).
- **Las seis listas de la web**, en un selector (como el de la web) y cada una con su permiso: Ventas (`documentos.ventas.index`), Cotizaciones (`documentos.cotizaciones.index`), **Traslados de Stock** (`despachos.transferir.index`), **Guías de Remisión** (`documentos.guia_remision.index`), **Notas de Crédito** (`documentos.nota_credito.index`) y **Entrada de Stock** (`documentos.stock.index`).
- **Traslados, guías, notas de crédito y entradas de stock**: búsqueda por número, rango de fechas "Creado" (por defecto hoy, con el mismo corte de las 05:00 de la web) y el detalle de cada documento con sus productos. Números como la web: `T001-0001`, `TG01-0003`, `BC01-0002` / `FC01-0002`, `S001-0001`. Traslados: aviso "Falta recibir", y eliminar (`DELETE /stock-transfer/{id}`, con `transferir-stock.destroy` y solo si no se recibió ningún producto). Guías y notas de crédito: ven el comprobante al que pertenecen y abren su PDF. Entradas de stock: monto y costos; el rol "jefe de almacén" no ve los importes, como en la web.
- **PDF de traslados y entradas de stock**: con el mismo diseño del documento de la web (título con el número, "Información general", tabla de productos y totales). El traslado muestra "Valor U." (costo promedio en el almacén de salida) y total por producto; la entrada, costo neto y total (el rol "jefe de almacén" la ve sin importes). Se abre desde el botón PDF de la tarjeta o desde el detalle, y se puede descargar, compartir o imprimir.
- **PDF de guías de remisión y notas de crédito**: con el diseño de los documentos de la web (cabecera con logo y datos de la empresa, recuadro con RUC, título y número, "Información general", tabla de productos; la nota lleva además sub total, descuento, valor de venta, IGV y total). La web no dibuja QR ni hash en esos documentos, así que la app tampoco. Salen solo si la lista trae la venta del documento.
- **Crear guía de remisión** (`POST /guia-remision`, permiso `documentos.guia_remision.store`): botón **Guía de remisión** en el comprobante de una venta activa (en Documentos), con las condiciones de la web (la venta sin boleta ni factura ofrece la guía local; si ya tiene una se ve "Guía de remisión creada"). El formulario trae tipo de guía (pública o privada), motivo de traslado, fechas, peso total, transportista (consulta por DNI/RUC), MTC o chofer con placa y licencia, ubigeo y dirección de salida y de llegada (prellenada con la del cliente) y observaciones. Emitir ante la SUNAT puede tardar: la petición espera hasta 120 s. **Previsualizar** (botón arriba del formulario de la guía): como en la web, se arma en la app con lo escrito hasta ahora, sin validar y sin crear nada ni gastar el número. Abre el PDF de la guía (mismo diseño que el de Documentos) con el aviso "VISTA PREVIA — sin guardar" y el número provisional `TGxx-NNNN (provisional)` (serie y último número de la empresa más uno; `guia_serie` y `guia_numero` de `/auth`, y `TG01-0001` si el backend no los trae). Los nombres del ubigeo salen de lo elegido, las fechas que faltan son las de hoy y cada tipo de guía solo lleva sus datos (la pública, el registro MTC; la privada, el chofer y la placa). Se puede descargar, compartir e imprimir.
- **Culminar una cotización como venta o editarla**: en Documentos, una cotización pendiente (activa, y si el usuario puede vender) tiene el botón **Culminar venta o editar cotización** (en la tarjeta y en el detalle). Pasa a Ventas con su cliente, almacén, lista de precios, productos y los precios con los que se cotizó, y un aviso "Está trabajando con la Cotización Nro: C001-xxxx" con **Cancelar**. Si la reserva de stock sigue vigente, lo reservado cuenta como disponible. Al elegir un comprobante se emite la venta (`from_cotizacion`, que marca la cotización como procesada); al elegir *Cotización* se actualiza la misma (`PUT /cotizaciones/{id}`).
- **Pendiente**: probar contra el servidor real la creación de la guía con SUNAT.

### Estado de Reportes

Reportes es el reporte **Ventas General** de la web (pestaña con permiso `reportes.ventas.index`, dentro de `reportes.index`):

- **Fechas**: los mismos atajos de la web (Última semana, Esta semana, Último mes, **Este mes** por defecto, Último año, Este año) o fechas a elección.
- **Cifras** (`GET /ventas/reporte`): Venta Total, Unidades Vendidas, N° de Ventas, Ticket Promedio y Margen (bruto o neto; sale oculto con `S/. ****` hasta tocar el ojo, igual que en la web; el neto descuenta el IGV y la renta de la empresa).
- **Comparar año anterior**: pide el mismo rango un año antes y muestra la variación de cada cifra y la línea del año pasado en la gráfica.
- **Gráfica** de ventas por día (o por mes en rangos largos): soles y dólares; al tocarla se ve el valor de cada punto.
- **Productos y servicios** vendidos en el rango (se cargan de a 15 al bajar), ordenables por venta total, cantidad, subtotal o descuento. **Ver documentos** lista las ventas que incluyen ese producto y abre su comprobante (`GET /ventas/{id}`).
- **Filtros avanzados**: fechas, sucursales, clientes, vendedores, marcas, categoría y departamentos (mismos parámetros que la web). **Descargar Excel** (`POST /ventas/export/reporte`) con los filtros puestos.
- **Por rol**, como en la web: el Jefe de Almacén no ve importes ni margen (solo unidades); el Vendedor ve importes pero no el margen, y sin el permiso `reportes.ventas.ver-otros-vendedores` solo se ve a sí mismo en el filtro de vendedores; solo el CEO ve el margen en todo caso.
- **Alcance**: Reportes en la app es **solo esta pestaña (Ventas General)**; el usuario pidió que no se agreguen las demás pestañas de la web.
- Antes la app mostraba un "Resumen ejecutivo" que no es un reporte de la web (es del Dashboard); se quitó.

### Estado de Ventas

- **Paso 1 (hecho, sin probar contra el servidor)**: venta al contado en soles. Permiso `ventas.store`. Comprobante (Ticket de Venta; boleta y factura solo si la empresa tiene certificado), almacén, lista de precios en soles, cliente (`/clientes/search`), productos (`/productos/search`, con stock por almacén y precio por lista) y `POST /ventas`.
- **Modal "Crear venta"** (como el de la web; se abre con *Registrar venta* y es lo que crea la venta): **fecha de emisión** (ticket: hasta 30 días atrás; boleta y factura: hoy y 2 días antes; solo se envía `created_at` si se elige otro día), **método de entrega** (Entrega Inmediata / Despacho; por defecto el del usuario), **uno o más métodos de pago** con su monto (se puede agregar y quitar; deben sumar el total; CONTRAENTREGA incluida) y observaciones. Si el servidor rechaza la venta, el modal sigue abierto con el motivo. La cotización mantiene su flujo (observaciones y reserva de stock).
- **Tipo de documento** siempre elegible: Ticket de Venta, boleta y factura (estas dos solo con certificado) y **cotización** (`POST /cotizaciones`, con reserva de stock opcional hasta una fecha). La factura no se emite a una persona. Boleta menor a S/ 700 puede ir **sin documento del cliente** (cliente varios).
- **Tipo de cambio** comercial vigente (`GET /tipo-cambio/comercial`) con su fuente, fecha y margen, y botón para actualizarlo.
- **Ventas en dólares**: la moneda es la de la lista de precios elegida (soles o dólares, como la web). En dólares los precios, el subtotal y el total salen con `$`; el modal "Crear venta" pide el **tipo de cambio** (el oficial, editable entre 3.000 y 4.300, que el backend exige) y muestra el equivalente en soles de cada pago. Una boleta en dólares no puede ir sin documento del cliente.
- **Crédito, plazo y cuotas**: las formas de pago CRÉDITO y PLAZO piden que el cliente tenga línea de crédito (si no, salen "no disponible"). Se ve el crédito disponible en soles (y lo que se le descontará en una venta en dólares), el monto no puede pasar de lo disponible, y las **cuotas** se reparten al céntimo con el plazo elegido (Diario, Semanal, Mensual o Anual; el plazo a plazo arranca en diario con una sola cuota), con fecha editable, agregar y quitar cuotas; deben sumar el monto del crédito. Solo una forma de pago a crédito por venta. Se envía `installments` y `plazo` en `payment_methods`.
- **Puntos**: si la empresa tiene el programa de puntos aparece la forma de pago PUNTOS (con "no disponible" si el cliente no llega al mínimo para canjear). Se canjean en soles, hasta los puntos a favor del cliente y desde el mínimo de la empresa; en una venta en dólares se convierten con el tipo de cambio.
- **Crear cliente** (permiso `clientes.store`): tipo, DNI/RUC con consulta a RENIEC/SUNAT, nombre, teléfono, correo, departamento/provincia/distrito, calle y dirección. Un Vendedor o el Ceo queda como ejecutivo comercial del cliente. Pendiente de la ficha completa de la web (direcciones adicionales, contactos, crédito, lista de precios, mapa).
- **Buscador de productos** (modal): búsqueda en el servidor por nombre, código, marca o categoría; filtros por categoría y marca (en 7power no hay subcategorías ni submarcas); marcar varios productos con su cantidad y agregarlos de una vez. Muestra stock del almacén, precio de la lista, categoría y unidad (cada producto tiene una sola unidad de medida). Los productos sin stock quedan bloqueados salvo los de "vender sin stock" y los servicios, y la cantidad no pasa de lo disponible (descontando lo que ya está en la venta).
- **Descuento por línea**: cada línea de la venta o cotización tiene su descuento en porcentaje o, con el botón de cambio, en monto fijo (máximo 100 % o el subtotal de la línea; si se escribe más, se recorta). El total y el subtotal de la línea van con el descuento; se manda `dto_fijo`, `dto`, `monto_dto`, `subtotal` y `subtotal_con_dto`. El comprobante muestra el descuento total.
- **Ítem libre**: con el permiso `factura.libre` aparece "Agregar ítem libre" (descripción, código opcional, cantidad y precio). Va como `product_id` nulo con `concepto_libre` y `codigo_libre`, no mueve stock ni se reprecia al cambiar de lista. Si el código ya es un producto del catálogo, se agrega como producto normal (con el mismo aviso de stock de la web). Una cotización no admite ítems libres (el backend exige producto).
- **Vendedor encargado**: el modal de la cotización lo ofrece (opcional; usuarios Vendedor y Admin Empresa, sin el propio usuario; `GET /usuarios/list`) y viaja como `vendedor_id`; al editar arranca con el que tenía. Al culminar una cotización como venta, la venta lleva ese vendedor (en "Crear venta" no se elige, como en la web). Si una cotización tiene el mismo producto en dos líneas con distinto descuento, al culminarla se juntan en una sola con la suma de lo descontado.
- **Pendiente**: editar la descripción de un ítem libre ya agregado, el interruptor "monto sin IGV" de la web y el punto de venta con caja.
- La app no repite la venta si falla la red: avisa que se revise Documentos antes de reintentar, porque el servidor pudo haberla registrado.

## 3. Preguntas abiertas

1. **¿Un mismo usuario puede trabajar con más de una empresa?** Hoy el backend no lo permite (un usuario = una empresa). Si hace falta, habría que cambiar el backend o aceptar dos logins distintos en la app.
2. **¿Quién es el usuario principal de la app?** Vendedores (productos, stock, ventas) o gerentes (reportes). Cambia qué módulo va primero.
3. **"Stock"**: ¿solo el módulo Stock, o también "Stock Inteligente" (análisis, órdenes de compra, reposición) de la web?
4. **Nombres**: en el backend los módulos se llaman `Productos`, `Stock`, `Ventas`, `Documentos` y `Reportes`. Confirmar que "producto" es `Productos`.
5. **Punto de Venta, Clientes, Despachos, Deudas**: no están en tu lista; Ventas necesita clientes, así que habrá que decidir si entran como parte de Ventas.
