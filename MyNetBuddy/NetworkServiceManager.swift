import Foundation

struct NetworkSnapshot {
    let services: [NetworkService]
    let preferredPriority: NetworkPriority?
}

enum NetworkServiceError: LocalizedError {
    case commandFailed(String)
    case missingServices

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .missingServices:
            return "No se encontraron servicios de red configurados."
        }
    }
}

final class NetworkServiceManager {
    func fetchSnapshot() throws -> NetworkSnapshot {
        if let orderedServices = try? fetchOrderedServicesFromNetworkSetup(), !orderedServices.isEmpty {
            return snapshot(from: orderedServices)
        }

        let fallbackServices = parseInterfacesFromIfconfig()
        guard !fallbackServices.isEmpty else {
            throw NetworkServiceError.missingServices
        }

        return snapshot(from: fallbackServices)
    }

    func prioritize(_ priority: NetworkPriority) throws -> NetworkSnapshot {
        let orderedServices = try fetchOrderedServicesForPrioritization()
        let reordered = reorder(parsedServices: orderedServices, priority: priority)
        let updatedOrderOutput = try reorderAndFetchOrder(serviceNames: reordered.map(\.displayName))
        let updatedServices = parseServiceOrder(from: updatedOrderOutput)

        guard !updatedServices.isEmpty else {
            throw NetworkServiceError.missingServices
        }

        return snapshot(from: updatedServices)
    }

    private func fetchOrderedServicesFromNetworkSetup() throws -> [ParsedService] {
        let orderOutput: String

        orderOutput = try runNetworkSetup(arguments: ["-listnetworkserviceorder"])

        return parseServiceOrder(from: orderOutput)
    }

    private func snapshot(from parsedServices: [ParsedService]) -> NetworkSnapshot {
        let preferredKind = preferredPriority(from: parsedServices)

        let services = parsedServices.enumerated().map { index, parsed in
            let ipAddress = currentIPAddress(for: parsed.device)
            let linkDescription = linkSpeedDescription(for: parsed.device, kind: parsed.kind)
            let detailSummary = detailSummary(for: parsed.device, kind: parsed.kind)

            return NetworkService(
                id: parsed.displayName,
                displayName: parsed.displayName,
                device: parsed.device,
                hardwarePort: parsed.hardwarePort,
                kind: parsed.kind,
                order: index + 1,
                isEnabled: ipAddress != nil,
                ipAddress: ipAddress,
                linkDescription: linkDescription,
                detailSummary: detailSummary,
                isCurrentTopPriority: index == 0
            )
        }

        let preferredPriority = preferredKind

        return NetworkSnapshot(services: services, preferredPriority: preferredPriority)
    }

    private func reorder(serviceNames: [String], using services: [NetworkService], priority: NetworkPriority) -> [String] {
        let matchingNames = services
            .filter { service in
                switch priority {
                case .ethernet:
                    return service.kind == .ethernet
                case .wifi:
                    return service.kind == .wifi
                }
            }
            .map(\.displayName)

        let remainingNames = serviceNames.filter { !matchingNames.contains($0) }
        return matchingNames + remainingNames
    }

