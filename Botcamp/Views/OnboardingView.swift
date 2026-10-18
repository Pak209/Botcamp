import SwiftUI
import SwiftData
import BotcampCore

/// Duolingo-style first run. One question per screen, big cards, springy progress bar.
/// The rules live in `BotcampCore.Onboarding` (tested); this file is only the look and feel.
struct OnboardingView: View {
    /// Called after the profile is saved. `true` = jump straight into the first lesson.
    var onFinish: (Bool) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CourseStore.self) private var content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flow = Onboarding.State()
    @State private var remindAt = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? .now
    @State private var reminderAllowed = false
    @State private var bubble: String = Onboarding.sarge(.hello)
    @State private var tapCount = 0
    @State private var winCount = 0
    @State private var missCount = 0
    @State private var showConfetti = false
    @State private var goingBack = false

    var body: some View {
        VStack(spacing: 16) {
            topBar
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .top) {
                            screen
                                .id(flow.step)
                                .transition(screenTransition)
                        }
                        .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                        .id("onboarding-top")
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: flow.step) { _, _ in
                        proxy.scrollTo("onboarding-top", anchor: .top)
                    }
                }
            }
            bottomButton
        }
        .padding()
        .background(Color.brandCream.ignoresSafeArea())
        .overlay { if showConfetti && !reduceMotion { ConfettiBurst().allowsHitTesting(false) } }
        .sensoryFeedback(.selection, trigger: tapCount)
        .sensoryFeedback(.success, trigger: winCount)
        .sensoryFeedback(.error, trigger: missCount)
        .interactiveDismissDisabled()
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { go(back: true) { flow.back() } } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.heavy))
            }
            .opacity(flow.step == .hello || flow.isLast ? 0 : 1)
            .disabled(flow.step == .hello || flow.isLast)
            .accessibilityLabel("Back")
            .layoutPriority(1)

            SpringProgressBar(value: flow.progress)
                .frame(minWidth: 48, maxWidth: .infinity)

            Button("Skip") { tapCount += 1; go { flow.skip() } }
                .font(.subheadline.weight(.heavy))
                .opacity(flow.isLast ? 0 : 1)
                .disabled(flow.isLast)
                .accessibilityHint("Skip this question")
                .layoutPriority(1)
        }
        .foregroundStyle(Color.brandNavy)
    }

    private var bottomButton: some View {
        VStack(spacing: 10) {
            Button(continueTitle) { continueTapped() }
                .buttonStyle(ChunkyButtonStyle(color: flow.canContinue ? .brandTeal : .gray.opacity(0.35)))
                .disabled(!flow.canContinue)
            if flow.step == .hello {
                Button { tapCount += 1; go { flow.skipAll() } } label: {
                    Text("Set up later")
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.brandNavy.opacity(0.7))
            }
        }
    }

    private var continueTitle: String {
        switch flow.step {
        case .hello: "Let's go!"
        case .reminder: "Not now"
        case .planReady: "Start Unit \(startUnit?.number ?? 1)"
        default: "Continue"
        }
    }

    private var screenTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let inEdge: Edge = goingBack ? .leading : .trailing, outEdge: Edge = goingBack ? .trailing : .leading
        return .asymmetric(insertion: .move(edge: inEdge).combined(with: .opacity), removal: .move(edge: outEdge).combined(with: .opacity))
    }

    private func go(back: Bool = false, _ change: () -> Void) {
        goingBack = back
        showConfetti = false
        let before = flow.step
        if reduceMotion { change() } else { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { change() } }
        if flow.step != before { bubble = Onboarding.sarge(flow.step) }
        if flow.finished { finish() }
    }

    private func continueTapped() {
        tapCount += 1
        if flow.step == .reminder { flow.wantsReminder = false }
        go { flow.next() }
    }

    // MARK: Screens

    @ViewBuilder private var screen: some View {
        switch flow.step {
        case .hello: helloScreen
        case .why: whyScreen
        case .level: levelScreen
        case .dailyGoal: dailyGoalScreen
        case .reminder: reminderScreen
        case .firstWin: firstWinScreen
        case .planReady: planScreen
        }
    }

    private var helloScreen: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            SpeechBubble(text: bubble)
            WavingSarge(size: 200)
            Spacer()
        }
    }

    private var whyScreen: some View {
        VStack(spacing: 18) {
            SargeRow(text: bubble, pose: .thinking)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(Onboarding.Reason.allCases, id: \.self) { r in
                    Button {
                        tapCount += 1; flow.reason = r; bubble = r.reply
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: r.icon).font(.system(size: 40)).foregroundStyle(Color.brandTeal)
                            Text(r.label)
                                .font(.headline.weight(.heavy))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                    .buttonStyle(BigCardStyle(selected: flow.reason == r))
                }
            }
        }
    }

    private var levelScreen: some View {
        VStack(spacing: 14) {
            SargeRow(text: bubble, pose: .thinking)
            ForEach(Onboarding.Level.allCases, id: \.self) { l in
                Button { tapCount += 1; flow.level = l } label: {
                    HStack(alignment: .center, spacing: 14) {
                        LevelBars(filled: l.bars)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.label).font(.headline.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                            Text(l.detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(BigCardStyle(selected: flow.level == l))
            }
        }
    }

    private var dailyGoalScreen: some View {
        VStack(spacing: 14) {
            SargeRow(text: bubble, pose: .idle)
            ForEach(Onboarding.minuteOptions, id: \.self) { m in
                let label = Onboarding.minutesLabel(m)
                Button { tapCount += 1; flow.minutes = m } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Text(label.title)
                            .font(.headline.weight(.heavy))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        Text(label.tag)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .buttonStyle(BigCardStyle(selected: flow.minutes == m))
            }
        }
    }

    private var reminderScreen: some View {
        VStack(spacing: 18) {
            SargeRow(text: bubble, pose: .cheer)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72)).foregroundStyle(Color.brandOrange)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            Text("I'll ping you once a day.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            DatePicker("Time", selection: $remindAt, displayedComponents: .hourAndMinute)
                .font(.headline)
                .padding().background(.white, in: RoundedRectangle(cornerRadius: 16))
            Button {
                tapCount += 1
                Task {
                    let ok = await ReminderScheduler.requestPermission()
                    await MainActor.run {
                        reminderAllowed = ok
                        flow.wantsReminder = true
                        go { flow.next() }
                    }
                }
            } label: { Label("Yes, remind me", systemImage: "bell.fill").frame(maxWidth: .infinity) }
            .buttonStyle(BigCardStyle(selected: true))
            Text("You can turn this off in Profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var firstWinScreen: some View {
        let q = Onboarding.firstWin
        return VStack(spacing: 16) {
            SargeRow(text: bubble, pose: flow.firstWinSolved ? .cheer : .thinking)
            Text(q.prompt)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                Button {
                    tapCount += 1
                    let right = flow.answerFirstWin(i)
                    if right { winCount += 1; bubble = q.right; showConfetti = true }
                    else { missCount += 1; bubble = q.wrong }
                } label: {
                    Text("\u{201C}\(option)\u{201D}")
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(BigCardStyle(selected: flow.firstWinPick == i, tint: tint(for: i)))
                .modifier(Shake(amount: flow.firstWinPick == i && !flow.firstWinSolved && !reduceMotion ? CGFloat(flow.firstWinTries) : 0))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: flow.firstWinTries)
                .disabled(flow.firstWinSolved)
            }
            if flow.firstWinSolved {
                XPPop(xp: flow.xpEarned)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55), value: flow.firstWinSolved)
    }

    private func tint(for i: Int) -> Color {
        guard flow.firstWinPick == i else { return .brandTeal }
        return i == Onboarding.firstWin.answer ? .brandLime : .brandPink
    }

    private var planScreen: some View {
        let r = flow.result
        return VStack(spacing: 18) {
            SpeechBubble(text: bubble)
            StreakFlame(streak: r.didFirstWin ? 1 : 0, size: 72)
            Text(r.didFirstWin ? "Day 1 streak. Nice start!" : "Do a lesson to light it.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                PlanRow(icon: "clock.fill", text: "\(r.dailyMinutes) min a day")
                PlanRow(icon: "map.fill", text: "Start: Unit \(startUnit?.number ?? 1)")
                if r.xpEarned > 0 { PlanRow(icon: "bolt.fill", text: "+\(r.xpEarned) XP earned") }
                if r.wantsReminder && reminderAllowed { PlanRow(icon: "bell.fill", text: "Daily nudge is on") }
            }
            .padding().background(.white, in: RoundedRectangle(cornerRadius: 20))
            Spacer()
        }
        .onAppear { if !reduceMotion { showConfetti = true } }
    }

    private var startUnit: BotcampCore.Unit? {
        content.course.unit(id: flow.result.startUnitId) ?? content.course.units.first
    }

    // MARK: Save

    private func finish() {
        let r = flow.result
        let hm = Calendar.current.dateComponents([.hour, .minute], from: remindAt)
        let p = ProgressWriter.applyOnboarding(r, reminderHour: hm.hour ?? 19, reminderMinute: hm.minute ?? 0, in: context)
        if r.wantsReminder && reminderAllowed {
            p.remindersOn = true
            try? context.save()
            ReminderScheduler.reschedule(profile: p, lessonsToday: r.didFirstWin ? 1 : 0)
        }
        onFinish(true)
        dismiss()
    }
}

// MARK: - Pieces

/// Top progress bar that springs forward on each step.
struct SpringProgressBar: View {
    var value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.brandNavy.opacity(0.12))
                Capsule().fill(Color.brandLime)
                    .frame(width: max(16, g.size.width * min(1, max(0, value))))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.5)).frame(height: 4).padding(.horizontal, 8).padding(.top, 3)
                    }
            }
        }
        .frame(height: 16)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// Sarge's speech bubble. Text types out letter by letter; tap to show it all.
