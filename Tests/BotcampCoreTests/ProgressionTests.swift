import XCTest
@testable import BotcampCore

final class ProgressionTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Los_Angeles")!; return c }()
    func day(_ d: Int, hour: Int = 10) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))! }

    // MARK: Streaks
    func testFirstActivityStartsStreak() {
        var s = StreakState(); s.recordActivity(now: day(1), calendar: cal)
        XCTAssertEqual(s.current, 1); XCTAssertEqual(s.longest, 1)
    }
    func testSameDayCountsOnce() {
        var s = StreakState(); s.recordActivity(now: day(1, hour: 8), calendar: cal); s.recordActivity(now: day(1, hour: 23), calendar: cal)
        XCTAssertEqual(s.current, 1)
    }
    func testConsecutiveDaysGrow() {
        var s = StreakState(); for d in 1...3 { s.recordActivity(now: day(d), calendar: cal) }
        XCTAssertEqual(s.current, 3)
    }
    func testMissedDayResetsWithoutFreeze() {
        var s = StreakState(); s.recordActivity(now: day(1), calendar: cal); s.recordActivity(now: day(3), calendar: cal)
        XCTAssertEqual(s.current, 1); XCTAssertEqual(s.longest, 1)
    }
    func testFreezeCoversMissedDay() {
        var s = StreakState(current: 4, longest: 4, lastActiveDay: cal.startOfDay(for: day(4)), freezes: 1)
        s.recordActivity(now: day(6), calendar: cal)
        XCTAssertEqual(s.current, 5); XCTAssertEqual(s.freezes, 0)
    }
    func testSevenDayStreakEarnsFreezeCapped() {
        var s = StreakState(); for d in 1...14 { s.recordActivity(now: day(d), calendar: cal) }
        XCTAssertEqual(s.freezes, 2)
        for d in 15...21 { s.recordActivity(now: day(d), calendar: cal) }
        XCTAssertEqual(s.freezes, StreakState.maxFreezes)
    }
    func testDisplayedStreakLapses() {
        var s = StreakState(); s.recordActivity(now: day(1), calendar: cal)
        XCTAssertEqual(s.displayed(now: day(2), calendar: cal), 1)
        XCTAssertEqual(s.displayed(now: day(4), calendar: cal), 0)
    }

    // MARK: XP & ranks
    func testXP() throws {
        let lesson = try CourseParsingTests.loadCourse().units[0].lessons[0]
        XCTAssertEqual(XPRules.xp(for: lesson, mistakes: 0, isReplay: false), lesson.xp + XPRules.perfectBonus)
        XCTAssertEqual(XPRules.xp(for: lesson, mistakes: 2, isReplay: false), lesson.xp)
        XCTAssertLessThan(XPRules.xp(for: lesson, mistakes: 0, isReplay: true), lesson.xp)
    }
    func testUnitCheckPassMark() throws {
        let check = try CourseParsingTests.loadCourse().units[0].lessons.first { $0.isUnitCheck }!
        XCTAssertTrue(XPRules.passed(check, correct: check.gradedCount))
        XCTAssertFalse(XPRules.passed(check, correct: 1))
    }
    func testRanks() {
        XCTAssertEqual(Rank.forXP(0), .recruit); XCTAssertEqual(Rank.forXP(99), .recruit)
        XCTAssertEqual(Rank.forXP(100), .cadet); XCTAssertEqual(Rank.forXP(5000), .botGeneral)
    }

    // MARK: Path / paywall
    func testPathUnlocksInOrderAndPaywall() throws {
        let c = try CourseParsingTests.loadCourse(); let p = PathPlanner(course: c)
        let u1 = c.units[0], u2 = c.units[1], u4 = c.units[3]
        XCTAssertEqual(p.state(of: u1.lessons[0], in: u1, completed: [], hasPro: false), .available)
        XCTAssertEqual(p.state(of: u1.lessons[1], in: u1, completed: [], hasPro: false), .locked)
        XCTAssertEqual(p.state(of: u2.lessons[0], in: u2, completed: [], hasPro: false), .locked)
        let u1done = Set(u1.lessons.map(\.id))
        XCTAssertEqual(p.state(of: u2.lessons[0], in: u2, completed: u1done, hasPro: false), .available)
        XCTAssertEqual(p.state(of: u4.lessons[0], in: u4, completed: u1done, hasPro: false), .needsPro)
        let first3 = Set(c.units.prefix(3).flatMap(\.lessons).map(\.id))
        XCTAssertEqual(p.state(of: u4.lessons[0], in: u4, completed: first3, hasPro: true), .available)
        XCTAssertEqual(p.nextLesson(completed: u1done, hasPro: false)?.1.id, u2.lessons[0].id)
    }

    // MARK: Grading
    func testGrader() {
        let f = FixPrompt(base: "b", chips: [.init(label: "a", text: "", correct: true), .init(label: "b", text: "", correct: false)], explain: nil)
        XCTAssertTrue(Grader.check(f, picked: [0])); XCTAssertFalse(Grader.check(f, picked: [0, 1]))
        let m = Match(prompt: "", pairs: [["A", "1"], ["B", "2"]])
        XCTAssertTrue(Grader.check(m, chosen: ["A": "1", "B": "2"])); XCTAssertFalse(Grader.check(m, chosen: ["A": "2", "B": "1"]))
        XCTAssertTrue(Grader.check(Order(prompt: "", items: ["x", "y"]), arranged: ["x", "y"]))
        XCTAssertTrue(Grader.check(Handoff(intro: "", prompt: "", checklist: ["a", "b"]), ticked: [0, 1]))
    }
}
