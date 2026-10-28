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

## 3. Preguntas abiertas

1. **¿Un mismo usuario puede trabajar con más de una empresa?** Hoy el backend no lo permite (un usuario = una empresa). Si hace falta, habría que cambiar el backend o aceptar dos logins distintos en la app.
2. **¿Quién es el usuario principal de la app?** Vendedores (productos, stock, ventas) o gerentes (reportes). Cambia qué módulo va primero.
3. **"Stock"**: ¿solo el módulo Stock, o también "Stock Inteligente" (análisis, órdenes de compra, reposición) de la web?
4. **Nombres**: en el backend los módulos se llaman `Productos`, `Stock`, `Ventas`, `Documentos` y `Reportes`. Confirmar que "producto" es `Productos`.
5. **Punto de Venta, Clientes, Despachos, Deudas**: no están en tu lista; Ventas necesita clientes, así que habrá que decidir si entran como parte de Ventas.
