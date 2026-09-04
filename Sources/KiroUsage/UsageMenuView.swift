import AppKit
import KiroUsageKit
import SwiftUI

struct UsageMenuView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginManager
    @AppStorage(MenuBarPreferences.iconOnlyKey) private var iconOnly = false
    @AppStorage(MenuBarPreferences.alertThresholdKey(for: 50)) private var alertAt50 = false
    @AppStorage(MenuBarPreferences.alertThresholdKey(for: 75)) private var alertAt75 = false
    @AppStorage(MenuBarPreferences.alertThresholdKey(for: 90)) private var alertAt90 = false
    @AppStorage(MenuBarPreferences.alertThresholdKey(for: 100)) private var alertAt100 = false
    private let alertManager = UsageAlertManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let snapshot = store.snapshot {
                usageContent(snapshot)
            } else if store.isLoading {
                loadingContent
            } else {
                emptyContent
            }

            if let error = store.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = launchAtLogin.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)

                Spacer()

                Menu {
                    Button("Abrir conta do Kiro", action: store.openAccount)
                    Button("Abrir aplicativo Kiro", action: store.openKiro)
                    Divider()
                    Toggle(
                        "Iniciar automaticamente com o macOS",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )
                    Toggle("Mostrar somente o ícone na barra de menus", isOn: $iconOnly)
                    Divider()
                    Menu("Alertar ao ultrapassar") {
                        Toggle("50%", isOn: $alertAt50)
                        Toggle("75%", isOn: $alertAt75)
                        Toggle("90%", isOn: $alertAt90)
                        Toggle("100%", isOn: $alertAt100)
                    }
                    .onChange(of: alertAt50) { _, isOn in requestAuthorizationIfNeeded(isOn) }
                    .onChange(of: alertAt75) { _, isOn in requestAuthorizationIfNeeded(isOn) }
                    .onChange(of: alertAt90) { _, isOn in requestAuthorizationIfNeeded(isOn) }
                    .onChange(of: alertAt100) { _, isOn in requestAuthorizationIfNeeded(isOn) }
                    Divider()
                    Button("Encerrar Kiro Usage") { NSApplication.shared.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(18)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Kiro Usage")
                    .font(.headline)
                Text(store.snapshot?.planName ?? "Monitor de créditos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func usageContent(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(UsageStore.format(snapshot.used))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("de \(UsageStore.format(snapshot.limit)) créditos")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ProgressView(value: snapshot.progress)
                .tint(progressColor(snapshot.progress))

            HStack {
                metric(title: "Restantes", value: UsageStore.format(snapshot.remaining))
                Spacer()
                metric(title: "Consumido", value: snapshot.progress.formatted(.percent.precision(.fractionLength(0))))
                if snapshot.overages > 0 {
                    Spacer()
                    metric(title: "Adicionais", value: UsageStore.format(snapshot.overages))
                }
            }

            if let allowed = snapshot.allowedUsageThroughToday(),
               let difference = snapshot.paceDifference() {
                paceCard(allowed: allowed, difference: difference)
            }

            if let resetDate = snapshot.resetDate {
                Label {
                    Text("Renova em \(UsageFormatter.resetDateString(resetDate))")
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let lastUpdated = store.lastUpdated {
                Text("Atualizado \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var loadingContent: some View {
        HStack {
            Spacer()
            ProgressView("Consultando o Kiro…")
            Spacer()
        }
        .frame(height: 100)
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conecte sua conta do Kiro")
                .font(.headline)
            Text("Abra o aplicativo Kiro IDE e faça login. Uma sessão ativa somente no site app.kiro.dev não cria a credencial local necessária.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Abrir Kiro", action: store.openKiro)
                .buttonStyle(.borderedProminent)
        }
    }

    private func requestAuthorizationIfNeeded(_ isOn: Bool) {
        guard isOn else { return }
        Task { await alertManager.requestAuthorizationIfNeeded() }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func paceCard(allowed: Double, difference: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: paceSymbol(difference))
                .foregroundStyle(paceColor(difference))

            VStack(alignment: .leading, spacing: 3) {
                Text("Até hoje: \(UsageStore.format(allowed)) créditos")
                    .font(.callout.weight(.medium))
                Text(paceDescription(difference))
                    .font(.caption)
                    .foregroundStyle(difference > 0 ? .orange : .secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
    }

    private func paceDescription(_ difference: Double) -> String {
        if abs(difference) < 0.01 {
            return "Exatamente no ritmo mensal"
        }
        if difference > 0 {
            return "\(UsageStore.format(difference)) acima do ritmo mensal"
        }
        return "\(UsageStore.format(abs(difference))) abaixo do ritmo mensal"
    }

    private func paceSymbol(_ difference: Double) -> String {
        if difference > 0.01 { return "arrow.up.circle.fill" }
        if difference < -0.01 { return "arrow.down.circle.fill" }
        return "equal.circle.fill"
    }

    private func paceColor(_ difference: Double) -> Color {
        if difference > 0.01 { return .orange }
        if difference < -0.01 { return .green }
        return .secondary
    }

    private func progressColor(_ progress: Double) -> Color {
        switch progress {
        case ..<0.8: return .purple
        case ..<1: return .orange
        default: return .red
        }
    }
}
