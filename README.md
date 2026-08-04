<h1 align="center" style="border-bottom: none">
  <div>
    MyNetBuddy
  </div>
</h1>
<h3 align="center">
  Tu red, con prioridad y velocidad real, desde la barra de menú
</h3>
<p align="center">
  <a href="https://github.com/JulianAlconcher/MyNetBuddy">
    <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-blue">
  </a>
  <a href="https://github.com/JulianAlconcher/MyNetBuddy">
    <img alt="Language" src="https://img.shields.io/badge/language-Swift-orange">
  </a>
  <a href="https://github.com/JulianAlconcher/MyNetBuddy">
    <img alt="Xcode" src="https://img.shields.io/badge/Xcode-16%2B-147EFB">
  </a>
</p>
<p>
MyNetBuddy es una app de macOS que vive en la barra de menú. Te deja elegir qué conexión priorizar (Ethernet o Wi-Fi) cuando ambas están activas, revisar el estado de cada interfaz en tiempo real y medir la velocidad real de descarga, estilo fast.com.
</p>
<h2 align="center">
  <a href="https://github.com/JulianAlconcher/MyNetBuddy">✨ Ver en GitHub</a>
</h2>


## Features
- Prioridad de red con un toque: Ethernet primero o Wi-Fi primero
- Estado en vivo de cada interfaz (IP, enlace, RSSI, ruido), actualizado cada 5 segundos
- Medición de velocidad real de bajada descargando desde Cloudflare (~5s, estilo fast.com)
- Interfaz minimalista: solo Ethernet y Wi-Fi en grande, el resto colapsado
- Refresco automático mientras el menú está abierto

## Cómo funciona

- La prioridad se cambia reordenando los servicios de red con `networksetup -ordernetworkservices` (puede pedir permisos de macOS).
- La velocidad real se mide con `URLSession` descargando de `https://speed.cloudflare.com/__down` y calculando bytes/segundo.
- Los datos de Wi-Fi (enlace, RSSI, ruido) vienen de CoreWLAN.

## Build & Run

Requisitos: macOS 14+ y Xcode 16+.

```sh
open MyNetBuddy.xcodeproj
```

O desde la terminal:

```sh
xcodebuild -project MyNetBuddy.xcodeproj -scheme MyNetBuddy -configuration Debug build
open "$(xcodebuild -project MyNetBuddy.xcodeproj -scheme MyNetBuddy -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/{print $3}')/MyNetBuddy.app"
```

## Structure

|Archivo|Rol|
|:--|:--|
| `MyNetBuddy/NetworkModels.swift` | Modelos: `NetworkService`, `NetworkServiceKind`, `NetworkPriority` |
| `MyNetBuddy/NetworkServiceManager.swift` | Parser de `networksetup`, clasificación de interfaces, medición de velocidad |
| `MyNetBuddy/NetworkViewModel.swift` | Estado publicado y lógica de presentación |
| `MyNetBuddy/MenuBarContentView.swift` | La interfaz del menú |
| `MyNetBuddy/MyNetBuddyApp.swift` | Entry point (`MenuBarExtra`) |


## License

Distributed under the MIT License. See `LICENSE` for more information.
