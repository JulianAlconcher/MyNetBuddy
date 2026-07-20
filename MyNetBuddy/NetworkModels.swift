import Foundation

enum NetworkPriority: String {
    case ethernet
    case wifi
}

enum NetworkServiceKind: String {
    case ethernet
    case wifi
    case other

    var iconName: String {
        switch self {
        case .ethernet:
            return "cable.connector"
        case .wifi:
            return "wifi"
        case .other:
            return "network"
        }
    }
}

struct NetworkService: Identifiable, Equatable {
    let id: String
    let displayName: String
    let device: String
    let hardwarePort: String
    let kind: NetworkServiceKind
    let order: Int
    let isEnabled: Bool
    let ipAddress: String?
    let linkDescription: String
    let detailSummary: String?
    let isCurrentTopPriority: Bool

    var statusLabel: String {
        isEnabled ? "Activa" : "Inactiva"
    }
}
