import Foundation

/// Native port of the web capstone advisor (get-up-to-speed/app.js `advise()`), recommendations unchanged.
public enum Advisor {
    public enum Goal: String, CaseIterable, Sendable { case write, code, media, research, automate }
    public enum Level: String, CaseIterable, Sendable { case new, some, pro }
    public enum Budget: String, CaseIterable, Sendable { case zero = "0", twenty = "20", hundred = "100" }
    public enum Priority: String, CaseIterable, Sendable { case quality, cost, privacy, speed }

    public static let goalLabels: [Goal: String] = [.write: "Writing / content", .code: "An app or website", .media: "Images / video / voice", .research: "Research / news", .automate: "Automate a business task"]
    public static let levelLabels: [Level: String] = [.new: "Brand new", .some: "Used ChatGPT a bit", .pro: "Comfortable"]
    public static let budgetLabels: [Budget: String] = [.zero: "$0", .twenty: "~$20", .hundred: "$100+"]
    public static let priorityLabels: [Priority: String] = [.quality: "Best quality", .cost: "Lowest cost", .privacy: "Privacy / local", .speed: "Speed / live info"]

    public struct Answers: Equatable, Sendable {
        public var idea: String; public var goal: Goal; public var level: Level?; public var budget: Budget?; public var priority: Priority?
        public init(idea: String = "", goal: Goal, level: Level? = nil, budget: Budget? = nil, priority: Priority? = nil) {
            self.idea = idea; self.goal = goal; self.level = level; self.budget = budget; self.priority = priority
        }
    }

    struct Recipe { let model, alt: String; let rung: Int; let units: [String]; let steps, team: [String] }

    static let recipes: [Goal: Recipe] = [
        .write: Recipe(model: "Claude Sonnet 5.5 (Claude Pro $20)", alt: "GPT-6 in ChatGPT (Go $8 / Plus $20)", rung: 1, units: ["m3", "m4"],
            steps: ["Make a Project (Claude) or Custom GPT and paste your brand voice, audience and 3 example posts into its instructions.", "Upload reference docs (outlines, past scripts).", "Prompt: 'Draft 5 hooks for [topic], then a 60-sec script for the best one.'", "Keep a 'rules' note: every time you fix the output, add a rule to the instructions.", "Batch: ask for a week of content in one table."],
            team: ["Researcher (Grok: pulls trending angles from X)", "Writer (Claude Sonnet: drafts)", "Editor (Haiku 5.5: cheap check for tone, length and facts)"]),
        .code: Recipe(model: "Claude Code or Grok Build (Grok 4.7) / Cursor", alt: "Codex (with a ChatGPT plan)", rung: 3, units: ["m3", "m7"],
            steps: ["Install a coding agent: Cursor or Grok Build (X Subscription) or Claude Code (Claude Pro).", "Make an empty folder and describe the app in 5 bullets: users, screens, data, must-haves, not-now.", "Ask: 'Plan this first, don't code yet.' Approve the plan.", "Let it build one screen at a time; run it after each step and paste back any errors.", "Commit to GitHub after every working step so you can undo."],
            team: ["Planner (Opus 5.5 / Grok 4.7 high reasoning: writes the spec)", "Builder agents (one per feature, working in parallel)", "Tester (Haiku 5.5: runs tests, reports failures)"]),
        .media: Recipe(model: "Nano Banana 2.1 / GPT Image 2.5 (images), Veo 3.1 or Kling 3.0 (video), ElevenLabs v4 (voice)", alt: "Grok Imagine (Premium $30; videos are watermarked)", rung: 2, units: ["m3", "m5"],
            steps: ["Write a shot list in chat: scene, subject, camera, mood. Use numbers, not adjectives.", "Generate key images first (Nano Banana / GPT Image) and pick a hero frame.", "Animate from that image (image-to-video in Veo or Kling) to keep the character consistent.", "Voice: ElevenLabs Starter ($6, commercial use). Clone only voices you have consent for.", "Assemble in CapCut or another editor. Avoid Sora: it was shut down in 2026."],
            team: ["Scriptwriter (Claude)", "Art director (generates and scores images)", "Producer (chains video and voice, checks timing)"]),
        .research: Recipe(model: "Grok 4.7 (live X and web search)", alt: "Gemini 4 Argon (Google AI Pro $19.99) for long documents", rung: 2, units: ["m1", "m4", "m6"],
            steps: ["Ask Grok: 'What changed in [topic] in the last 7 days? Cite every claim with links.'", "Open 2–3 sources yourself; never trust uncited numbers.", "Save a Project or Gem with your standing research questions.", "Turn it into a daily brief: a scheduled task or routine that sends you a summary every morning."],
            team: ["Scouts (one per source: X, news, Reddit)", "Verifier (cross-checks claims, drops uncited ones)", "Writer (formats the brief)"]),
        .automate: Recipe(model: "n8n + Claude Haiku 5.5 or Grok 4.7 via API", alt: "Zapier/Make with the built-in AI step (easier, pricier)", rung: 4, units: ["m8", "m10"],
            steps: ["Write the task as 'WHEN x happens, DO y, THEN z' (e.g. new email → classify → draft reply).", "Start n8n (cloud trial or self-hosted) and add the trigger node.", "Add an AI node with your API key (kept in n8n credentials, never in the prompt).", "Add the action node (Gmail draft, Notion row, Slack). Draft first, auto-send later.", "Run 20 real examples, log the mistakes and tighten the prompt."],
            team: ["Router (cheap model sorts incoming items)", "Specialist agents per category", "Human-approval step before anything is sent"]),
    ]

