import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetworkViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            priorityControls
            servicesSection
            footer
        }
        .padding(16)
        .onAppear {
            viewModel.startAutoRefresh()
            if viewModel.measuredDownloadMbps == nil
                || Date().timeIntervalSince(viewModel.speedMeasuredAt ?? .distantPast) > 60
            {
                viewModel.measureDownloadSpeed()
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("MyNetBuddy", systemImage: "network")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    viewModel.refresh()
                }
                .buttonStyle(.borderless)
            }

            Text("Elegi qué conexión querés priorizar y revisá el estado actual de cada interfaz.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var priorityControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prioridad")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    viewModel.prioritize(.ethernet)
                } label: {
                    priorityButtonLabel(
                        title: "Ethernet primero",
                        icon: "cable.connector",
                        isSelected: viewModel.preferredPriority == .ethernet,
                        isActive: viewModel.hasActiveEthernet,
                        inactiveText: "Sin cable"
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPrioritizeEthernet)

                Button {
                    viewModel.prioritize(.wifi)
                } label: {
                    priorityButtonLabel(
                        title: "Wi-Fi primero",
                        icon: "wifi",
                        isSelected: viewModel.preferredPriority == .wifi,
                        isActive: viewModel.hasActiveWiFi,
                        inactiveText: "No conectada"
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPrioritizeWiFi)
            }

            if !viewModel.canPrioritizeEthernet {
                Text("Para elegir la prioridad, Ethernet y Wi-Fi deben estar ambos activos.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func priorityButtonLabel(
        title: String,
        icon: String,
        isSelected: Bool,
        isActive: Bool,
        inactiveText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(statusText(isSelected: isSelected, isActive: isActive, inactiveText: inactiveText))
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isActive || isSelected ? 1 : 0.6)
    }

    private func statusText(isSelected: Bool, isActive: Bool, inactiveText: String) -> String {
        if isSelected {
            return "Activa"
        }
        if !isActive {
            return inactiveText
        }
        return "Disponible"
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Interfaces")
                    .font(.headline)
                Spacer()
                Text(viewModel.services.isEmpty ? "Sin datos" : "\(viewModel.services.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.services.isEmpty {
                Text("Todavia no encontramos servicios de red. Tocá Refresh para volver a cargar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.priorityServices) { service in
                    serviceCard(service)
                }
                if !viewModel.otherServices.isEmpty {
                    otherServicesSection
                }
            }
        }
    }

    private var otherServicesSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.otherServices) { service in
                    HStack(spacing: 8) {
                        Label(service.displayName, systemImage: service.kind.iconName)
                            .font(.caption)
                        Spacer()
                        Text(service.device.isEmpty ? "Sin enlace" : service.device)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 4)
        } label: {
            Text("Otras interfaces (\(viewModel.otherServices.count))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func serviceCard(_ service: NetworkService) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Label(service.displayName, systemImage: service.kind.iconName)
                            .font(.subheadline.weight(.semibold))
                        if service.isCurrentTopPriority {
                            Text("Prioridad")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text("Device \(service.device)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("#\(service.order)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                metric(title: "Estado", value: service.statusLabel)
                metric(title: "IP", value: service.ipAddress ?? "N/D")
                if service.kind == .wifi {
                    metric(
                        title: "Descarga",
                        value: viewModel.isMeasuringSpeed ? "Midiendo…" : speedLabel(viewModel.measuredDownloadMbps)
                    )
                } else {
                    metric(title: "Velocidad", value: service.linkDescription)
                }
            }

            if let details = service.detailSummary {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if service.kind == .wifi {
                HStack(spacing: 8) {
                    Button {
                        viewModel.measureDownloadSpeed()
                    } label: {
                        Label(
                            viewModel.isMeasuringSpeed ? "Midiendo…" : "Medir velocidad",
                            systemImage: viewModel.isMeasuringSpeed ? "arrow.triangle.2.circlepath" : "gauge.with.dots.needle.67percent"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isMeasuringSpeed)
                    if let measuredAt = viewModel.speedMeasuredAt {
                        Text("Medida \(relativeTime(measuredAt))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(service.isEnabled ? Color.gray.opacity(0.08) : Color.gray.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(service.isEnabled ? 1 : 0.55)
    }

    private func speedLabel(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        if value < 10 {
            return String(format: "%.1f Mbps", value)
        }
        return String(format: "%.0f Mbps", value)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(max(interval, 0))) ?? "ahora"
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text("Cambiar la prioridad puede pedir permisos de macOS.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView(viewModel: NetworkViewModel.preview)
    }
}
