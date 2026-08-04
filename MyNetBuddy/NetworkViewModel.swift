import Combine
import Foundation

@MainActor
final class NetworkViewModel: ObservableObject {
    @Published private(set) var services: [NetworkService] = []
    @Published private(set) var preferredPriority: NetworkPriority?
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var measuredDownloadMbps: Double?
    @Published private(set) var speedMeasuredAt: Date?
    @Published private(set) var isMeasuringSpeed = false

    private let serviceManager: NetworkServiceManager
    private var refreshTimer: Timer?

    convenience init() {
        self.init(serviceManager: NetworkServiceManager())
    }

    init(serviceManager: NetworkServiceManager) {
        self.serviceManager = serviceManager
    }

    func startAutoRefresh(interval: TimeInterval = 5) {
        refresh()
        guard refreshTimer == nil else {
            return
        }
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func measureDownloadSpeed() {
        guard !isMeasuringSpeed else {
            return
        }
        isMeasuringSpeed = true
        Task { [weak self] in
            guard let self else {
                return
            }
            let result = await self.serviceManager.measureDownloadMbps()
            self.measuredDownloadMbps = result
            self.speedMeasuredAt = Date()
            self.isMeasuringSpeed = false
        }
    }

    var menuBarIconName: String {
        switch preferredPriority {
        case .ethernet:
            return "cable.connector"
        case .wifi:
            return "wifi"
        case .none:
            return "network"
        }
    }

    var canPrioritizeEthernet: Bool {
        hasActiveEthernet && hasActiveWiFi
    }

    var canPrioritizeWiFi: Bool {
        hasActiveEthernet && hasActiveWiFi
    }

    var hasActiveEthernet: Bool {
        services.contains(where: { $0.kind == .ethernet && $0.isEnabled })
    }

    var hasActiveWiFi: Bool {
        services.contains(where: { $0.kind == .wifi && $0.isEnabled })
    }

    var priorityServices: [NetworkService] {
        let ethernet = activeFirst(services.filter { $0.kind == .ethernet }).first
        let wifi = activeFirst(services.filter { $0.kind == .wifi }).first
        return [ethernet, wifi].compactMap { $0 }
    }

    var otherServices: [NetworkService] {
        let primaryIDs = Set(priorityServices.map(\.id))
        return activeFirst(services.filter { !primaryIDs.contains($0.id) })
    }

    private func activeFirst(_ services: [NetworkService]) -> [NetworkService] {
        services.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled {
                return lhs.isEnabled
            }
            return lhs.order < rhs.order
        }
    }

    func refresh() {
        do {
            let snapshot = try serviceManager.fetchSnapshot()
            services = snapshot.services
            preferredPriority = snapshot.preferredPriority
            statusMessage = "Estado actualizado."
            errorMessage = nil
        } catch {
            services = []
            preferredPriority = nil
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func prioritize(_ priority: NetworkPriority) {
        do {
            let snapshot = try serviceManager.prioritize(priority)
            services = snapshot.services
            preferredPriority = snapshot.preferredPriority
            statusMessage = priority == .ethernet
                ? "Ethernet quedó al frente del orden de servicios."
                : "Wi-Fi quedó al frente del orden de servicios."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension NetworkViewModel {
    static var preview: NetworkViewModel {
        let viewModel = NetworkViewModel(serviceManager: NetworkServiceManager())
        viewModel.services = [
            NetworkService(
                id: "Ethernet",
                displayName: "Ethernet",
                device: "en7",
                hardwarePort: "USB-C Ethernet",
                kind: .ethernet,
                order: 1,
                isEnabled: true,
                ipAddress: "192.168.1.20",
                linkDescription: "Cable conectado",
                detailSummary: "Interfaz cableada lista para priorizar.",
                isCurrentTopPriority: true
            ),
            NetworkService(
                id: "Wi-Fi",
                displayName: "Wi-Fi",
                device: "en0",
                hardwarePort: "Wi-Fi",
                kind: .wifi,
                order: 2,
                isEnabled: true,
                ipAddress: "192.168.1.15",
                linkDescription: "866 Mbps",
                detailSummary: "SSID Oficina  ·  RSSI -48  ·  Noise -92",
                isCurrentTopPriority: false
            )
        ]
        viewModel.preferredPriority = .ethernet
        viewModel.statusMessage = "Preview cargado."
        return viewModel
    }
}
