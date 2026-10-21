import KiroUsageKit
import SwiftUI
import WidgetKit

struct UsageWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if let snapshot = entry.payload?.snapshot {
            content(for: snapshot)
        } else {
            emptyContent
        }
    }

    private func content(for snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
                Text(snapshot.planName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if let resetDate = snapshot.resetDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text(UsageFormatter.resetDateShortString(resetDate))
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(UsageFormatter.format(snapshot.used))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("/\(UsageFormatter.format(snapshot.limit))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: snapshot.progress)
                .tint(progressColor(snapshot.progress))
                .padding(.top, 1)

            if let difference = snapshot.paceDifference() {
                paceRow(difference: difference, snapshot: snapshot)
                    .padding(.top, 2)
            }

            HStack(spacing: 4) {
                Text("\(UsageFormatter.format(snapshot.remaining)) restantes")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(snapshot.progress.formatted(.percent.precision(.fractionLength(0))))
                    .fontWeight(.semibold)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
    }

    private func paceRow(difference: Double, snapshot: UsageSnapshot) -> some View {
        let color = paceColor(snapshot)
        let isOnPace = abs(difference) < 0.01

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: paceSymbol(snapshot))
                    .font(.system(size: 14))
                if !isOnPace {
                    Text(UsageFormatter.format(abs(difference)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(color)

            Text(paceCaption(difference))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func paceCaption(_ difference: Double) -> String {
        if abs(difference) < 0.01 { return "no ritmo mensal" }
        return difference > 0 ? "acima do ritmo mensal" : "abaixo do ritmo mensal"
    }

    private var emptyContent: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.purple)
            Text("Abra o Kiro Usage")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func paceSymbol(_ snapshot: UsageSnapshot) -> String {
        switch snapshot.paceStatus() {
        case .belowLimit: return "arrow.down.circle.fill"
        case .onLimit: return "equal.circle.fill"
        case .overLimit: return "arrow.up.circle.fill"
        case nil: return "sparkles"
        }
    }

    private func paceColor(_ snapshot: UsageSnapshot) -> Color {
        switch snapshot.paceStatus() {
        case .belowLimit: return .green
        case .onLimit: return .secondary
        case .overLimit: return .orange
        case nil: return .secondary
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        switch progress {
        case ..<0.8: return .purple
        case ..<1: return .orange
        default: return .red
        }
    }
}
