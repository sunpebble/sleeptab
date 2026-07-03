import XCTest
@testable import Sleeptab

final class SleepMathTests: XCTestCase {
    // Fixed calendar so tests don't depend on machine timezone/DST
    private var cal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func day(_ day: Int) -> Date {
        cal.startOfDay(for: date(day, 12))
    }

    func testMorningWakeBucketsToWakeDay() {
        let nights = SleepMath.nights(
            from: [DateInterval(start: date(1, 23), end: date(2, 7))], calendar: cal)
        XCTAssertEqual(nights, [Night(day: day(2), asleep: 8 * 3600)])
    }

    func testPreMidnightSegmentJoinsMorningSegment() {
        // Watch logs two chunks: 22:00–23:30, then 23:45–06:30 — one night, on the wake day
        let nights = SleepMath.nights(from: [
            DateInterval(start: date(3, 22), end: date(3, 23, 30)),
            DateInterval(start: date(3, 23, 45), end: date(4, 6, 30)),
        ], calendar: cal)
        XCTAssertEqual(nights.count, 1)
        XCTAssertEqual(nights[0].day, day(4))
        XCTAssertEqual(nights[0].asleep, 1.5 * 3600 + 6.75 * 3600, accuracy: 1)
    }

    func testOverlappingSourcesAreNotDoubleCounted() {
        // Watch and iPhone both log the same night
        let nights = SleepMath.nights(from: [
            DateInterval(start: date(5, 23), end: date(6, 7)),
            DateInterval(start: date(5, 23, 30), end: date(6, 6, 30)),
        ], calendar: cal)
        XCTAssertEqual(nights, [Night(day: day(6), asleep: 8 * 3600)])
    }

    func testDebtSumsShortfallAndClampsAtZero() {
        let asOf = date(10, 12)
        let goal: TimeInterval = 8 * 3600
        let shortNights = [
            Night(day: day(8), asleep: 6 * 3600),
            Night(day: day(9), asleep: 7 * 3600),
        ]
        XCTAssertEqual(SleepMath.debt(nights: shortNights, goal: goal, asOf: asOf, calendar: cal),
                       3 * 3600, accuracy: 1)

        let longNights = [Night(day: day(9), asleep: 10 * 3600)]
        XCTAssertEqual(SleepMath.debt(nights: longNights, goal: goal, asOf: asOf, calendar: cal), 0)
    }

    func testSurplusOffsetsShortfall() {
        let asOf = date(10, 12)
        let nights = [
            Night(day: day(8), asleep: 6 * 3600),   // -2h
            Night(day: day(9), asleep: 9 * 3600),   // +1h
        ]
        XCTAssertEqual(SleepMath.debt(nights: nights, goal: 8 * 3600, asOf: asOf, calendar: cal),
                       1 * 3600, accuracy: 1)
    }

    func testDebtIgnoresNightsOutsideWindow() {
        let asOf = date(28, 12)
        let nights = [
            Night(day: day(2), asleep: 2 * 3600),   // ancient, outside 14-day window
            Night(day: day(27), asleep: 7 * 3600),  // -1h
        ]
        XCTAssertEqual(SleepMath.debt(nights: nights, goal: 8 * 3600, asOf: asOf, calendar: cal),
                       1 * 3600, accuracy: 1)
    }

    func testWidgetSummaryRoundtrip() throws {
        let summary = WidgetSummary(debt: 3600, nights: [Night(day: day(1), asleep: 7 * 3600)],
                                    goal: 8 * 3600, updated: date(2, 8))
        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(WidgetSummary.self, from: data)
        XCTAssertEqual(decoded.debt, summary.debt)
        XCTAssertEqual(decoded.nights, summary.nights)
    }
}
