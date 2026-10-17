import Foundation

/// Duolingo-style first run, kept pure so every rule is testable.
/// Flow: hello → why → level → daily goal → reminder → first win → plan ready.
/// Every screen can be skipped; skipped answers fall back to safe defaults.
public enum Onboarding {

    public enum Step: Int, CaseIterable, Sendable {
        case hello, why, level, dailyGoal, reminder, firstWin, planReady
    }

    /// "Why learn AI?"
    public enum Reason: String, CaseIterable, Sendable {
        case work, sideMoney, fun, school
        public var label: String {
            switch self { case .work: "For work"; case .sideMoney: "Side money"; case .fun: "Just for fun"; case .school: "School or kids" }
        }
        /// SF Symbol shown on the card.
        public var icon: String {
            switch self { case .work: "briefcase.fill"; case .sideMoney: "dollarsign.circle.fill"; case .fun: "gamecontroller.fill"; case .school: "graduationcap.fill" }
        }
        /// Sarge's reply after the pick.
        public var reply: String {
            switch self {
            case .work: "Nice. AI can save you hours."
            case .sideMoney: "Love it. Let's build something."
            case .fun: "Fun is the best way to learn."
            case .school: "Great. You'll learn it together."
            }
        }
    }

    /// "How much do you know?"
    public enum Level: String, CaseIterable, Sendable {
        case new, some, comfy
        public var label: String {
            switch self { case .new: "I'm brand new"; case .some: "I tried ChatGPT a bit"; case .comfy: "I use AI a lot" }
        }
        public var detail: String {
            switch self { case .new: "Start from zero"; case .some: "Skip the very basics"; case .comfy: "Jump to prompting" }
        }
        public var icon: String {
            switch self { case .new: "leaf.fill"; case .some: "bolt.fill"; case .comfy: "flame.fill" }
        }
        /// Number of bars filled on the card (1…3).
        public var bars: Int { Level.allCases.firstIndex(of: self)! + 1 }
        /// Starting unit. Only free units, so placement never hits the paywall.
        public var startUnitId: String {
            switch self { case .new: "m1"; case .some: "m2"; case .comfy: "m3" }
        }
    }

    /// Daily goal in minutes; lessons are ~3 min, so minutes map onto DailyGoal.options.
    public static let minuteOptions = [3, 5, 10, 15]
    public static let defaultMinutes = 5
    public static func lessonsPerDay(minutes: Int) -> Int {
        switch minutes { case ..<5: 1; case 5..<10: 2; case 10..<15: 3; default: 5 }
    }
    public static func minutesLabel(_ m: Int) -> (title: String, tag: String) {
        switch m {
        case ..<5: ("\(m) min a day", "Easy")
        case 5..<10: ("\(m) min a day", "Steady")
        case 10..<15: ("\(m) min a day", "Serious")
        default: ("\(m) min a day", "Intense")
        }
    }

    /// The tiny first win: one question, two cards.
    public struct MiniQuestion: Equatable, Sendable {
        public let prompt: String
        public let options: [String]
        public let answer: Int
        public let right: String
        public let wrong: String
    }
    public static let firstWin = MiniQuestion(
        prompt: "Which ask gets a better answer?",
        options: ["Write something.", "Write a 3-line birthday note for my mom."],
        answer: 1,
        right: "Yes! More detail, better answer.",
        wrong: "Close! Try the one with details.")
    public static let firstWinXP = 10
    public static let firstWinRetryXP = 5
    public static let firstWinLessonId = "onboarding-first-win"

    /// What Sarge says on each screen. Short lines only (checked by tests).
    public static func sarge(_ step: Step) -> String {
        switch step {
        case .hello: "Hi! I'm Sarge Byte. Let's learn AI!"
        case .why: "Why do you want to learn AI?"
        case .level: "How much do you know?"
        case .dailyGoal: "Pick a daily goal."
        case .reminder: "Want a little nudge each day?"
        case .firstWin: "Quick one. You've got this!"
        case .planReady: "Your plan is ready!"
        }
    }

    /// Everything the flow collected, ready to save to the profile.
    public struct Result: Equatable, Sendable {
        public var reason: Reason?
        public var level: Level?
        public var dailyMinutes: Int
        public var lessonsPerDay: Int
        public var startUnitId: String
        public var wantsReminder: Bool
        public var xpEarned: Int
        public var didFirstWin: Bool
    }

    public struct State: Equatable, Sendable {
        public private(set) var step: Step = .hello
        public var reason: Reason?
        public var level: Level?
        public var minutes: Int = Onboarding.defaultMinutes
        public var wantsReminder = false
        public private(set) var firstWinPick: Int?
        public private(set) var firstWinTries = 0
        public private(set) var firstWinSolved = false
        public private(set) var finished = false

        public init() {}

        /// 0…1 for the top bar. Hello is 0; plan ready is full.
        public var progress: Double { Double(step.rawValue) / Double(Step.allCases.count - 1) }
        public var isLast: Bool { step == .planReady }

        /// Continue is enabled only once the screen's question is answered.
        public var canContinue: Bool {
            switch step {
            case .why: reason != nil
            case .level: level != nil
            case .firstWin: firstWinSolved
            default: true
            }
        }

        public var xpEarned: Int {
            guard firstWinSolved else { return 0 }
            return firstWinTries <= 1 ? Onboarding.firstWinXP : Onboarding.firstWinRetryXP
        }

        /// Tap an answer in the first-win lesson. Returns true if right. Locked once solved.
        @discardableResult
        public mutating func answerFirstWin(_ index: Int) -> Bool {
            guard step == .firstWin, !firstWinSolved, Onboarding.firstWin.options.indices.contains(index) else { return firstWinSolved }
            firstWinPick = index
            firstWinTries += 1
            if index == Onboarding.firstWin.answer { firstWinSolved = true }
            return firstWinSolved
        }

        /// Moves forward if allowed. On the last step it finishes.
        public mutating func next() {
            guard canContinue else { return }
            advance()
        }

        /// Skips the current screen, keeping defaults for its answer.
        public mutating func skip() { advance() }

        /// Skips the rest of setup with defaults and jumps to "plan ready".
        public mutating func skipAll() { step = .planReady }

        public mutating func back() {
            guard !finished, step.rawValue > 0, let s = Step(rawValue: step.rawValue - 1) else { return }
            step = s
        }

        private mutating func advance() {
            if let s = Step(rawValue: step.rawValue + 1) { step = s } else { finished = true }
        }

        public var result: Result {
            Result(reason: reason, level: level, dailyMinutes: minutes,
                   lessonsPerDay: Onboarding.lessonsPerDay(minutes: minutes),
                   startUnitId: (level ?? .new).startUnitId,
                   wantsReminder: wantsReminder, xpEarned: xpEarned, didFirstWin: firstWinSolved)
        }
    }

    /// Simple copy rule: no line longer than `max` words.
    public static func wordCount(_ s: String) -> Int { s.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
}