    public struct Plan: Equatable, Sendable {
        public var idea: String
        public var model: String
        public var alternative: String
        public var rung: Int
        /// Unit ids to learn first, sorted by unit number (m1…m10).
        public var learnFirst: [String]
        public var steps: [String]
        public var notes: [String]
        public var team: [String]
        /// True when the subagent team is shown as "Level up" rather than "Later".
        public var teamIsNow: Bool
    }

    public static func plan(_ a: Answers) -> Plan {
        let r = recipes[a.goal]!
        var model = r.model, alt = r.alt
        var notes: [String] = []
        var units = Set(r.units)
        var ordered = r.units
        if a.budget == .zero { model += " (start on the free tier)"; notes.append("Free tiers are enough to learn on. Upgrade when you hit limits daily.") }
        if a.priority == .privacy {
            alt = model; model = "Open weights: Qwen3.8-27B (Apache 2.0) run locally via Ollama/LM Studio"
            notes.append("Local models keep data on your machine but are weaker than frontier models.")
            units.formUnion(["m2", "m10"])
        }
        if a.priority == .cost && a.goal != .media { notes.append("Use a small model (Haiku 5.5, GPT-6 Luna, DeepSeek V4.1 Flash) for bulk steps."); units.insert("m10") }
        if a.priority == .speed { notes.append("For live info, Grok's X search is the differentiator.") }
        if a.level == .new {
            units.formUnion(["m1", "m3"])
            if r.rung > 2 { notes.append("New to AI? Do one week on the Chat and Projects rungs first. It makes everything below click.") }
        }
        let big = a.level != .new || a.budget == .hundred
        if big { units.insert("m9") }
        ordered = units.sorted { unitNumber($0) < unitNumber($1) }
        let idea = a.idea.trimmingCharacters(in: .whitespacesAndNewlines)
        return Plan(idea: idea.isEmpty ? "your idea" : idea, model: model, alternative: alt, rung: r.rung,
                    learnFirst: ordered, steps: r.steps, notes: notes, team: r.team, teamIsNow: big)
    }

    static func unitNumber(_ id: String) -> Int { Int(id.dropFirst()) ?? 0 }
}
