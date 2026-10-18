import SwiftUI
import SwiftData
import BotcampCore

/// "Plan your first project": native port of the web advisor, with links back into units.
struct CapstoneView: View {
    @Environment(CourseStore.self) private var content
    @Query private var records: [LessonRecord]
    @AppStorage("capstone.idea") private var idea = ""
    @State private var goal: Advisor.Goal?
    @State private var level: Advisor.Level?
    @State private var budget: Advisor.Budget?
    @State private var priority: Advisor.Priority?
    @State private var plan: Advisor.Plan?
    @State private var openUnit: BotcampCore.Unit?

    private var completed: Set<String> { Set(records.map(\.lessonId)) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            SargeByte(pose: .thinking, size: 72)
                            Text("Describe your idea and I'll draw up a setup plan, plus which units to lean on.")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        }
                        question("1. What's your idea?") {
                            TextField("e.g. A faceless YouTube channel about crypto history", text: $idea, axis: .vertical)
                                .lineLimit(2...)
                                .padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                        question("2. What do you want to make?") { chips(Advisor.Goal.allCases, Advisor.goalLabels, $goal) }
                        question("3. Your AI experience") { chips(Advisor.Level.allCases, Advisor.levelLabels, $level) }
                        question("4. Monthly budget") { chips(Advisor.Budget.allCases, Advisor.budgetLabels, $budget) }
                        question("5. What matters most?") { chips(Advisor.Priority.allCases, Advisor.priorityLabels, $priority) }
                        Button("Get my plan") {
                            guard let goal else { return }
                            withAnimation { plan = Advisor.plan(.init(idea: idea, goal: goal, level: level, budget: budget, priority: priority)) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation { proxy.scrollTo("plan", anchor: .top) } }
                        }
                        .buttonStyle(ChunkyButtonStyle()).disabled(goal == nil)
                        if goal == nil { Text("Pick what you want to make to continue.").font(.caption).foregroundStyle(.secondary) }
                        if let plan { PlanCard(plan: plan, rungs: content.course.rungs, completed: completed, units: content.course.units, lastChecked: content.course.lastChecked) { openUnit = $0 }.id("plan") }
                    }
                    .padding()
                }
            }
            .background(Color.brandCream.ignoresSafeArea())
            .navigationTitle("Plan your project")
            .sheet(item: $openUnit) { UnitSummarySheet(unit: $0) }
        }
    }

    private func question<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); c() }
    }

    private func chips<T: Hashable>(_ all: [T], _ labels: [T: String], _ sel: Binding<T?>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(all, id: \.self) { v in
                Text(labels[v] ?? "")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(sel.wrappedValue == v ? Color.brandLime : .white, in: Capsule())
                    .overlay(Capsule().stroke(Color.brandNavy, lineWidth: sel.wrappedValue == v ? 2.5 : 1))
                    .onTapGesture { sel.wrappedValue = v }
            }
        }
    }
}

struct PlanCard: View {
    let plan: Advisor.Plan
    let rungs: [Rung]
    let completed: Set<String>
    let units: [BotcampCore.Unit]
    let lastChecked: String
    let open: (BotcampCore.Unit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAN FOR").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
            Text(plan.idea).font(.title2.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
            Group { Text("Best model: ").bold() + Text(plan.model) }.fixedSize(horizontal: false, vertical: true)
            Group { Text("Alternative: ").bold() + Text(plan.alternative) }.fixedSize(horizontal: false, vertical: true)
            WrappingHStack(spacing: 6, lineSpacing: 6) {
                ForEach(Array(rungs.enumerated()), id: \.offset) { i, r in
                    Text(r.title)
                        .font(.caption.weight(i == plan.rung ? .heavy : .regular))
                        .foregroundStyle(Color.brandNavy)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .background(i == plan.rung ? Color.brandLime : Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("Learn these first").font(.headline)
            ForEach(plan.learnFirst, id: \.self) { link($0) }
            Text("Set it up, step by step").font(.headline)
            ForEach(Array(plan.steps.enumerated()), id: \.offset) { i, s in
                Text("\(i + 1). \(s)").fixedSize(horizontal: false, vertical: true)
            }
            ForEach(plan.notes, id: \.self) { n in
                Label {
                    Text(n).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                }
                .font(.subheadline)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandYellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
            Text(plan.teamIsNow ? "Level up: your subagent team" : "Later: your subagent team").font(.headline)
            ForEach(Array(plan.team.enumerated()), id: \.offset) { i, s in
                Text("\(i + 1). \(s)").fixedSize(horizontal: false, vertical: true)
            }
            Text("How: in Claude Code, create agents in .claude/agents/; in n8n, use one AI Agent node per role with a router. Start with 2 agents, not 5.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            link("m9")
            Text("Model facts last checked \(lastChecked).").font(.caption).foregroundStyle(.secondary)
            link("m2")
            ShareLink(item: shareText) { Label("Share my plan", systemImage: "square.and.arrow.up") }
        }
        .padding().background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private func link(_ id: String) -> some View {
        if let u = units.first(where: { $0.id == id }) {
            let done = u.lessons.allSatisfy { completed.contains($0.id) }
            Button { open(u) } label: {
                Label {
                    Text("Unit \(u.number): \(u.title)")
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: done ? "checkmark.circle.fill" : "book.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var shareText: String {
        (["Botcamp plan for: \(plan.idea)", "Best model: \(plan.model)", "Alternative: \(plan.alternative)", "", "Steps:"]
         + plan.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }).joined(separator: "\n")
    }
}

/// Lightweight unit preview opened from capstone links; the path itself lives on the Learn tab.
struct UnitSummarySheet: View {
    let unit: BotcampCore.Unit
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { Text(unit.blurb) }
                Section("Lessons") { ForEach(unit.lessons) { Text($0.title) } }
                Section { Text("Find Unit \(unit.number) on the Learn tab to play it.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Unit \(unit.number): \(unit.title)")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
