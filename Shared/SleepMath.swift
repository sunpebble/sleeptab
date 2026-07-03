import Foundation

struct Night: Codable, Equatable, Identifiable {
    let day: Date        // startOfDay of the wake day
    let asleep: TimeInterval
    var id: Date { day }
}

enum SleepMath {
    /// Buckets asleep intervals into nights and de-duplicates overlap (Watch and
    /// iPhone often both log the same night). Night key: the calendar day 12h after
    /// the interval ends — morning wake-ups land on the wake day, pre-midnight
    /// segments land with the following morning.
    /// ponytail: afternoon naps count toward the coming night; good enough
    static func nights(from intervals: [DateInterval], calendar: Calendar = .current) -> [Night] {
        var buckets: [Date: [DateInterval]] = [:]
        for interval in intervals {
            let key = calendar.startOfDay(for: interval.end.addingTimeInterval(12 * 3600))
            buckets[key, default: []].append(interval)
        }
        return buckets
            .map { Night(day: $0.key, asleep: mergedDuration($0.value)) }
            .sorted { $0.day < $1.day }
    }

    /// Total covered time of a set of possibly-overlapping intervals.
    static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []
        for interval in sorted {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1].end = max(last.end, interval.end)
            } else {
                merged.append((interval.start, interval.end))
            }
        }
        return merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    /// Rolling sleep debt over the nights recorded in the last `window` days.
    /// Surplus nights offset shortfalls; the total never goes below zero.
    /// ponytail: nights with no data are skipped, not counted as zero sleep
    static func debt(nights: [Night], goal: TimeInterval, window: Int = 14,
                     asOf: Date = .now, calendar: Calendar = .current) -> TimeInterval {
        guard let cutoff = calendar.date(byAdding: .day, value: -window,
                                         to: calendar.startOfDay(for: asOf)) else { return 0 }
        let recent = nights.filter { $0.day > cutoff }
        return max(0, recent.reduce(0) { $0 + (goal - $1.asleep) })
    }
}

/// Snapshot the app writes to the App Group so the widget (which can't read
/// HealthKit) has something to show.
struct WidgetSummary: Codable {
    var debt: TimeInterval
    var nights: [Night]  // last 7
    var goal: TimeInterval
    var updated: Date

    static let appGroupID = "group.com.sunpebble.sleeptab"
    static let key = "widgetSummary"

    static func save(_ summary: WidgetSummary) {
        guard let data = try? JSONEncoder().encode(summary) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
    }

    static func load() -> WidgetSummary? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }
}
