import Foundation

/// A question the player got wrong at least once, kept for Review mode until answered right there.
public struct MissedRef: Hashable, Codable, Sendable {
    public var lessonId: String
    public var stepIndex: Int
    public init(lessonId: String, stepIndex: Int) { self.lessonId = lessonId; self.stepIndex = stepIndex }
}

public enum ReviewBuilder {
    public static let reviewLessonId = "review"
    public static let maxPerSession = 10

    /// Resolves refs to graded steps still present in the course (content updates may remove some).
    public static func steps(for refs: [MissedRef], in course: Course, limit: Int = maxPerSession) -> [(MissedRef, Step)] {
        var seen = Set<MissedRef>(), out: [(MissedRef, Step)] = []
        for ref in refs where !seen.contains(ref) {
            seen.insert(ref)
            guard let lesson = course.allLessons.first(where: { $0.id == ref.lessonId }),
                  lesson.steps.indices.contains(ref.stepIndex), lesson.steps[ref.stepIndex].isGraded else { continue }
            out.append((ref, lesson.steps[ref.stepIndex]))
            if out.count == limit { break }
        }
        return out
    }

    /// A synthetic lesson so Review reuses the normal lesson player. Review XP is small and fixed.
    public static func lesson(for refs: [MissedRef], in course: Course, limit: Int = maxPerSession) -> Lesson? {
        let s = steps(for: refs, in: course, limit: limit)
        guard !s.isEmpty else { return nil }
        return Lesson(id: reviewLessonId, title: "Review", xp: 5, steps: s.map(\.1))
    }

    /// After a review session: refs answered right on the first try are cleared; the rest stay.
    public static func remaining(after refs: [MissedRef], missedInSession: Set<Int>) -> [MissedRef] {
        refs.enumerated().filter { missedInSession.contains($0.offset) }.map(\.element)
    }
}

/// Daily goal + local reminder scheduling rules (no networking, no UserNotifications import here).
public struct DailyGoal: Equatable, Sendable {
    public static let options = [1, 2, 3, 5]
    public var lessonsPerDay: Int
    public init(lessonsPerDay: Int) { self.lessonsPerDay = max(1, lessonsPerDay) }
    public func isMet(lessonsToday: Int) -> Bool { lessonsToday >= lessonsPerDay }
    public func progress(lessonsToday: Int) -> Double { min(1, Double(lessonsToday) / Double(lessonsPerDay)) }

    /// Next reminder fire date at hour:minute. Skips today if the goal is already met or the time has passed.
    public static func nextReminder(hour: Int, minute: Int, now: Date, goalMetToday: Bool, calendar: Calendar = .current) -> Date {
        var c = calendar.dateComponents([.year, .month, .day], from: now); c.hour = hour; c.minute = minute
        let today = calendar.date(from: c)!
        if !goalMetToday && today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)!
    }

    public static func reminderBody(streak: Int) -> String {
        streak > 0 ? "Sarge Byte says: keep your \(streak)-day streak alive. One quick lesson?" : "Sarge Byte is waiting. One 3-minute lesson gets you moving."
    }
}

public enum Certificate {
    /// Earned when every lesson in every unit is complete.
    public static func isEarned(course: Course, completed: Set<String>) -> Bool {
        !course.units.isEmpty && course.allLessons.allSatisfy { completed.contains($0.id) }
    }
    public static func progress(course: Course, completed: Set<String>) -> Double {
        let all = course.allLessons
        return all.isEmpty ? 0 : Double(all.filter { completed.contains($0.id) }.count) / Double(all.count)
    }
}

/// Signals for the mascot moments, kept pure so they're testable.
public enum Moments {
    /// A rank-up happened if XP crossed a threshold.
    public static func rankUp(from old: Int, to new: Int) -> Rank? {
        let a = Rank.forXP(old), b = Rank.forXP(new)
        return b.rawValue > a.rawValue ? b : nil
    }
    /// Broken streak: there was activity before, but the displayed streak is now 0.
    public static func streakBroken(_ s: StreakState, now: Date, calendar: Calendar = .current) -> Bool {
        s.lastActiveDay != nil && s.displayed(now: now, calendar: calendar) == 0
    }
    /// Fraction of the way from the current rank to the next (1 at max rank).
    public static func rankProgress(xp: Int) -> Double {
        let r = Rank.forXP(xp)
        guard r.rawValue + 1 < Rank.thresholds.count else { return 1 }
        let lo = Rank.thresholds[r.rawValue], hi = Rank.thresholds[r.rawValue + 1]
        return Double(xp - lo) / Double(hi - lo)
    }
}
