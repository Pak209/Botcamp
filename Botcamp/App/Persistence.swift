import Foundation
import SwiftData
import BotcampCore

/// Single local profile (no accounts in v1).
@Model
final class PlayerProfile {
    var totalXP: Int = 0
    var streakData: Data = Data()
    var dailyGoal: Int = 1
    var createdAt: Date = Date()
    // v0.2 (defaults keep SwiftData's lightweight migration automatic)
    var hasOnboarded: Bool = false
    var goalText: String = ""
    var playerName: String = ""
    var remindersOn: Bool = false
    var reminderHour: Int = 19
    var reminderMinute: Int = 0

    init() {}

    var streak: StreakState {
        get { (try? JSONDecoder().decode(StreakState.self, from: streakData)) ?? StreakState() }
        set { streakData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    var rank: Rank { Rank.forXP(totalXP) }
}

/// One row per finished play-through of a lesson.
@Model
final class LessonRecord {
    var lessonId: String = ""
    var completedAt: Date = Date()
    var xpEarned: Int = 0
    var mistakes: Int = 0

    init(lessonId: String, xpEarned: Int, mistakes: Int, completedAt: Date = .now) {
        self.lessonId = lessonId; self.xpEarned = xpEarned; self.mistakes = mistakes; self.completedAt = completedAt
    }
}

/// A question missed at least once; lives until answered right in Review.
@Model
final class MissedQuestion {
    var lessonId: String = ""
    var stepIndex: Int = 0
    var missedAt: Date = Date()
    init(lessonId: String, stepIndex: Int, missedAt: Date = .now) { self.lessonId = lessonId; self.stepIndex = stepIndex; self.missedAt = missedAt }
    var ref: MissedRef { MissedRef(lessonId: lessonId, stepIndex: stepIndex) }
}

enum ProgressWriter {
    static func profile(in context: ModelContext) -> PlayerProfile {
        if let p = try? context.fetch(FetchDescriptor<PlayerProfile>()).first { return p }
        let p = PlayerProfile(); context.insert(p); return p
    }

    /// Records a finished lesson, awards XP, bumps the streak. Returns XP earned.
    @discardableResult
    static func finish(lesson: Lesson, mistakes: Int, completed: Set<String>, in context: ModelContext, now: Date = .now) -> Int {
        let profile = profile(in: context)
        let xp = XPRules.xp(for: lesson, mistakes: mistakes, isReplay: completed.contains(lesson.id))
        profile.totalXP += xp
        var streak = profile.streak
        streak.recordActivity(now: now)
        profile.streak = streak
        context.insert(LessonRecord(lessonId: lesson.id, xpEarned: xp, mistakes: mistakes, completedAt: now))
        try? context.save()
        return xp
    }

    static func recordMiss(lessonId: String, stepIndex: Int, in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<MissedQuestion>(predicate: #Predicate { $0.lessonId == lessonId && $0.stepIndex == stepIndex }))) ?? []
        if existing.isEmpty { context.insert(MissedQuestion(lessonId: lessonId, stepIndex: stepIndex)); try? context.save() }
    }

    static func clearReviewed(_ cleared: [MissedRef], in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<MissedQuestion>())) ?? []
        let set = Set(cleared)
        for m in all where set.contains(m.ref) { context.delete(m) }
        try? context.save()
    }

    static func todayCount(_ records: [LessonRecord], now: Date = .now) -> Int {
        records.filter { $0.lessonId != ReviewBuilder.reviewLessonId && Calendar.current.isDate($0.completedAt, inSameDayAs: now) }.count
    }
}
