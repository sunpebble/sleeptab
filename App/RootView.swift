import Charts
import SwiftUI

struct RootView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.scenePhase) private var scenePhase
    @State private var health = HealthStore()
    @AppStorage("sleepGoalHours") private var goalHours = 8.0
    @State private var showPaywall = false
    @State private var rangeNights = 7

    private var goal: TimeInterval { goalHours * 3600 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if !health.loaded {
                    ProgressView().padding(.top, 120).tint(Theme.cream)
                } else if health.nights.isEmpty {
                    emptyState
                } else {
                    debtCard
                    chartCard
                    weekCard
                    insightsCard
                    goalCard
                }
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #if DEBUG
        // -paywall: 直接弹解锁页，供 ASC 内购审核截图用
        .onAppear { if CommandLine.arguments.contains("-paywall") { showPaywall = true } }
        #endif
        .task { await health.load(goal: goal) }
        .onChange(of: goalHours) { health.publish(goal: goal) }
        .onChange(of: scenePhase) { _, phase in
            // re-read overnight data when coming back to foreground
            if phase == .active { Task { await health.load(goal: goal) } }
        }
    }

    private var header: some View {
        HStack {
            Text("SLEEPTAB")
                .font(Theme.font(20, weight: .bold))
                .kerning(4)
            Spacer()
            if !pro.isPro {
                Button("PRO") { showPaywall = true }
                    .font(Theme.font(13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(Theme.cream)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🌙").font(.system(size: 56))
            Text("No sleep data yet")
                .font(Theme.font(17, weight: .semibold))
                .foregroundStyle(Theme.cream)
            Text("Sleeptab reads sleep from Apple Health.\nWear your watch tonight, or check\nHealth → Sharing → Apps → Sleeptab.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.faded)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }

    private var currentDebt: TimeInterval {
        SleepMath.debt(nights: health.nights, goal: goal)
    }

    private var debtCard: some View {
        VStack(spacing: 6) {
            if currentDebt <= 0 {
                Text("ALL CAUGHT UP")
                    .font(Theme.font(40, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("NO SLEEP DEBT · LAST 14 NIGHTS")
                    .font(Theme.font(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.faded)
            } else {
                Text(hoursMinutes(currentDebt))
                    .font(Theme.font(56, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.cream)
                Text("SLEEP DEBT · LAST 14 NIGHTS")
                    .font(Theme.font(11, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Theme.faded)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }

    private var shownNights: [Night] {
        Array(health.nights.suffix(rangeNights))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach([7, 30, 90], id: \.self) { nights in
                    Button {
                        // Free tier: last 7 nights. Pro unlocks full history.
                        if nights > 7 && !pro.isPro {
                            showPaywall = true
                        } else {
                            rangeNights = nights
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(nights)N")
                            if nights > 7 && !pro.isPro {
                                Image(systemName: "lock.fill").font(.system(size: 8))
                            }
                        }
                        .font(Theme.font(12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(rangeNights == nights ? Theme.accent : Theme.cream.opacity(0.08)))
                        .foregroundStyle(rangeNights == nights ? Theme.bg : Theme.faded)
                    }
                }
                Spacer()
            }

            Chart {
                ForEach(shownNights) { night in
                    BarMark(
                        x: .value("Night", night.day, unit: .day),
                        y: .value("Slept", night.asleep / 3600))
                    .foregroundStyle(night.asleep >= goal ? Theme.accent : Theme.accent.opacity(0.4))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Goal", goalHours))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Theme.faded)
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Theme.cream.opacity(0.08))
                    AxisValueLabel().foregroundStyle(Theme.faded)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Theme.faded)
                }
            }
            .frame(height: 190)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }

    private var weekCard: some View {
        let week = Array(health.nights.suffix(7))
        let avg = week.isEmpty ? 0 : week.map(\.asleep).reduce(0, +) / Double(week.count)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AVG · LAST 7 NIGHTS")
                    .font(Theme.font(10, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Theme.faded)
                Text(hoursMinutes(avg))
                    .font(Theme.font(22, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.cream)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("VS GOAL")
                    .font(Theme.font(10, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Theme.faded)
                Text((avg >= goal ? "+" : "−") + hoursMinutes(abs(avg - goal)))
                    .font(Theme.font(22, weight: .bold).monospacedDigit())
                    .foregroundStyle(avg >= goal ? Theme.accent : Theme.cream)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS · LAST \(shownNights.count) NIGHTS")
                .font(Theme.font(10, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Theme.faded)
            if pro.isPro {
                let split = SleepMath.weekdayWeekendAverages(nights: shownNights)
                if let weekday = split.weekday {
                    insightRow("WEEKDAY AVG", hoursMinutes(weekday))
                }
                if let weekend = split.weekend {
                    insightRow("WEEKEND AVG", hoursMinutes(weekend))
                }
                if let best = shownNights.max(by: { $0.asleep < $1.asleep }) {
                    insightRow("BEST NIGHT", nightText(best))
                }
                if let worst = shownNights.min(by: { $0.asleep < $1.asleep }) {
                    insightRow("ROUGHEST", nightText(worst))
                }
                if let stats = SleepMath.bedtimeStats(nights: shownNights) {
                    let midnight = Calendar.current.startOfDay(for: .now)
                    insightRow("AVG BEDTIME", midnight.addingTimeInterval(stats.avgOffset)
                        .formatted(.dateTime.hour().minute()))
                    insightRow("CONSISTENCY", "± " + hoursMinutes(stats.spread))
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 11))
                        Text("Weekday vs weekend, best & roughest nights — unlock with Pro")
                            .font(Theme.font(12))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Theme.faded)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }

    private func insightRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.font(11, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Theme.faded)
            Spacer()
            Text(value)
                .font(Theme.font(15, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.cream)
        }
    }

    private func nightText(_ night: Night) -> String {
        "\(hoursMinutes(night.asleep)) · \(night.day.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var goalCard: some View {
        HStack {
            Text("SLEEP NEED")
                .font(Theme.font(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(Theme.faded)
            Spacer()
            Stepper(value: $goalHours, in: 5...10, step: 0.25) {
                Text(hoursMinutes(goal))
                    .font(Theme.font(16, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.cream)
            }
            .fixedSize()
            .tint(Theme.accent)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
    }
}
