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
        .task {
            viewModel.refresh()
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
                        isSelected: viewModel.preferredPriority == .ethernet
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
                        isSelected: viewModel.preferredPriority == .wifi
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canPrioritizeWiFi)
            }
        }
    }

    private func priorityButtonLabel(title: String, icon: String, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            Text(isSelected ? "Activa" : "Disponible")
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                ForEach(viewModel.services) { service in
                    serviceCard(service)
                }
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
                metric(title: "Velocidad", value: service.linkDescription)
            }

            if let details = service.detailSummary {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
