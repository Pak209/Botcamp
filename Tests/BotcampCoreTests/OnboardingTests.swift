import XCTest
@testable import BotcampCore

final class OnboardingTests: XCTestCase {
    typealias S = Onboarding.State

    func testStartsAtHelloWithEmptyBar() {
        let s = S()
        XCTAssertEqual(s.step, .hello)
        XCTAssertEqual(s.progress, 0)
        XCTAssertTrue(s.canContinue)
        XCTAssertFalse(s.finished)
    }

    func testHappyPathCollectsAnswers() {
        var s = S()
        s.next()                                   // hello → why
        XCTAssertEqual(s.step, .why)
        XCTAssertFalse(s.canContinue)
        s.next()                                   // blocked until a pick
        XCTAssertEqual(s.step, .why)
        s.reason = .sideMoney; s.next()
        XCTAssertEqual(s.step, .level)
        s.level = .some; s.next()
        XCTAssertEqual(s.step, .dailyGoal)
        s.minutes = 10; s.next()
        XCTAssertEqual(s.step, .reminder)
        s.wantsReminder = true; s.next()
        XCTAssertEqual(s.step, .firstWin)
        XCTAssertFalse(s.canContinue)
        XCTAssertTrue(s.answerFirstWin(Onboarding.firstWin.answer))
        s.next()
        XCTAssertEqual(s.step, .planReady)
        XCTAssertEqual(s.progress, 1)
        XCTAssertTrue(s.isLast)
        s.next()
        XCTAssertTrue(s.finished)
        XCTAssertEqual(s.result, .init(reason: .sideMoney, level: .some, dailyMinutes: 10, lessonsPerDay: 3,
                                       startUnitId: "m2", wantsReminder: true, xpEarned: 10, didFirstWin: true))
    }

    func testProgressRisesEveryStep() {
        var s = S(); var last = -1.0
        for _ in Onboarding.Step.allCases {
            XCTAssertGreaterThan(s.progress, last); last = s.progress
            s.skip()
        }
    }

    func testSkipEveryScreenGivesDefaults() {
        var s = S()
        for _ in Onboarding.Step.allCases { s.skip() }
        XCTAssertTrue(s.finished)
        let r = s.result
        XCTAssertNil(r.reason); XCTAssertNil(r.level)
        XCTAssertEqual(r.dailyMinutes, 5)
        XCTAssertEqual(r.lessonsPerDay, 2)
        XCTAssertEqual(r.startUnitId, "m1")
        XCTAssertFalse(r.wantsReminder)
        XCTAssertEqual(r.xpEarned, 0)
        XCTAssertFalse(r.didFirstWin)
    }

    func testSkipAllJumpsToPlanFromAnywhere() {
        var s = S(); s.skip(); s.reason = .fun
        s.skipAll()
        XCTAssertEqual(s.step, .planReady)
        XCTAssertFalse(s.finished)
        s.next()
        XCTAssertTrue(s.finished)
        XCTAssertEqual(s.result.reason, .fun)
    }

    func testBackGoesOneScreenAndStopsAtHello() {
        var s = S(); s.back()
        XCTAssertEqual(s.step, .hello)
        s.skip(); s.skip(); s.back()
        XCTAssertEqual(s.step, .why)
    }

    func testFirstWinWrongThenRightGivesSmallerXP() {
        var s = S()
        while s.step != .firstWin { s.skip() }
        XCTAssertFalse(s.answerFirstWin(0))
        XCTAssertFalse(s.canContinue)
        XCTAssertEqual(s.xpEarned, 0)
        XCTAssertTrue(s.answerFirstWin(1))
        XCTAssertEqual(s.xpEarned, Onboarding.firstWinRetryXP)
        // Locked once solved: more taps change nothing.
        XCTAssertTrue(s.answerFirstWin(0))
        XCTAssertEqual(s.firstWinTries, 2)
    }

    func testFirstWinIgnoredOffScreenOrOutOfRange() {
        var s = S()
        XCTAssertFalse(s.answerFirstWin(1))        // not on that screen yet
        while s.step != .firstWin { s.skip() }
        XCTAssertFalse(s.answerFirstWin(9))
        XCTAssertEqual(s.firstWinTries, 0)
    }

    func testMinutesMapOntoDailyGoalOptions() {
        XCTAssertEqual(Onboarding.minuteOptions, [3, 5, 10, 15])
        XCTAssertEqual(Onboarding.minuteOptions.map(Onboarding.lessonsPerDay), DailyGoal.options)
    }

    func testLevelPlacesIntoFreeUnits() throws {
        let c = try CourseParsingTests.loadCourse()
        XCTAssertEqual(Onboarding.Level.allCases.map(\.startUnitId), ["m1", "m2", "m3"])
        for l in Onboarding.Level.allCases { XCTAssertEqual(c.unit(id: l.startUnitId)?.isFree, true, l.rawValue) }
    }

    func testPlacementOpensStartUnitAndKeepsEarlierOnesPlayable() throws {
        let c = try CourseParsingTests.loadCourse(), p = PathPlanner(course: c)
        let u1 = c.units[0], u2 = c.units[1], u3 = c.units[2]
        XCTAssertEqual(p.state(of: u2.lessons[0], in: u2, completed: [], hasPro: false, startUnitId: "m2"), .available)
        XCTAssertEqual(p.state(of: u1.lessons[0], in: u1, completed: [], hasPro: false, startUnitId: "m2"), .available)
        XCTAssertEqual(p.state(of: u2.lessons[1], in: u2, completed: [], hasPro: false, startUnitId: "m2"), .locked)
        XCTAssertEqual(p.state(of: u3.lessons[0], in: u3, completed: [], hasPro: false, startUnitId: "m2"), .locked)
        XCTAssertEqual(p.nextLesson(completed: [], hasPro: false, startUnitId: "m2")?.1.id, u2.lessons[0].id)
        // After the placement unit, it wraps back to earlier units.
        let u2done = Set(u2.lessons.map(\.id))
        XCTAssertEqual(p.nextLesson(completed: u2done, hasPro: false, startUnitId: "m2")?.1.id, u3.lessons[0].id)
        // Unknown or empty placement behaves like no placement.
        XCTAssertEqual(p.nextLesson(completed: [], hasPro: false, startUnitId: "")?.1.id, u1.lessons[0].id)
        XCTAssertEqual(p.nextLesson(completed: [], hasPro: false, startUnitId: "nope")?.1.id, u1.lessons[0].id)
    }

    /// Copy rule: short lines (≤ 8 words), no jargon.
    func testCopyIsShortAndPlain() {
        var lines = Onboarding.Step.allCases.map(Onboarding.sarge)
        lines += Onboarding.Reason.allCases.flatMap { [$0.label, $0.reply] }
        lines += Onboarding.Level.allCases.flatMap { [$0.label, $0.detail] }
        let q = Onboarding.firstWin
        lines += [q.prompt, q.right, q.wrong] + q.options
        lines += Onboarding.minuteOptions.map { Onboarding.minutesLabel($0).title }
        let jargon = ["token", "llm", "model", "agent", "api", "prompt engineering", "neural", "parameter"]
        for line in lines {
            XCTAssertLessThanOrEqual(Onboarding.wordCount(line), 8, line)
            for j in jargon { XCTAssertFalse(line.lowercased().contains(j), "\(line) uses \(j)") }
        }
    }
}
