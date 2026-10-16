import Foundation

public enum XPRules {
    public static let perfectBonus = 5
    public static let replayFraction = 0.2   // replays earn 20% so review is still rewarded
    public static func xp(for lesson: Lesson, mistakes: Int, isReplay: Bool) -> Int {
        let base = lesson.xp + (mistakes == 0 && lesson.gradedCount > 0 ? perfectBonus : 0)
        return isReplay ? max(1, Int((Double(base) * replayFraction).rounded())) : base
    }
    public static func passed(_ lesson: Lesson, correct: Int) -> Bool {
        guard lesson.isUnitCheck, lesson.gradedCount > 0 else { return true }
        return Double(correct) / Double(lesson.gradedCount) >= lesson.passFraction
    }
}

/// Streak state, value type so it is trivial to test. Days are calendar days in the user's time zone.
public struct StreakState: Codable, Equatable, Sendable {
    public var current: Int = 0
    public var longest: Int = 0
    public var lastActiveDay: Date? = nil
    public var freezes: Int = 0
    public static let maxFreezes = 2
    public static let freezeEvery = 7   // earn a freeze every 7-day streak milestone

    public init(current: Int = 0, longest: Int = 0, lastActiveDay: Date? = nil, freezes: Int = 0) {
        self.current = current; self.longest = longest; self.lastActiveDay = lastActiveDay; self.freezes = freezes
    }

    /// Streak as shown on screen right now (0 if it has lapsed beyond what freezes cover).
    public func displayed(now: Date, calendar: Calendar = .current) -> Int {
        guard let last = lastActiveDay else { return 0 }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return gap - 1 <= freezes ? current : 0
    }

    /// Record a completed lesson at `now`.
    public mutating func recordActivity(now: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if let last = lastActiveDay {
            let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
            if gap <= 0 { return }                       // already counted today
            let missed = gap - 1
            if missed == 0 { current += 1 }
            else if missed <= freezes { freezes -= missed; current += 1 }
            else { current = 1 }
        } else { current = 1 }
        lastActiveDay = today
        if current % Self.freezeEvery == 0 { freezes = min(Self.maxFreezes, freezes + 1) }
        longest = max(longest, current)
    }
}

public enum Rank: Int, CaseIterable, Sendable {
    case recruit, cadet, operatorRank, specialist, commander, botGeneral
    public var title: String { ["Recruit", "Cadet", "Operator", "Specialist", "Commander", "Bot General"][rawValue] }
    public var badgeAsset: String { ["badge-1-recruit", "badge-2-cadet", "badge-3-operator", "badge-4-specialist", "badge-5-commander", "badge-6-bot-general"][rawValue] }
    public static let thresholds = [0, 100, 300, 600, 1000, 1600]
    public static func forXP(_ xp: Int) -> Rank { Rank(rawValue: thresholds.lastIndex { xp >= $0 } ?? 0)! }
}

public enum LessonState: Equatable, Sendable { case done, available, locked, needsPro }

/// Decides what is playable. Lessons unlock in order within a unit; a unit opens when the previous unit's lessons are done.
public struct PathPlanner: Sendable {
    public let course: Course
    public init(course: Course) { self.course = course }

    public func isUnitComplete(_ unit: Unit, completed: Set<String>) -> Bool {
        unit.lessons.allSatisfy { completed.contains($0.id) }
    }

    public func state(of lesson: Lesson, in unit: Unit, completed: Set<String>, hasPro: Bool) -> LessonState {
        if completed.contains(lesson.id) { return .done }
        if !unit.isFree && !hasPro { return .needsPro }
        if let ui = course.units.firstIndex(where: { $0.id == unit.id }), ui > 0,
           !isUnitComplete(course.units[ui - 1], completed: completed), !course.units[ui - 1].isStub {
            return .locked
        }
        guard let li = unit.lessons.firstIndex(where: { $0.id == lesson.id }) else { return .locked }
        return li == 0 || completed.contains(unit.lessons[li - 1].id) ? .available : .locked
    }

    /// The next lesson to suggest on the home screen.
    public func nextLesson(completed: Set<String>, hasPro: Bool) -> (Unit, Lesson)? {
        for unit in course.units {
            for lesson in unit.lessons where state(of: lesson, in: unit, completed: completed, hasPro: hasPro) == .available {
                return (unit, lesson)
            }
        }
        return nil
    }

    /// The "you're here" ladder rung = highest rung whose unit is complete.
    public func currentRung(completed: Set<String>) -> Int {
        var rung = 0
        for (i, r) in course.rungs.enumerated() {
            if let u = course.unit(id: r.unitId), isUnitComplete(u, completed: completed) { rung = i }
        }
        return rung
    }
}
