import Combine
import Foundation

@MainActor
final class NetworkViewModel: ObservableObject {
    @Published private(set) var services: [NetworkService] = []
    @Published private(set) var preferredPriority: NetworkPriority?
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?

    private let serviceManager: NetworkServiceManager

    convenience init() {
        self.init(serviceManager: NetworkServiceManager())
    }

    init(serviceManager: NetworkServiceManager) {
        self.serviceManager = serviceManager
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
        services.contains(where: { $0.kind == .ethernet })
    }

    var canPrioritizeWiFi: Bool {
        services.contains(where: { $0.kind == .wifi })
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
