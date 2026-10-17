import Foundation
import UserNotifications
import BotcampCore

/// Opt-in, local-only daily-goal reminder. One pending request, rescheduled after each lesson.
enum ReminderScheduler {
    static let id = "botcamp.daily-goal"

    /// Asks for permission (only called when the user flips the toggle on). Returns whether it's allowed.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(enabled: Bool, hour: Int, minute: Int, goalMetToday: Bool, streak: Int, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }
        let fire = DailyGoal.nextReminder(hour: hour, minute: minute, now: now, goalMetToday: goalMetToday)
        let content = UNMutableNotificationContent()
        content.title = "Botcamp"
        content.body = DailyGoal.reminderBody(streak: streak)
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func reschedule(profile: PlayerProfile, lessonsToday: Int) {
        reschedule(enabled: profile.remindersOn, hour: profile.reminderHour, minute: profile.reminderMinute,
                   goalMetToday: DailyGoal(lessonsPerDay: profile.dailyGoal).isMet(lessonsToday: lessonsToday),
                   streak: profile.streak.displayed(now: .now))
    }
}
