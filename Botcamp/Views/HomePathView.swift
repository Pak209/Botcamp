import SwiftUI
import SwiftData
import BotcampCore

/// Duolingo-style winding path. Ladder rungs from content.js become section headers.
struct HomePathView: View {
    @Environment(CourseStore.self) private var content
    @Environment(ProStore.self) private var pro
    @Query private var profiles: [PlayerProfile]
    @Query private var records: [LessonRecord]
    @State private var playing: PlayTarget?
    @State private var showPaywall = false

    struct PlayTarget: Identifiable { let unit: BotcampCore.Unit; let lesson: Lesson; var id: String { lesson.id } }

    private var completed: Set<String> { Set(records.map(\.lessonId)) }
    private var profile: PlayerProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    ForEach(content.course.units) { unit in unitSection(unit) }
                    Text("Model facts last checked \(content.course.lastChecked).")
                        .font(.caption).foregroundStyle(.secondary).padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
            .background(Color.brandCream.ignoresSafeArea())
            .navigationTitle("Botcamp")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { statsPill } }
            .fullScreenCover(item: $playing) { t in LessonPlayerView(unit: t.unit, lesson: t.lesson, completed: completed) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var header: some View {
        let streak = profile?.streak.displayed(now: .now) ?? 0
        let rung = content.planner.currentRung(completed: completed)
        return HStack(spacing: 12) {
            SargeByte(pose: streak == 0 && !records.isEmpty ? .sleeping : .idle, size: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(streak == 0 ? "Ready, recruit?" : "\(streak)-day streak. Keep it up!").font(.headline)
                Text("You're here: \(content.course.rungs[safe: rung]?.title ?? "Chat")").font(.subheadline).foregroundStyle(.secondary)
                if let next = content.planner.nextLesson(completed: completed, hasPro: pro.hasPro) {
                    Button("Start: \(next.1.title)") { playing = .init(unit: next.0, lesson: next.1) }
                        .buttonStyle(ChunkyButtonStyle()).padding(.top, 4)
                }
            }
        }
        .padding().background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    private var statsPill: some View {
        HStack(spacing: 10) {
            Label("\(profile?.streak.displayed(now: .now) ?? 0)", systemImage: "flame.fill").foregroundStyle(Color.brandOrange)
            Label("\(profile?.totalXP ?? 0)", systemImage: "bolt.fill").foregroundStyle(Color.brandTeal)
        }.font(.subheadline.bold())
    }

    @ViewBuilder private func unitSection(_ unit: BotcampCore.Unit) -> some View {
        if let rung = content.course.rungs.firstIndex(where: { $0.unitId == unit.id }) {
            Text("RUNG \(rung + 1) · \(content.course.rungs[rung].title.uppercased())")
                .font(.caption.weight(.heavy)).foregroundStyle(Color.brandOlive).frame(maxWidth: .infinity, alignment: .leading)
        }
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Unit \(unit.number): \(unit.title)").font(.title3.weight(.heavy))
                    Text(unit.blurb).font(.footnote).opacity(0.85)
                }
                Spacer()
                if !unit.isFree && !pro.hasPro { Image(systemName: "lock.fill") }
            }
            .padding().foregroundStyle(.white)
            .background(unit.isFree ? Color.brandTeal : Color.brandNavy, in: RoundedRectangle(cornerRadius: 16))

            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { i, lesson in
                let state = content.planner.state(of: lesson, in: unit, completed: completed, hasPro: pro.hasPro)
                LessonNode(lesson: lesson, state: state)
                    .offset(x: CGFloat([0, 50, 0, -50][i % 4]))
                    .onTapGesture {
                        switch state {
                        case .available, .done: playing = .init(unit: unit, lesson: lesson)
                        case .needsPro: showPaywall = true
                        case .locked: break
                        }
                    }
            }
            if unit.isStub { Text("More lessons coming soon").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct LessonNode: View {
    let lesson: Lesson
    let state: LessonState
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(fill).frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.brandNavy, lineWidth: 3))
                    .shadow(color: .brandNavy.opacity(0.9), radius: 0, y: 5)
                Image(systemName: icon).font(.title2.bold()).foregroundStyle(Color.brandNavy)
            }
            Text(lesson.title).font(.caption.weight(.semibold)).frame(width: 130).multilineTextAlignment(.center)
        }
        .opacity(state == .locked ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint(state == .locked ? "Locked" : state == .needsPro ? "Requires Pro" : "Start lesson")
    }
    private var fill: Color {
        switch state { case .done: .brandYellow; case .available: .brandLime; case .locked: .gray.opacity(0.3); case .needsPro: .brandPink.opacity(0.6) }
    }
    private var icon: String {
        if lesson.isUnitCheck { return state == .done ? "trophy.fill" : "flag.checkered" }
        switch state { case .done: return "checkmark"; case .needsPro: return "lock.fill"; case .locked: return "lock"; case .available: return "star.fill" }
    }
}

extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }
