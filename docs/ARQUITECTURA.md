# Arquitectura de AppNovik

Copiada de `C:\laragon\www\arequipagocreditos` (Clean Architecture + Provider). Su documento de origen es `CLEAN_ARCHITECTURE.md` de ese proyecto.

```
lib/
├── core/
│   ├── constants/        api_constants.dart (URL base vía --dart-define=API_DOMAIN), app_constants.dart
│   ├── errors/           exceptions.dart (capa data) · failures.dart (capa domain/presentation)
│   ├── network/          api_client.dart
│   └── utils/            either.dart · validators.dart
├── data/
│   ├── datasources/      *_remote_datasource.dart (http) · *_local_datasource.dart (secure storage)
│   ├── models/           JSON ↔ objeto; extienden las entidades
│   └── repositories/     implementaciones; convierten Exception → Failure
├── domain/
│   ├── entities/
│   ├── repositories/     interfaces
│   └── usecases/
├── presentation/
│   ├── pages/            login_page, main_shell_page (barra inferior en celular, riel en tablet)
│   ├── providers/        ChangeNotifier por feature
│   └── components/ y widgets/   (se crean al hacer falta)
├── theme/app_theme.dart
├── dependency_injection.dart   lista de providers y cableado de dependencias
└── main.dart
```

Flujo: `UI → Provider → UseCase → Repository (interfaz) → RepositoryImpl → DataSource → API`.

## Diferencias respecto a arequipagocreditos

- Los repositorios devuelven `Either<Failure, T>` (como describe su documento). En su código real varios repositorios lanzan `Failure` en vez de devolver `Either`.
- Se omitió todo lo específico de ese negocio: Firebase/notificaciones, biometría/PIN, firma de documentos, cupones, financiamiento.
- El token de Sanctum y el usuario se guardan en `flutter_secure_storage`.

## Lo implementado

Solo la feature **auth** completa (`POST /login` con `usuario` y `password`, `POST /logout`) y un shell con los cinco módulos como pantallas "en construcción". Los módulos reales siguen el patrón de "Agregar una nueva feature" de `CLEAN_ARCHITECTURE.md`: entity → repository → usecase → model/datasource/repository impl → provider → registrar en `dependency_injection.dart`.

## Cambiar el servidor

```bash
flutter run --dart-define=API_DOMAIN=http://192.168.1.10:8000
```
