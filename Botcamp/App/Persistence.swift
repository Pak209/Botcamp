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

    static func todayCount(_ records: [LessonRecord], now: Date = .now) -> Int {
        records.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: now) }.count
    }
}
