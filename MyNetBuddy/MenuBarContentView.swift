import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: NetworkViewModel
    @State private var refreshRotation = 0.0
    @State private var showOtherServices = false

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
                Button {
                    refreshRotation += 360
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshRotation))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: refreshRotation)
                }
                .buttonStyle(.borderless)
                .help("Actualizar estado")
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
                    guard viewModel.canPrioritizeEthernet else { return }
                    viewModel.prioritize(.ethernet)
                } label: {
                    priorityButtonLabel(
                        title: "Ethernet primero",
                        icon: "cable.connector",
                        isSelected: viewModel.preferredPriority == .ethernet,
                        isHighlighted: viewModel.preferredPriority == .ethernet
                            || (viewModel.hasActiveEthernet && !viewModel.hasActiveWiFi),
                        isActive: viewModel.hasActiveEthernet,
                        inactiveText: "Sin cable"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard viewModel.canPrioritizeWiFi else { return }
                    viewModel.prioritize(.wifi)
                } label: {
                    priorityButtonLabel(
                        title: "Wi-Fi primero",
                        icon: "wifi",
                        isSelected: viewModel.preferredPriority == .wifi,
                        isHighlighted: viewModel.preferredPriority == .wifi
                            || (viewModel.hasActiveWiFi && !viewModel.hasActiveEthernet),
                        isActive: viewModel.hasActiveWiFi,
                        inactiveText: "No conectada"
                    )
                }
                .buttonStyle(.plain)
            }

            if !viewModel.canPrioritizeEthernet {
                Text("Requerís Ethernet y Wi-Fi activos.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func priorityButtonLabel(
        title: String,
        icon: String,
        isSelected: Bool,
        isHighlighted: Bool,
        isActive: Bool,
        inactiveText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isHighlighted ? Color.accentColor : .primary)
            Text(statusText(isSelected: isSelected, isActive: isActive, inactiveText: inactiveText))
                .font(.caption.weight(.medium))
                .foregroundStyle(isHighlighted ? Color.accentColor : (isSelected ? .primary : .secondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isHighlighted ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isHighlighted ? 1 : (isActive ? 0.8 : 0.4))
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
                Text("No se encontraron servicios de red.")
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
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showOtherServices.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showOtherServices ? 90 : 0))
                    Text("Otras interfaces (\(viewModel.otherServices.count))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showOtherServices {
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
            }
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
                        Label {
                            Text(viewModel.isMeasuringSpeed ? "Midiendo…" : "Medir velocidad")
                        } icon: {
                            if viewModel.isMeasuringSpeed {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "gauge.with.dots.needle.67percent")
                            }
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isMeasuringSpeed)
                    .help("Medir la velocidad real de descarga")
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
            Spacer()
            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .help("Cerrar MyNetBuddy")
        }
    }
}

struct MenuBarContentView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContentView(viewModel: NetworkViewModel.preview)
    }
}
