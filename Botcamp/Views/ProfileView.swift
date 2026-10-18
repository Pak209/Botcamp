import SwiftUI
import SwiftData
import BotcampCore

struct ProfileView: View {
    @Environment(ProStore.self) private var pro
    @Query private var profiles: [PlayerProfile]
    @Query private var records: [LessonRecord]
    @Environment(\.modelContext) private var context
    @State private var showPaywall = false
    @State private var remindersDenied = false
    var body: some View {
        let p = profiles.first
        let xp = p?.totalXP ?? 0
        let rank = Rank.forXP(xp)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(rank.badgeAsset).resizable().scaledToFit().frame(width: 80, height: 80)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rank.title).font(.title2.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                            Text("\(xp) XP").foregroundStyle(.secondary)
                            if let next = Rank(rawValue: rank.rawValue + 1) {
                                ProgressView(value: Double(xp - Rank.thresholds[rank.rawValue]), total: Double(Rank.thresholds[next.rawValue] - Rank.thresholds[rank.rawValue]))
                                Text("Next: \(next.title)").font(.caption).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                }
                Section("Streak") {
                    LabeledContent("Current", value: "\(p?.streak.displayed(now: .now) ?? 0) days")
                    LabeledContent("Longest", value: "\(p?.streak.longest ?? 0) days")
                    LabeledContent("Streak freezes", value: "\(p?.streak.freezes ?? 0)")
                    LabeledContent("Lessons today", value: "\(ProgressWriter.todayCount(records))")
                }
                Section("Daily goal") {
                    if let p {
                        Picker("Lessons per day", selection: Binding(get: { p.dailyGoal }, set: { p.dailyGoal = $0; try? context.save(); resched(p) })) {
                            ForEach(DailyGoal.options, id: \.self) { Text("\($0)").tag($0) }
                        }
                        Toggle("Daily reminder", isOn: Binding(get: { p.remindersOn }, set: { on in
                            if on { Task { let ok = await ReminderScheduler.requestPermission(); await MainActor.run { p.remindersOn = ok; remindersDenied = !ok; try? context.save(); resched(p) } } }
                            else { p.remindersOn = false; try? context.save(); resched(p) }
                        }))
                        if p.remindersOn {
                            DatePicker("Time", selection: Binding(
                                get: { Calendar.current.date(from: DateComponents(hour: p.reminderHour, minute: p.reminderMinute)) ?? .now },
                                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); p.reminderHour = c.hour ?? 19; p.reminderMinute = c.minute ?? 0; try? context.save(); resched(p) }),
                                displayedComponents: .hourAndMinute)
                        }
                        if remindersDenied { Text("Notifications are off for Botcamp. Turn them on in iOS Settings.").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Section {
                    NavigationLink { CertificateView() } label: { Label("Completion certificate", systemImage: "rosette") }
                }
                Section("Ranks") {
                    ForEach(Rank.allCases, id: \.self) { r in
                        HStack(alignment: .center, spacing: 8) {
                            Image(r.badgeAsset).resizable().frame(width: 32, height: 32)
                            Text(r.title)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            Text("\(Rank.thresholds[r.rawValue]) XP").foregroundStyle(.secondary)
                        }
                            .opacity(xp >= Rank.thresholds[r.rawValue] ? 1 : 0.4)
                    }
                }
                Section {
                    if pro.hasPro { Label("Pro unlocked", systemImage: "star.fill") }
                    else { Button("Get Botcamp Pro") { showPaywall = true } }
                    Button("Restore Purchases") { Task { await pro.restore() } }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func resched(_ p: PlayerProfile) { ReminderScheduler.reschedule(profile: p, lessonsToday: ProgressWriter.todayCount(records)) }
}
