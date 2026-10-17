import XCTest
@testable import BotcampCore

final class FeatureTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Los_Angeles")!; return c }()
    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: h, minute: m))! }
    func course() throws -> Course { try CourseParsingTests.loadCourse() }

    // MARK: Content
    func testAllTenUnitsFullyBuilt() throws {
        let c = try course()
        XCTAssertEqual(c.units.count, 10)
        for u in c.units {
            XCTAssertFalse(u.isStub, u.id)
            XCTAssertEqual(u.lessons.count, 5, u.id)
            XCTAssertTrue(u.lessons.last!.isUnitCheck, u.id)
            XCTAssertTrue(u.lessons.contains { $0.steps.contains { if case .handoff = $0 { return true }; return false } }, u.id)
        }
    }
    func testNoStepTypeIsUnknown() throws {
        for l in try course().allLessons { for s in l.steps { if case .unknown(let t) = s { XCTFail("\(l.id): \(t)") } } }
    }

    // MARK: Advisor (parity with app.js)
    func testAdvisorDemoMatchesWeb() {
        let p = Advisor.plan(.init(idea: "Faceless YouTube channel about crypto history", goal: .media, level: .some, budget: .twenty, priority: .quality))
        XCTAssertTrue(p.model.hasPrefix("Nano Banana 2.1"))
        XCTAssertEqual(p.rung, 2)
        XCTAssertEqual(p.learnFirst, ["m3", "m5", "m9"])
        XCTAssertTrue(p.teamIsNow)
    }
    func testAdvisorPrivacySwapsToLocal() {
        let p = Advisor.plan(.init(goal: .write, level: .new, budget: .zero, priority: .privacy))
        XCTAssertTrue(p.model.contains("Qwen3.8"))
        XCTAssertTrue(p.alternative.contains("free tier"))
        XCTAssertEqual(p.learnFirst, ["m1", "m2", "m3", "m4", "m10"])
        XCTAssertFalse(p.teamIsNow)
        XCTAssertEqual(p.idea, "your idea")
    }
    func testAdvisorNewbieCodeGetsWarningAndCostNote() {
        let p = Advisor.plan(.init(goal: .code, level: .new, budget: .hundred, priority: .cost))
        XCTAssertTrue(p.notes.contains { $0.hasPrefix("New to AI?") })
        XCTAssertTrue(p.notes.contains { $0.contains("small model") })
        XCTAssertEqual(p.learnFirst, ["m1", "m3", "m7", "m9", "m10"])
    }
    func testAdvisorCostNoteSkippedForMedia() {
        XCTAssertTrue(Advisor.plan(.init(goal: .media, priority: .cost)).notes.isEmpty)
    }
    func testAdvisorUnitsExistInCourse() throws {
        let c = try course()
        for g in Advisor.Goal.allCases { for id in Advisor.plan(.init(goal: g, level: .new, priority: .privacy)).learnFirst { XCTAssertNotNil(c.unit(id: id)) } }
    }

    // MARK: Review
    func testReviewBuildsFromMissedGradedSteps() throws {
        let c = try course()
        let refs = [MissedRef(lessonId: "u1l1", stepIndex: 2), MissedRef(lessonId: "u1l1", stepIndex: 0), // explain: skipped
                    MissedRef(lessonId: "gone", stepIndex: 0), MissedRef(lessonId: "u1l1", stepIndex: 2)]  // missing, duplicate
        let l = try XCTUnwrap(ReviewBuilder.lesson(for: refs, in: c))
        XCTAssertEqual(l.steps.count, 1); XCTAssertEqual(l.id, "review")
        XCTAssertNil(ReviewBuilder.lesson(for: [], in: c))
    }
    func testReviewLimit() throws {
        let c = try course()
        let refs = c.allLessons.flatMap { l in l.steps.indices.map { MissedRef(lessonId: l.id, stepIndex: $0) } }
        XCTAssertEqual(ReviewBuilder.steps(for: refs, in: c).count, ReviewBuilder.maxPerSession)
    }
    func testReviewRemaining() {
        let refs = (0..<3).map { MissedRef(lessonId: "a", stepIndex: $0) }
        XCTAssertEqual(ReviewBuilder.remaining(after: refs, missedInSession: [1]), [refs[1]])
    }

    // MARK: Daily goal + reminders
    func testDailyGoal() {
        let g = DailyGoal(lessonsPerDay: 3)
        XCTAssertFalse(g.isMet(lessonsToday: 2)); XCTAssertTrue(g.isMet(lessonsToday: 3))
        XCTAssertEqual(g.progress(lessonsToday: 6), 1)
        XCTAssertEqual(DailyGoal(lessonsPerDay: 0).lessonsPerDay, 1)
    }
    func testReminderToday() {
        XCTAssertEqual(DailyGoal.nextReminder(hour: 19, minute: 30, now: at(16, 9), goalMetToday: false, calendar: cal), at(16, 19, 30))
    }
    func testReminderTomorrowWhenPassedOrMet() {
        XCTAssertEqual(DailyGoal.nextReminder(hour: 19, minute: 0, now: at(16, 20), goalMetToday: false, calendar: cal), at(17, 19))
        XCTAssertEqual(DailyGoal.nextReminder(hour: 19, minute: 0, now: at(16, 9), goalMetToday: true, calendar: cal), at(17, 19))
    }
    func testReminderBody() {
        XCTAssertTrue(DailyGoal.reminderBody(streak: 4).contains("4-day"))
        XCTAssertFalse(DailyGoal.reminderBody(streak: 0).contains("streak"))
    }

    // MARK: Certificate + moments
    func testCertificate() throws {
        let c = try course()
        let all = Set(c.allLessons.map(\.id))
        XCTAssertTrue(Certificate.isEarned(course: c, completed: all))
        XCTAssertFalse(Certificate.isEarned(course: c, completed: all.subtracting(["u10check"])))
        XCTAssertEqual(Certificate.progress(course: c, completed: []), 0)
    }
    func testRankUpAndProgress() {
        XCTAssertEqual(Moments.rankUp(from: 95, to: 105), .cadet)
        XCTAssertNil(Moments.rankUp(from: 105, to: 120))
        XCTAssertEqual(Moments.rankProgress(xp: 200), 0.5, accuracy: 0.001)
        XCTAssertEqual(Moments.rankProgress(xp: 5000), 1)
    }
    func testStreakBroken() {
        XCTAssertFalse(Moments.streakBroken(StreakState(), now: at(16, 9), calendar: cal))
        let s = StreakState(current: 3, longest: 3, lastActiveDay: cal.startOfDay(for: at(10, 9)))
        XCTAssertTrue(Moments.streakBroken(s, now: at(16, 9), calendar: cal))
    }
}
