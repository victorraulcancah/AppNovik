# Novik (AppNovik) — Alcance inicial

Documento de planificación. **No hay funcionalidad implementada todavía**: `AppNovik` es el proyecto Flutter recién generado (`flutter create --project-name app_novik AppNovik`).

## 1. Objetivo

App móvil de Novik para **celular y tablet**, entregable como **APK (Android)** y app para **iOS**. Consume el backend existente `7power` y replica, en formato móvil, parte de lo que hoy ofrece el front web `7power-front`.

## 2. Módulos de la primera etapa

| # | Módulo | Descripción inicial |
|---|--------|---------------------|
| 1 | Ventas | Consulta y registro de ventas, estado de cuenta de clientes, cotizaciones |
| 2 | Reportes | Reportes de ventas (por sucursal, marca, categoría, departamento, cliente, vendedor, producto) y resumen ejecutivo |
| 3 | Stock | Consulta de stock por almacén, análisis de stock y dashboard de stock inteligente |
| 4 | Documentos | Boletas/facturas, notas de crédito, guías de remisión y cotizaciones |
| 5 | Producto | Catálogo, búsqueda, detalle, imagen, listas de precios |

El detalle funcional de cada módulo (qué pantallas, qué se puede crear/editar y qué es solo lectura) está **por definir**; esta tabla solo fija el punto de partida.

## 3. Proyectos de referencia (en `C:\laragon\www\novik`)

| Proyecto | Rol | Notas |
|----------|-----|-------|
| `7power` | Backend (Laravel, API REST) | Rutas en `routes/api.php`; autenticación con Laravel Sanctum (`auth:sanctum`) |
| `7power-front` | Front web (React + Vite + Ant Design) | Sirve de guía de pantallas y flujos; la URL del API se define en `src/lib/const_glob.ts` |
| `AppNovik` | App móvil (Flutter) | Este proyecto |

### API a consumir (según `7power/routes/api.php`)

- **Auth**: `POST /login`, `POST /logout`, `POST /auth`, `POST /validate-token`, `POST /recuperar-password`, `POST /activate-account`.
- **Ventas**: `/ventas` (resource), `/ventas/estado-de-cuenta`, `/cotizaciones`, `/ventas/resumen-ejecutivo`, `/ventas/metas`.
- **Reportes**: familia `/ventas/reporte-*` (sucursales, marcas, categorías, departamentos, clientes, vendedores, productos-servicios, tracking, caída de clientes, clientes inactivos, productos sin ventas, etc.) y sus variantes `-v2` y `/export`.
- **Stock**: `/stock`, `/almacenes`, `/dashboard-stock`, `/analisis-stock`, `/ordenes-compra`, `/reposicion-ajustes`.
- **Documentos**: `/boletas`, notas de crédito, guías de remisión (controladores `BoletaController`, `NotaCreditoController`, `GuiaRemisionController`).
- **Producto**: `/productos` (+ `/productos/search`, `/productos/img`), `/marcas`, `/categorias`, `/lineas`, `/medidas`, `/lista-de-precios`.

> Antes de implementar cada módulo hay que confirmar contra el código del backend qué parámetros y respuestas devuelve cada endpoint; esta lista sale solo de los nombres de rutas.

### Entornos del API

- Producción (según el front): `https://novi-k.com/7power/public/api`.
- Desarrollo: backend local de `7power` (el front usa `http://localhost:8000` por defecto o `VITE_DEV_API_ORIGIN`).
- La app debe tomar la URL base de un único archivo de configuración, sin URLs repartidas por el código.

## 4. Plataformas y formatos

- **Celular y tablet**: diseño responsivo (layouts distintos según ancho; en tablet, vistas maestro–detalle y tablas más ricas). Orientación vertical y horizontal en tablet.
- **Android**: entregable APK (`flutter build apk --release`); para tienda, App Bundle (`flutter build appbundle`). Requiere firma con keystore propio.
- **iOS**: la compilación y el IPA **solo se pueden generar en macOS con Xcode** y una cuenta Apple Developer. En esta máquina Windows no es posible; hará falta un Mac o un servicio de CI con macOS.
- El proyecto ya incluye carpetas `android/` e `ios/` (y también web, windows, macos, linux, que no son parte del alcance y se pueden eliminar).

## 5. Decisiones pendientes

1. **Nombre y `applicationId`/bundle id** definitivos (hoy el paquete es `app_novik`).
2. **Gestión de estado y arquitectura** (por ejemplo Riverpod/Bloc + capas data/domain/presentation).
3. **Cliente HTTP y almacenamiento seguro del token** (p. ej. `dio` + `flutter_secure_storage`).
4. **Alcance real de cada módulo**: ¿solo consulta o también crear/editar ventas y documentos?
5. **Offline**: si la app debe funcionar sin conexión y cómo sincronizar.
6. **Exportación/descarga** de reportes y PDFs de documentos en móvil.
7. **Roles y permisos**: el backend tiene `RoleController`/`Module`; definir qué módulos ve cada usuario.
8. **Cuenta de Apple Developer / Google Play** y quién publica.

## 6. Propuesta de orden de trabajo

1. Base: configuración de entornos, cliente HTTP, login con token, navegación y layout responsivo celular/tablet.
2. Producto (solo lectura: lista, búsqueda, detalle).
3. Stock (consulta por almacén, dashboard).
4. Ventas.
5. Documentos.
6. Reportes.
7. Empaquetado: APK firmado de Android; build de iOS en Mac/CI.