    private func currentIPAddress(for device: String) -> String? {
        let output = runQuietCommand(launchPath: "/usr/sbin/ipconfig", arguments: ["getifaddr", device])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func linkSpeedDescription(for device: String, kind: NetworkServiceKind) -> String {
        switch kind {
        case .ethernet:
            let output = runQuietCommand(launchPath: "/sbin/ifconfig", arguments: [device])
            if output.contains("status: active") {
                return "Cable conectado"
            }
            return "Sin enlace"
        case .wifi:
            let airportOutput = runQuietCommand(
                launchPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
                arguments: ["-I"]
            )
            if let rateLine = airportOutput
                .split(separator: "\n")
                .first(where: { $0.localizedCaseInsensitiveContains("lastTxRate") }) {
                let value = rateLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                return value.isEmpty ? "Wi-Fi detectado" : "\(value) Mbps"
            }
            return "Wi-Fi detectado"
        case .other:
            return "Interfaz disponible"
        }
    }

    private func detailSummary(for device: String, kind: NetworkServiceKind) -> String? {
        switch kind {
        case .wifi:
            let airportOutput = runQuietCommand(
                launchPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
                arguments: ["-I"]
            )
            let ssid = airportValue(named: "SSID", in: airportOutput)
            let bssid = airportValue(named: "BSSID", in: airportOutput)
            let noise = airportValue(named: "agrCtlNoise", in: airportOutput)
            let rssi = airportValue(named: "agrCtlRSSI", in: airportOutput)
            var pieces: [String] = []
            if let ssid {
                pieces.append("SSID \(ssid)")
            }
            if let bssid {
                pieces.append("BSSID \(bssid)")
            }
            if let rssi {
                pieces.append("RSSI \(rssi)")
            }
            if let noise {
                pieces.append("Noise \(noise)")
            }
            return pieces.isEmpty ? nil : pieces.joined(separator: "  ·  ")
        case .ethernet:
            let output = runQuietCommand(launchPath: "/sbin/ifconfig", arguments: [device])
            if output.contains("status: active") {
                return "Interfaz cableada lista para priorizar."
            }
            return "Conecta un cable para que esta interfaz entre en uso."
        case .other:
            return nil
        }
    }

    private func airportValue(named key: String, in output: String) -> String? {
        output
            .split(separator: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") })?
            .split(separator: ":", maxSplits: 1)
            .last?
            .trimmingCharacters(in: .whitespaces)
    }

    private func parseServiceOrder(from output: String) -> [ParsedService] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var services: [ParsedService] = []

        for index in lines.indices {
            let line = lines[index]
            guard line.hasPrefix("("), index + 1 < lines.count else {
                continue
            }

            let displayName = lineName(from: line)

            let detailLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
            guard detailLine.hasPrefix("Hardware Port:") else {
                continue
            }

            let components = detailLine
                .replacingOccurrences(of: "Hardware Port:", with: "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard components.count >= 2 else {
                continue
            }

            let hardwarePort = components[0]
            let device = components[1].replacingOccurrences(of: "Device: ", with: "")

            services.append(
                ParsedService(
                    displayName: displayName.isEmpty ? hardwarePort : displayName,
                    hardwarePort: hardwarePort,
                    device: device,
                    kind: classify(hardwarePort: hardwarePort)
                )
            )
        }

        return services
    }

    private func parseInterfacesFromIfconfig() -> [ParsedService] {
        let output = runQuietCommand(launchPath: "/sbin/ifconfig", arguments: [])
        let blocks = output.components(separatedBy: "\n")

        var services: [ParsedService] = []
        var currentDevice: String?
        var currentLines: [String] = []

        func flushCurrentBlock() {
            guard let device = currentDevice else {
                return
            }

            let details = currentLines.joined(separator: "\n")
            guard shouldIncludeInterface(device: device, details: details) else {
                return
            }

            let kind = classify(device: device, details: details)
            services.append(
                ParsedService(
                    displayName: displayName(for: device, kind: kind),
                    hardwarePort: hardwarePortName(for: device, kind: kind),
                    device: device,
                    kind: kind
                )
            )
        }

        for line in blocks {
            if !line.isEmpty, !line.hasPrefix("\t"), let colonIndex = line.firstIndex(of: ":") {
                flushCurrentBlock()
                currentDevice = String(line[..<colonIndex])
                currentLines = [line]
            } else {
                currentLines.append(line)
            }
        }

        flushCurrentBlock()

        let activeServices = services
            .filter { currentIPAddress(for: $0.device) != nil }
            .sorted(by: fallbackPrioritySort)
        let inactiveServices = services
            .filter { currentIPAddress(for: $0.device) == nil }
            .sorted(by: fallbackPrioritySort)
        return activeServices + inactiveServices
    }

    private func fetchOrderedServicesForPrioritization() throws -> [ParsedService] {
        let orderedServices: [ParsedService]

        if let services = try? fetchOrderedServicesFromNetworkSetup(), !services.isEmpty {
            orderedServices = services
        } else {
            let orderOutput = try runPrivilegedNetworkSetup(arguments: ["-listnetworkserviceorder"])
            orderedServices = parseServiceOrder(from: orderOutput)
        }

        guard !orderedServices.isEmpty else {
            throw NetworkServiceError.missingServices
        }

        return orderedServices
    }

    private func preferredPriority(from services: [ParsedService]) -> NetworkPriority? {
        for service in services {
            switch service.kind {
            case .ethernet:
                return .ethernet
            case .wifi:
                return .wifi
            case .other:
                continue
            }
        }
        return nil
    }

    private func lineName(from line: String) -> String {
        guard let closingParenIndex = line.firstIndex(of: ")") else {
            return line.trimmingCharacters(in: .whitespaces)
        }

        let nameStart = line.index(after: closingParenIndex)
        return String(line[nameStart...]).trimmingCharacters(in: .whitespaces)
    }

    private func classify(hardwarePort: String) -> NetworkServiceKind {
        let lowercased = hardwarePort.lowercased()
        if lowercased.contains("wi-fi") || lowercased.contains("wifi") || lowercased.contains("air") {
            return .wifi
        }
        if lowercased.contains("ethernet") || lowercased.contains("lan") || lowercased.contains("thunderbolt bridge") {
            return .ethernet
        }
        return .other
    }

    private func classify(device: String, details: String) -> NetworkServiceKind {
        let lowercasedDevice = device.lowercased()
        let lowercasedDetails = details.lowercased()

        if lowercasedDevice == "en0" || lowercasedDetails.contains("wi-fi") || lowercasedDetails.contains("airport") {
            return .wifi
        }
        if lowercasedDevice.hasPrefix("en") {
            return .ethernet
        }
        return .other
    }

    private func shouldIncludeInterface(device: String, details: String) -> Bool {
        guard device.hasPrefix("en") else {
            return false
        }

        let lowercasedDetails = details.lowercased()
        return lowercasedDetails.contains("status: active") || lowercasedDetails.contains("inet ")
    }

    private func displayName(for device: String, kind: NetworkServiceKind) -> String {
        switch kind {
        case .wifi:
            return "Wi-Fi"
        case .ethernet:
            return device == "en7" ? "Ethernet" : "Ethernet \(device.uppercased())"
        case .other:
            return device.uppercased()
        }
    }

    private func hardwarePortName(for device: String, kind: NetworkServiceKind) -> String {
        switch kind {
        case .wifi:
            return "Wi-Fi"
        case .ethernet:
            return "Ethernet"
        case .other:
            return device.uppercased()
        }
    }

    private func fallbackPrioritySort(lhs: ParsedService, rhs: ParsedService) -> Bool {
        fallbackPriorityRank(lhs.kind) < fallbackPriorityRank(rhs.kind)
    }

    private func fallbackPriorityRank(_ kind: NetworkServiceKind) -> Int {
        switch kind {
        case .ethernet:
            return 0
        case .wifi:
            return 1
        case .other:
            return 2
        }
    }

    private func runNetworkSetup(arguments: [String]) throws -> String {
        let result = runCommand(launchPath: "/usr/sbin/networksetup", arguments: arguments)

        guard result.exitCode == 0 else {
            let reason = errorMessage(from: result, defaultMessage: "No se pudo ejecutar networksetup.")
            throw NetworkServiceError.commandFailed(reason.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result.stdout
    }

    private func runPrivilegedNetworkSetup(arguments: [String]) throws -> String {
        let command = (["/usr/sbin/networksetup"] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
        return try runPrivilegedShellCommand(command)
    }

    private func errorMessage(from result: CommandResult, defaultMessage: String) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }

        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return stdout
        }

        return defaultMessage
    }

    private func privilegedErrorMessage(from result: CommandResult, defaultMessage: String) -> String {
        let rawMessage = errorMessage(from: result, defaultMessage: defaultMessage)
        let lowercased = rawMessage.lowercased()

        if lowercased.contains("user canceled") || rawMessage.contains("(-128)") {
            return "Se canceló la autenticación de administrador."
        }

        if lowercased.contains("administrator user name or password") || rawMessage.contains("(-60005)") {
            return "El usuario o la contraseña de un administrador de macOS no son válidos."
        }

        if lowercased.contains("authorization was denied") {
            return "No se autorizó el acceso de administrador."
        }

        if lowercased.contains("not allowed assistive access") {
            return "macOS bloqueó la autorización. Probá abrir la app desde Xcode o revisá los permisos del sistema."
        }

        if lowercased.contains("wrong number of network services") {
            return "macOS rechazó el cambio porque faltaban servicios en el reordenamiento. Volvé a intentar con la versión actualizada."
        }

        return rawMessage
    }

    private func reorder(parsedServices: [ParsedService], priority: NetworkPriority) -> [ParsedService] {
        let prioritizedServices = parsedServices.filter { service in
            switch priority {
            case .ethernet:
                return service.kind == .ethernet
            case .wifi:
                return service.kind == .wifi
            }
        }
        let remainingServices = parsedServices.filter { service in
            !prioritizedServices.contains { $0.displayName == service.displayName }
        }
        return prioritizedServices + remainingServices
    }

    private func reorderAndFetchOrder(serviceNames: [String]) throws -> String {
        let reorderCommand = (["/usr/sbin/networksetup", "-ordernetworkservices"] + serviceNames)
            .map(shellEscaped)
            .joined(separator: " ")
        let listCommand = ["/usr/sbin/networksetup", "-listnetworkserviceorder"]
            .map(shellEscaped)
            .joined(separator: " ")

        return try runPrivilegedShellCommand("\(reorderCommand) && \(listCommand)")
    }

    private func runPrivilegedShellCommand(_ command: String) throws -> String {
        let script = "do shell script \(appleScriptString(command)) with administrator privileges"
        let result = runCommand(launchPath: "/usr/bin/osascript", arguments: ["-e", script])

        guard result.exitCode == 0 else {
            let defaultMessage = "No se pudo ejecutar el comando con permisos de administrador."
            let reason = privilegedErrorMessage(from: result, defaultMessage: defaultMessage)
            throw NetworkServiceError.commandFailed(reason.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result.stdout
    }

    private func shellEscaped(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptString(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func runQuietCommand(launchPath: String, arguments: [String]) -> String {
        let result = runCommand(launchPath: launchPath, arguments: arguments)
        return result.stdout
    }

    private func runCommand(launchPath: String, arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }
}

private struct ParsedService {
    let displayName: String
    let hardwarePort: String
    let device: String
    let kind: NetworkServiceKind
}

private struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}
