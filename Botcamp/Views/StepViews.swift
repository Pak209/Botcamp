import SwiftUI
import BotcampCore

/// Dispatches a Step to its view. Every view calls `onResult(correct)` exactly once.
struct StepView: View {
    let step: Step
    let onResult: (Bool) -> Void
    var body: some View {
        switch step {
        case .explain(let v): ExplainStepView(step: v, onResult: onResult)
        case .choice(let v): ChoiceStepView(question: v.question, options: v.options) { onResult(Grader.check(v, picked: $0)) }
        case .trueFalse(let v): ChoiceStepView(question: "True or false?\n\(v.statement)", options: ["True", "False"]) { onResult(Grader.check(v, picked: $0 == 0)) }
        case .multiSelect(let v): MultiSelectStepView(step: v, onResult: onResult)
        case .spotBetter(let v): SpotBetterStepView(step: v, onResult: onResult)
        case .fixPrompt(let v): FixPromptStepView(step: v, onResult: onResult)
        case .match(let v): MatchStepView(step: v, onResult: onResult)
        case .order(let v): OrderStepView(step: v, onResult: onResult)
        case .handoff(let v): HandoffStepView(step: v, onResult: onResult)
        case .unknown:
            VStack { Text("This lesson needs a newer version of Botcamp."); Button("Skip") { onResult(true) }.buttonStyle(ChunkyButtonStyle()) }
        }
    }
}

struct StepTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title2.weight(.heavy))
            .foregroundStyle(Color.brandNavy)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OptionRow: View {
    let text: String
    let selected: Bool
    var body: some View {
        Text(text)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(selected ? Color.brandTeal.opacity(0.25) : .white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.brandTeal : .gray.opacity(0.4), lineWidth: selected ? 3 : 1.5))
            .contentShape(Rectangle())
    }
}

struct ExplainStepView: View {
    let step: Explain
    let onResult: (Bool) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(text: step.title)
            if let d = step.diagram { FlowDiagram(boxes: d) }
            Text(step.text).font(.body).fixedSize(horizontal: false, vertical: true)
            if let note = step.note { Label(note, systemImage: "calendar").font(.footnote).foregroundStyle(.secondary) }
            Button("Got it") { onResult(true) }.buttonStyle(ChunkyButtonStyle()).padding(.top)
        }
    }
}

struct ChoiceStepView: View {
    let question: String
    let options: [String]
    let check: (Int) -> Void
    @State private var picked: Int?
    var body: some View {
        VStack(spacing: 12) {
            StepTitle(text: question)
            ForEach(options.indices, id: \.self) { i in
                OptionRow(text: options[i], selected: picked == i).onTapGesture { picked = i }
            }
            Button("Check") { if let picked { check(picked) } }.buttonStyle(ChunkyButtonStyle()).disabled(picked == nil).padding(.top)
        }
    }
}

struct MultiSelectStepView: View {
    let step: MultiSelect
    let onResult: (Bool) -> Void
    @State private var picked = Set<Int>()
    var body: some View {
        VStack(spacing: 12) {
            StepTitle(text: step.question)
            Text("Select all that apply")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(step.options.indices, id: \.self) { i in
                OptionRow(text: step.options[i], selected: picked.contains(i)).onTapGesture { picked.formSymmetricDifference([i]) }
            }
            Button("Check") { onResult(Grader.check(step, picked: picked)) }.buttonStyle(ChunkyButtonStyle()).disabled(picked.isEmpty).padding(.top)
        }
    }
}

struct SpotBetterStepView: View {
    let step: SpotBetter
    let onResult: (Bool) -> Void
    @State private var picked: Int?
    var body: some View {
        VStack(spacing: 12) {
            StepTitle(text: step.question)
            ForEach([0, 1], id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    Text(i == 0 ? "PROMPT A" : "PROMPT B").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                    OptionRow(text: i == 0 ? step.a : step.b, selected: picked == i).font(.system(.callout, design: .monospaced))
                }.onTapGesture { picked = i }
            }
            Button("Check") { if let picked { onResult(Grader.check(step, picked: picked)) } }.buttonStyle(ChunkyButtonStyle()).disabled(picked == nil)
        }
    }
}

