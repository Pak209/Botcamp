import SwiftUI
import SwiftData
import BotcampCore

/// Plays a lesson's steps. Missed questions are re-queued at the end (no hearts, never blocks).
struct LessonPlayerView: View {
    let unit: BotcampCore.Unit
    let lesson: Lesson
    let completed: Set<String>
    /// Set when playing Review mode: refs[i] is the source of lesson.steps[i].
    var reviewRefs: [MissedRef]? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var queue: [Int] = []          // indices into lesson.steps
    @State private var position = 0
    @State private var feedback: Feedback?
    @State private var missedOnce = Set<Int>()
    @State private var finished: Result?

    struct Feedback { let correct: Bool; let explain: String? }
    struct Result { let xp: Int; let passed: Bool; let firstTryCorrect: Int; var xpBefore: Int = 0; var rankUp: Rank? = nil }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let finished { FinishView(result: finished, lesson: lesson) { dismiss() } }
            else if position < queue.count {
                let index = queue[position]
                ScrollView {
                    StepView(step: lesson.steps[index], onResult: { ok in answered(index: index, correct: ok) })
                        .id("\(position)-\(index)")
                        .padding()
                        .disabled(feedback != nil)
                }
                if let feedback { feedbackBar(feedback) }
            }
        }
        .background(Color.brandCream.ignoresSafeArea())
        .onAppear { if queue.isEmpty { queue = Array(lesson.steps.indices) } }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { Image(systemName: "xmark").font(.title3.bold()) }
            ProgressView(value: Double(min(position, queue.count)), total: Double(max(queue.count, 1)))
                .tint(.brandLime).scaleEffect(y: 2.5)
        }
        .padding().foregroundStyle(Color.brandNavy)
    }

    private func feedbackBar(_ f: Feedback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(f.correct ? "Nice!" : "Not quite. It'll come back at the end.", systemImage: f.correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.headline)
            if let e = f.explain { Text(e).font(.subheadline) }
            Button("Continue") { advance() }.buttonStyle(ChunkyButtonStyle(color: f.correct ? .brandLime : .brandOrange))
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background((f.correct ? Color.brandLime : Color.brandOrange).opacity(0.25))
    }

    private func answered(index: Int, correct: Bool) {
        let step = lesson.steps[index]
        guard step.isGraded else { advance(); return }
        if !correct {
            if !missedOnce.contains(index) && reviewRefs == nil { ProgressWriter.recordMiss(lessonId: lesson.id, stepIndex: index, in: context) }
            missedOnce.insert(index); queue.append(index)
        }
        feedback = Feedback(correct: correct, explain: step.explanation)
    }

    private func advance() {
        feedback = nil
        position += 1
        if position >= queue.count { finish() }
    }

    private func finish() {
        let firstTry = lesson.steps.indices.filter { lesson.steps[$0].isGraded && !missedOnce.contains($0) }.count
        let passed = XPRules.passed(lesson, correct: firstTry)
        let before = ProgressWriter.profile(in: context).totalXP
        var xp = 0
        if passed { xp = ProgressWriter.finish(lesson: lesson, mistakes: missedOnce.count, completed: completed, in: context) }
        if let refs = reviewRefs {
            let keep = Set(ReviewBuilder.remaining(after: refs, missedInSession: missedOnce))
            ProgressWriter.clearReviewed(refs.filter { !keep.contains($0) }, in: context)
        }
        let profile = ProgressWriter.profile(in: context)
        let today = (try? context.fetch(FetchDescriptor<LessonRecord>())).map { ProgressWriter.todayCount($0) } ?? 0
        ReminderScheduler.reschedule(profile: profile, lessonsToday: today)
        finished = Result(xp: xp, passed: passed, firstTryCorrect: firstTry, xpBefore: before, rankUp: Moments.rankUp(from: before, to: before + xp))
    }
}

private extension Step {
    var explanation: String? {
        switch self {
        case .choice(let v): v.explain; case .trueFalse(let v): v.explain; case .multiSelect(let v): v.explain
        case .spotBetter(let v): v.explain; case .fixPrompt(let v): v.explain
        default: nil
        }
    }
}

struct FinishView: View {
    let result: LessonPlayerView.Result
    let lesson: Lesson
    let done: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            if let rank = result.rankUp { LevelUpBurst(rank: rank) }
            else { SargeByte(pose: result.passed ? .cheer : .thinking, size: 160) }
            Text(result.passed ? "Lesson complete!" : "Almost there").font(.largeTitle.weight(.heavy))
            if result.passed {
                Label("+\(result.xp) XP", systemImage: "bolt.fill").font(.title2.bold()).foregroundStyle(Color.brandTeal)
                XPBar(from: Moments.rankProgress(xp: result.xpBefore) <= Moments.rankProgress(xp: result.xpBefore + result.xp) ? Moments.rankProgress(xp: result.xpBefore) : 0,
                      to: Moments.rankProgress(xp: result.xpBefore + result.xp),
                      label: "\(Rank.forXP(result.xpBefore + result.xp).title) · \(result.xpBefore + result.xp) XP")
                    .padding(.horizontal, 30)
            } else {
                Text("You got \(result.firstTryCorrect) of \(lesson.gradedCount) on the first try. Pass mark is \(Int(lesson.passFraction * 100))%. Give it another go.")
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Continue", action: done).buttonStyle(ChunkyButtonStyle())
        }.padding()
    }
}
