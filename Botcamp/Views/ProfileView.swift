import SwiftUI
import SwiftData
import BotcampCore

struct ProfileView: View {
    @Environment(ProStore.self) private var pro
    @Query private var profiles: [PlayerProfile]
    @Query private var records: [LessonRecord]
    @State private var showPaywall = false
    var body: some View {
        let p = profiles.first
        let xp = p?.totalXP ?? 0
        let rank = Rank.forXP(xp)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(rank.badgeAsset).resizable().scaledToFit().frame(width: 80, height: 80)
                        VStack(alignment: .leading) {
                            Text(rank.title).font(.title2.weight(.heavy))
                            Text("\(xp) XP").foregroundStyle(.secondary)
                            if let next = Rank(rawValue: rank.rawValue + 1) {
                                ProgressView(value: Double(xp - Rank.thresholds[rank.rawValue]), total: Double(Rank.thresholds[next.rawValue] - Rank.thresholds[rank.rawValue]))
                                Text("Next: \(next.title)").font(.caption)
                            }
                        }
                    }
                }
                Section("Streak") {
                    LabeledContent("Current", value: "\(p?.streak.displayed(now: .now) ?? 0) days")
                    LabeledContent("Longest", value: "\(p?.streak.longest ?? 0) days")
                    LabeledContent("Streak freezes", value: "\(p?.streak.freezes ?? 0)")
                    LabeledContent("Lessons today", value: "\(ProgressWriter.todayCount(records))")
                }
                Section("Ranks") {
                    ForEach(Rank.allCases, id: \.self) { r in
                        HStack { Image(r.badgeAsset).resizable().frame(width: 32, height: 32); Text(r.title); Spacer(); Text("\(Rank.thresholds[r.rawValue]) XP").foregroundStyle(.secondary) }
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
}
