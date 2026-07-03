import SwiftUI
import WidgetKit

@main
struct SleeptabWidgetBundle: WidgetBundle {
    var body: some Widget {
        DebtWidget()
    }
}

private let bg = Color(red: 0.086, green: 0.098, blue: 0.145)
private let cream = Color(red: 1.0, green: 0.965, blue: 0.91)
private let accent = Color(red: 0.969, green: 0.718, blue: 0.20)

struct DebtSnapshot: TimelineEntry {
    let date: Date
    let summary: WidgetSummary?
    let isPro: Bool

    static let placeholder = DebtSnapshot(
        date: .now,
        summary: WidgetSummary(
            debt: 3.4 * 3600,
            nights: (1...7).map {
                Night(day: Calendar.current.date(byAdding: .day, value: -$0, to: .now)!,
                      asleep: (6.5 + Double($0 % 3) * 0.8) * 3600)
            }.sorted { $0.day < $1.day },
            goal: 8 * 3600, updated: .now),
        isPro: true)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DebtSnapshot { .placeholder }

    private func snapshot() -> DebtSnapshot {
        DebtSnapshot(
            date: .now,
            summary: WidgetSummary.load(),
            isPro: UserDefaults(suiteName: WidgetSummary.appGroupID)?
                .bool(forKey: "isPro") ?? false)
    }

    func getSnapshot(in context: Context, completion: @escaping (DebtSnapshot) -> Void) {
        completion(context.isPreview ? .placeholder : snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DebtSnapshot>) -> Void) {
        // App refreshes the shared summary on every foreground; hourly is plenty here
        completion(Timeline(entries: [snapshot()], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct DebtWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DebtWidget", provider: Provider()) { snapshot in
            DebtWidgetView(snapshot: snapshot)
                .containerBackground(bg, for: .widget)
        }
        .configurationDisplayName("Sleep Debt")
        .description("Your running sleep debt at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DebtWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DebtSnapshot

    var body: some View {
        if !snapshot.isPro {
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 20))
                Text("Sleeptab Pro")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text("Unlock in the app")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(cream.opacity(0.55))
            }
            .foregroundStyle(cream)
        } else if let summary = snapshot.summary {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.debt <= 0 ? "CAUGHT UP" : hm(summary.debt))
                        .font(.system(size: summary.debt <= 0 ? 16 : 26,
                                      weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(summary.debt <= 0 ? accent : cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("SLEEP DEBT")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(cream.opacity(0.55))
                    if family == .systemSmall { bars(summary) }
                }
                if family == .systemMedium {
                    Spacer()
                    bars(summary).frame(width: 130)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Text("Open Sleeptab to sync")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(cream.opacity(0.55))
        }
    }

    private func bars(_ summary: WidgetSummary) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(summary.nights) { night in
                Capsule()
                    .fill(night.asleep >= summary.goal ? accent : accent.opacity(0.4))
                    .frame(height: max(4, min(36, night.asleep / summary.goal * 30)))
            }
        }
        .frame(height: 38, alignment: .bottom)
    }

    private func hm(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}
