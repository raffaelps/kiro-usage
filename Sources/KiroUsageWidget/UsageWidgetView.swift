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
                Spacer(minLength: 4)
                Image(systemName: paceSymbol(snapshot))
                    .font(.system(size: 11))
                    .foregroundStyle(paceColor(snapshot))
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

            HStack(spacing: 4) {
                Text("\(UsageFormatter.format(snapshot.remaining)) restantes")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(snapshot.progress.formatted(.percent.precision(.fractionLength(0))))
                    .fontWeight(.semibold)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            if let resetDate = snapshot.resetDate {
                Label {
                    Text(UsageFormatter.resetDateString(resetDate))
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
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
