import SwiftUI
import SwiftData
import BotcampCore

/// First-run: Sarge Byte intro → pick a goal → pick a daily goal (+ optional reminder).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var goal: Advisor.Goal?
    @State private var daily = 1
    @State private var remind = false
    @State private var remindAt = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? .now

    var body: some View {
        VStack(spacing: 20) {
            HStack { ForEach(0..<3, id: \.self) { i in Capsule().fill(i <= page ? Color.brandTeal : .gray.opacity(0.3)).frame(height: 6) } }
            Spacer(minLength: 0)
            Group {
                switch page {
                case 0: intro
                case 1: goalPage
                default: dailyPage
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            Spacer(minLength: 0)
            Button(page < 2 ? "Continue" : "Start training") { next() }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(page == 1 && goal == nil)
        }
        .padding()
        .background(Color.brandCream.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private var intro: some View {
        VStack(spacing: 16) {
            SargeByte(pose: .cheer, size: 180)
            Text("Welcome, recruit!").font(.largeTitle.weight(.heavy))
            Text("I'm Sarge Byte. In a few minutes a day I'll take you from \"what's a token?\" to running your own team of AI agents. No coding needed.")
                .multilineTextAlignment(.center)
        }
    }

    private var goalPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            SargeByte(pose: .thinking, size: 100).frame(maxWidth: .infinity)
            Text("What do you want AI to help you make?").font(.title2.weight(.heavy))
            ForEach(Advisor.Goal.allCases, id: \.self) { g in
                OptionRow(text: Advisor.goalLabels[g] ?? g.rawValue, selected: goal == g)
                    .onTapGesture { goal = g }
            }
        }
    }

    private var dailyPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a daily goal").font(.title2.weight(.heavy))
            Text("Lessons take 2–4 minutes. Small and steady wins.").foregroundStyle(.secondary)
            ForEach(DailyGoal.options, id: \.self) { n in
                OptionRow(text: "\(n) lesson\(n == 1 ? "" : "s") a day · ~\(n * 3) min", selected: daily == n)
                    .onTapGesture { daily = n }
            }
            Toggle("Remind me if I haven't trained yet", isOn: $remind).padding(.top, 8)
            if remind { DatePicker("Reminder time", selection: $remindAt, displayedComponents: .hourAndMinute) }
            Text("Reminders are optional, stay on this phone, and can be turned off in Profile.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func next() {
        if page < 2 { withAnimation { page += 1 }; return }
        let p = ProgressWriter.profile(in: context)
        p.goalText = goal?.rawValue ?? ""
        p.dailyGoal = daily
        let hm = Calendar.current.dateComponents([.hour, .minute], from: remindAt)
        p.reminderHour = hm.hour ?? 19; p.reminderMinute = hm.minute ?? 0
        p.hasOnboarded = true
        try? context.save()
        if remind {
            Task {
                let ok = await ReminderScheduler.requestPermission()
                await MainActor.run {
                    p.remindersOn = ok; try? context.save()
                    ReminderScheduler.reschedule(profile: p, lessonsToday: 0)
                }
            }
        }
        dismiss()
    }
}