/// The full line is always laid out (invisibly) so the bubble is as tall as the
/// finished sentence and nothing truncates while it types.
struct SpeechBubble: View {
    var text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            bubbleText(text).opacity(0).accessibilityHidden(true)
            bubbleText(String(text.prefix(shown))).foregroundStyle(Color.brandNavy)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.brandNavy.opacity(0.15), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { shown = text.count }
        .task(id: text) {
            if reduceMotion { shown = text.count; return }
            shown = 0
            for i in 0...text.count {
                shown = i
                try? await Task.sleep(nanoseconds: 28_000_000)
                if Task.isCancelled { shown = text.count; return }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sarge says: \(text)")
    }

    private func bubbleText(_ string: String) -> some View {
        Text(string)
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Small Sarge next to his bubble, for question screens.
struct SargeRow: View {
    var text: String
    var pose: MascotPose
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SargeByte(pose: pose, size: 84)
            SpeechBubble(text: text)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Sarge waving hello: a happy wiggle plus a waving hand.
struct WavingSarge: View {
    var size: CGFloat = 200
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wave = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            SargeByte(pose: .cheer, size: size)
                .rotationEffect(.degrees(wave ? 4 : -4), anchor: .bottom)
            Text("\u{1F44B}")
                .font(.system(size: size * 0.28))
                .rotationEffect(.degrees(wave ? 25 : -15), anchor: .bottomLeading)
                .offset(x: size * 0.05, y: size * 0.05)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35).repeatCount(6, autoreverses: true), value: wave)
        .onAppear { if !reduceMotion { wave = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sarge Byte waves hello")
    }
}

/// Big tappable card that bounces when pressed and pops when picked.
struct BigCardStyle: ButtonStyle {
    var selected: Bool
    var tint: Color = .brandTeal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(Color.brandNavy)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? tint.opacity(0.22) : Color.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? tint : Color.brandNavy.opacity(0.2), lineWidth: 3)
            }
            // Same rule as ChunkyButtonStyle: depth behind the card, never a
            // shadow of the label (that draws the words twice).
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? tint : Color.brandNavy.opacity(0.2))
                    .offset(y: pressed ? 0 : 4)
            }
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.94 : (selected ? 1.02 : 1)))
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.45), value: pressed)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.5), value: selected)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 1–3 rising bars for the "how much do you know" cards.
struct LevelBars: View {
    var filled: Int
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= filled ? Color.brandTeal : Color.brandNavy.opacity(0.15))
                    .frame(width: 8, height: CGFloat(10 + i * 8))
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }
}

