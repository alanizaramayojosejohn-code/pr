# Release signing — PR Android

## Prerequisitos (una sola vez)

### 1. Google Cloud SDK (para subir APKs a Firebase Storage)

```powershell
winget install Google.CloudSDK
# Reinicia la terminal, luego:
gcloud auth login
```

### 2. Keystore release

```powershell
keytool -genkeypair -v `
  -keystore pr-release.jks `
  -keyalg RSA -keysize 2048 `
  -validity 10000 `
  -alias pr `
  -dname "CN=PR App, OU=Mobile, O=Alaniz Jose, L=Argentina, S=Argentina, C=AR"
```

Guarda la keystore y las contraseñas en **dos lugares**:
1. Google Drive personal (carpeta privada)
2. USB físico guardado en lugar seguro

**Si pierdes la keystore, las instalaciones existentes NO pueden actualizarse** — habría que publicar como app nueva.

### 3. key.properties (no se sube al repo)

Crea `mobile/android/key.properties`:

```
storeFile=../../pr-release.jks
storePassword=<tu-contraseña-de-store>
keyAlias=pr
keyPassword=<tu-contraseña-de-key>
```

El `storeFile` es relativo al directorio `mobile/android/app/`.

### 4. Firebase Storage — bucket público para downloads

El bucket de Firebase del proyecto es `pr-app-efa2f.appspot.com`.
Los APKs se suben a `gs://pr-app-efa2f.appspot.com/downloads/`.

El script `release-apk.ps1` despliega también `storage.rules` que permite
lecturas públicas en `/downloads/**`. Solo necesitas hacer esto una vez:

```powershell
firebase deploy --only storage
```

---

## Publicar una nueva versión

1. Incrementa `version` en `mobile/pubspec.yaml` (ej. `1.0.1+2`)
2. Corre el script de release desde la raíz del proyecto:

```powershell
.\scripts\release-apk.ps1 -Notes "• Descripción del cambio"

# Para marcar la versión como forzada (bloquea builds anteriores):
.\scripts\release-apk.ps1 -Notes "• Fix crítico" -MinSupported <nuevo_build>
```

3. Commitea el manifest actualizado:

```powershell
git add public/app-version.json
git commit -m "chore: release v1.0.1"
git push
```

El CI auto-deploya la PWA y el `app-version.json` actualizado junto con el commit.

---

## Arquitectura de distribución

```
Firebase Hosting (pr-app-efa2f.web.app)
  └─ /app-version.json  ← desde public/ del repo, siempre actualizado por CI

Firebase Storage (pr-app-efa2f.appspot.com)
  └─ /downloads/pr-{version}.apk  ← APKs firmados, persistentes entre CI deploys
```

El APK en Storage NO se borra cuando CI auto-deploya el código.
El manifest en Hosting SÍ se actualiza automáticamente con cada push.

---

## Verificar firma del APK

```powershell
# Desde mobile/
flutter build apk --release
& "$env:ANDROID_HOME\build-tools\<version>\apksigner.bat" verify `
  --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

## Regla de oro sobre min_supported_build

Solo sube `min_supported_build` cuando hay un cambio **incompatible**:
- Migración de esquema SQLite que rompe datos locales
- Cambio de API Supabase que rompe clientes viejos
- Fix de seguridad crítico

Un `min_supported_build` incorrecto bloquea a **todos** los usuarios sin red.
