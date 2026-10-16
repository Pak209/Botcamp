import Foundation

/// Pure answer checking, shared by the SwiftUI step views and tests.
public enum Grader {
    public static func check(_ c: Choice, picked: Int) -> Bool { picked == c.answer }
    public static func check(_ t: TrueFalse, picked: Bool) -> Bool { picked == t.answer }
    public static func check(_ m: MultiSelect, picked: Set<Int>) -> Bool { picked == Set(m.answers) }
    public static func check(_ s: SpotBetter, picked: Int) -> Bool { picked == s.better }
    /// Correct when every helpful chip is on and no unhelpful chip is on.
    public static func check(_ f: FixPrompt, picked: Set<Int>) -> Bool {
        picked == Set(f.chips.indices.filter { f.chips[$0].correct })
    }
    public static func check(_ o: Order, arranged: [String]) -> Bool { arranged == o.items }
    /// `chosen` maps a left term to the right meaning the user paired it with.
    public static func check(_ m: Match, chosen: [String: String]) -> Bool {
        m.pairs.allSatisfy { chosen[$0[0]] == $0[1] }
    }
    /// Handoff is self-checked: complete when every box is ticked.
    public static func check(_ h: Handoff, ticked: Set<Int>) -> Bool { ticked.count == h.checklist.count }
}
