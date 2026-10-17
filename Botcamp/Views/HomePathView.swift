import SwiftUI
import SwiftData
import BotcampCore

/// Duolingo-style winding path. Ladder rungs from content.js become section headers.
struct HomePathView: View {
    /// Set by RootTabView after onboarding: open the first lesson of the placement unit.
    var autoStart: Binding<Bool> = .constant(false)
    @Environment(CourseStore.self) private var content
    @Environment(ProStore.self) private var pro
    @Query private var profiles: [PlayerProfile]
    @Query private var records: [LessonRecord]
    @Query(sort: \MissedQuestion.missedAt) private var missed: [MissedQuestion]
    @State private var playing: PlayTarget?
    @State private var reviewing: ReviewTarget?
    @State private var showPaywall = false

    struct PlayTarget: Identifiable { let unit: BotcampCore.Unit; let lesson: Lesson; var id: String { lesson.id } }
    struct ReviewTarget: Identifiable { let lesson: Lesson; let refs: [MissedRef]; let id = UUID() }

    private var completed: Set<String> { Set(records.map(\.lessonId)) }
    private var profile: PlayerProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    reviewCard
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
            .fullScreenCover(item: $reviewing) { t in
                LessonPlayerView(unit: content.course.units[0], lesson: t.lesson, completed: completed, reviewRefs: t.refs)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onChange(of: autoStart.wrappedValue) { _, go in
                guard go else { return }
                autoStart.wrappedValue = false
                if let next = content.planner.nextLesson(completed: completed, hasPro: pro.hasPro, startUnitId: profile?.startUnitId) {
                    playing = .init(unit: next.0, lesson: next.1)
                }
            }
        }
    }

    private var header: some View {
        let streak = profile?.streak.displayed(now: .now) ?? 0
        let rung = content.planner.currentRung(completed: completed)
        let broken = profile.map { Moments.streakBroken($0.streak, now: .now) } ?? false
        let goal = DailyGoal(lessonsPerDay: profile?.dailyGoal ?? 1)
        let today = ProgressWriter.todayCount(records)
        return HStack(spacing: 12) {
            if broken { SleepingSarge(size: 84) } else { SargeByte(pose: .idle, size: 84) }
            VStack(alignment: .leading, spacing: 4) {
                Text(broken ? "Sarge dozed off. Wake him with a lesson!" : streak == 0 ? "Ready, recruit?" : "\(streak)-day streak. Keep it up!").font(.headline)
                XPBar(to: goal.progress(lessonsToday: today), label: "Daily goal: \(min(today, goal.lessonsPerDay))/\(goal.lessonsPerDay) lessons")
                Text("You're here: \(content.course.rungs[safe: rung]?.title ?? "Chat")").font(.subheadline).foregroundStyle(.secondary)
                if let next = content.planner.nextLesson(completed: completed, hasPro: pro.hasPro, startUnitId: profile?.startUnitId) {
                    Button("Start: \(next.1.title)") { playing = .init(unit: next.0, lesson: next.1) }
                        .buttonStyle(ChunkyButtonStyle()).padding(.top, 4)
                }
            }
        }
        .padding().background(.white, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var reviewCard: some View {
        let refs = ReviewBuilder.steps(for: missed.map(\.ref), in: content.course).map(\.0)
        if !refs.isEmpty, let lesson = ReviewBuilder.lesson(for: refs, in: content.course) {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill").font(.title).foregroundStyle(Color.brandOrange)
                VStack(alignment: .leading) {
                    Text("Review mode").font(.headline)
                    Text("\(missed.count) question\(missed.count == 1 ? "" : "s") to practice").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Practice") { reviewing = ReviewTarget(lesson: lesson, refs: refs) }.buttonStyle(.borderedProminent).tint(.brandOrange)
            }
            .padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var statsPill: some View {
        HStack(spacing: 10) {
            StreakFlame(streak: profile?.streak.displayed(now: .now) ?? 0, size: 16)
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
                let state = content.planner.state(of: lesson, in: unit, completed: completed, hasPro: pro.hasPro, startUnitId: profile?.startUnitId)
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
