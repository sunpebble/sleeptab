import Foundation
import HealthKit
import Observation
import WidgetKit

@MainActor
@Observable
final class HealthStore {
    private(set) var nights: [Night] = []
    private(set) var loaded = false

    func load(goal: TimeInterval) async {
        #if DEBUG
        if CommandLine.arguments.contains("-seedDemo") {
            nights = Self.demoNights()
            publish(goal: goal)
            return
        }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else {
            loaded = true
            return
        }
        let store = HKHealthStore()
        let sleepType = HKCategoryType(.sleepAnalysis)
        try? await store.requestAuthorization(toShare: [], read: [sleepType])

        let start = Calendar.current.date(byAdding: .day, value: -400, to: .now)!
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType,
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [])
        let samples = (try? await descriptor.result(for: store)) ?? []
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals = samples
            .filter { asleepValues.contains($0.value) }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
        nights = SleepMath.nights(from: intervals)
        publish(goal: goal)
    }

    /// Recomputes the widget snapshot; also called when the sleep goal changes.
    func publish(goal: TimeInterval) {
        loaded = true
        WidgetSummary.save(WidgetSummary(
            debt: SleepMath.debt(nights: nights, goal: goal),
            nights: Array(nights.suffix(7)),
            goal: goal,
            updated: .now))
        WidgetCenter.shared.reloadAllTimelines()
    }

    #if DEBUG
    static func demoNights() -> [Night] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (1...45).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            // deterministic wobble: ~5.8–8.5h with a rough night every 5th
            let hours = 7.0 + sin(Double(offset) * 1.7) * 1.3 + (offset % 5 == 0 ? -1.2 : 0.2)
            return Night(day: day, asleep: hours * 3600)
        }
        .sorted { $0.day < $1.day }
    }
    #endif
}
