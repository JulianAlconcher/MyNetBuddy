# MyNetBuddy

App de macOS en la barra de menú que muestra el estado de tus interfaces de red, permite elegir la prioridad entre Ethernet y Wi-Fi, y mide la velocidad real de descarga.

## Funcionalidades

- **Prioridad de red**: elegí si Ethernet o Wi-Fi va primero cuando ambos están activos.
- **Estado en vivo**: estado, IP y velocidad de cada interfaz, actualizado cada 5 segundos mientras el menú está abierto.
- **Velocidad real**: mide el throughput de bajada descargando desde el endpoint público de Cloudflare durante ~5 segundos (estilo fast.com), mostrado como dato principal junto a la velocidad de enlace PHY como secundario.
- **Interfaz minimalista**: solo Ethernet y Wi-Fi se muestran como tarjetas; el resto de las interfaces quedan colapsadas en "Otras interfaces".

## Requisitos

- macOS 14 o posterior
- Xcode 16 o posterior

## Compilar y ejecutar

```bash
open MyNetBuddy.xcodeproj
```

O desde la terminal:

```bash
xcodebuild -project MyNetBuddy.xcodeproj -scheme MyNetBuddy -configuration Debug build
open "$(xcodebuild -project MyNetBuddy.xcodeproj -scheme MyNetBuddy -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/MyNetBuddy.app"
```

## Cómo funciona

- La prioridad se cambia reordenando el orden de servicios de red con `networksetup -ordernetworkservices` (puede pedir permisos de macOS).
- La velocidad real se mide con `URLSession` descargando de `https://speed.cloudflare.com/__down` y calculando bytes/segundo.
- Los datos de Wi-Fi (enlace, RSSI, ruido) vienen de CoreWLAN.

## Estructura

- `MyNetBuddy/NetworkModels.swift` — modelos (`NetworkService`, `NetworkServiceKind`, `NetworkPriority`).
- `MyNetBuddy/NetworkServiceManager.swift` — parser de `networksetup`, clasificación de interfaces, medición de velocidad.
- `MyNetBuddy/NetworkViewModel.swift` — estado publicado y lógica de presentación.
- `MyNetBuddy/MenuBarContentView.swift` — la interfaz del menú.
- `MyNetBuddy/MyNetBuddyApp.swift` — entry point (`MenuBarExtra`).