struct PlanRow: View {
    var icon: String
    var text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.brandTeal).frame(width: 28)
            Text(text)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// "+10 XP" pill that pops in after the first win.
struct XPPop: View {
    var xp: Int
    var body: some View {
        Label("+\(xp) XP", systemImage: "bolt.fill")
            .font(.title2.weight(.heavy))
            .foregroundStyle(Color.brandNavy)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.brandYellow, in: Capsule())
            .overlay(Capsule().stroke(Color.brandNavy, lineWidth: 3))
    }
}

/// Horizontal shake for a wrong pick. `amount` changes each miss to replay it.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}

/// One-shot confetti that falls from the top. Callers hide it when Reduce Motion is on.
struct ConfettiBurst: View {
    private struct Bit: Identifiable { let id: Int; let x: CGFloat; let drift: CGFloat; let spin: Double; let delay: Double; let color: Color; let size: CGFloat }
    private let bits: [Bit] = (0..<36).map { (i: Int) -> Bit in
        let r = { (n: Int) -> CGFloat in CGFloat((i * 9301 + n * 49297) % 233280) / 233280 }
        return Bit(id: i, x: r(1), drift: r(2) - 0.5, spin: Double(r(3)) * 720 - 360, delay: Double(r(4)) * 0.3,
                   color: [Color.brandTeal, .brandLime, .brandYellow, .brandPink, .brandOrange][i % 5], size: 6 + r(5) * 8)
    }
    @State private var fall = false
    var body: some View {
        GeometryReader { g in
            ZStack {
                ForEach(bits) { b in
                    RoundedRectangle(cornerRadius: 2).fill(b.color)
                        .frame(width: b.size, height: b.size * 0.6)
                        .rotationEffect(.degrees(fall ? b.spin : 0))
                        .position(x: g.size.width * b.x + (fall ? b.drift * 120 : 0),
                                  y: fall ? g.size.height + 20 : -20)
                        .opacity(fall ? 0 : 1)
                        .animation(.easeIn(duration: 1.6).delay(b.delay), value: fall)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { fall = true }
        .accessibilityHidden(true)
    }
}