struct FixPromptStepView: View {
    let step: FixPrompt
    let onResult: (Bool) -> Void
    @State private var on = Set<Int>()
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(text: "Fix the prompt")
            Text("Tap the pieces that make this prompt stronger.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(step.base).fixedSize(horizontal: false, vertical: true)
                ForEach(on.sorted(), id: \.self) { i in
                    Text(step.chips[i].text)
                        .foregroundStyle(Color.brandOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(.callout, design: .monospaced)).padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            FlexibleChips(labels: step.chips.map(\.label), selected: on) { on.formSymmetricDifference([$0]) }
            Button("Check") { onResult(Grader.check(step, picked: on)) }.buttonStyle(ChunkyButtonStyle()).disabled(on.isEmpty)
        }
    }
}

struct FlexibleChips: View {
    let labels: [String]
    let selected: Set<Int>
    let toggle: (Int) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(labels.indices, id: \.self) { i in
                Button { toggle(i) } label: {
                    Text("+ \(labels[i])")
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(selected.contains(i) ? Color.brandLime : .white, in: Capsule())
                        .overlay(Capsule().stroke(Color.brandNavy, lineWidth: 2))
                }.foregroundStyle(Color.brandNavy)
            }
        }
    }
}

/// Tap a term, then tap its meaning. Meanings are shuffled once per appearance.
struct MatchStepView: View {
    let step: Match
    let onResult: (Bool) -> Void
    @State private var meanings: [String] = []
    @State private var activeTerm: String?
    @State private var chosen: [String: String] = [:]
    var body: some View {
        VStack(spacing: 12) {
            StepTitle(text: step.prompt)
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 8) {
                    ForEach(step.pairs.map { $0[0] }, id: \.self) { term in
                        OptionRow(text: term + (chosen[term] != nil ? " ✓" : ""), selected: activeTerm == term)
                            .onTapGesture { activeTerm = term }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 8) {
                    ForEach(meanings, id: \.self) { m in
                        OptionRow(text: m, selected: chosen.values.contains(m)).font(.footnote)
                            .onTapGesture {
                                guard let t = activeTerm else { return }
                                chosen = chosen.filter { $0.value != m }
                                chosen[t] = m; activeTerm = nil
                            }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            Button("Check") { onResult(Grader.check(step, chosen: chosen)) }
                .buttonStyle(ChunkyButtonStyle()).disabled(chosen.count < step.pairs.count)
        }
        .onAppear { if meanings.isEmpty { meanings = step.pairs.map { $0[1] }.shuffled() } }
    }
}

struct OrderStepView: View {
    let step: Order
    let onResult: (Bool) -> Void
    @State private var items: [String] = []
    var body: some View {
        VStack(spacing: 12) {
            StepTitle(text: step.prompt)
            Text("Use the arrows to reorder.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(items.enumerated()), id: \.element) { i, item in
                HStack(alignment: .center, spacing: 8) {
                    Text("\(i + 1).").bold()
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    Button { move(i, -1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0)
                    Button { move(i, 1) } label: { Image(systemName: "chevron.down") }.disabled(i == items.count - 1)
                }
                .padding().background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
            Button("Check") { onResult(Grader.check(step, arranged: items)) }.buttonStyle(ChunkyButtonStyle())
        }
        .onAppear {
            guard items.isEmpty else { return }
            var s = step.items.shuffled()
            while s == step.items && s.count > 1 { s.shuffle() }
            items = s
        }
    }
    private func move(_ i: Int, _ d: Int) { withAnimation { items.swapAt(i, i + d) } }
}
