import Foundation

public struct Course: Codable, Equatable, Sendable {
    public var version: Int
    public var lastChecked: String
    public var rungs: [Rung]
    public var units: [Unit]
    public var glossary: [GlossaryTerm]

    public static func decode(_ data: Data) throws -> Course {
        let course = try JSONDecoder().decode(Course.self, from: data)
        try course.validate()
        return course
    }

    public func unit(id: String) -> Unit? { units.first { $0.id == id } }
    public var allLessons: [Lesson] { units.flatMap(\.lessons) }

    public struct ValidationError: Error, Equatable, CustomStringConvertible {
        public let description: String
    }

    /// Structural checks so a bad course.json fails loudly in tests, not at runtime.
    public func validate() throws {
        func fail(_ s: String) -> ValidationError { ValidationError(description: s) }
        var ids = Set<String>()
        for unit in units {
            if unit.lessons.isEmpty { throw fail("unit \(unit.id) has no lessons") }
            for lesson in unit.lessons {
                if !ids.insert(lesson.id).inserted { throw fail("duplicate lesson id \(lesson.id)") }
                if lesson.steps.isEmpty { throw fail("lesson \(lesson.id) has no steps") }
                for step in lesson.steps {
                    switch step {
                    case .choice(let q) where !q.options.indices.contains(q.answer):
                        throw fail("lesson \(lesson.id): answer out of range")
                    case .multiSelect(let q) where q.answers.contains { !q.options.indices.contains($0) }:
                        throw fail("lesson \(lesson.id): multiSelect answer out of range")
                    case .spotBetter(let q) where !(0...1).contains(q.better):
                        throw fail("lesson \(lesson.id): spotBetter must be 0 or 1")
                    case .match(let q) where q.pairs.contains { $0.count != 2 }:
                        throw fail("lesson \(lesson.id): match pairs need 2 items")
                    default: break
                    }
                }
            }
        }
        for term in glossary where unit(id: term.unitId) == nil {
            throw fail("glossary term \(term.term) points to unknown unit \(term.unitId)")
        }
    }
}

public struct Rung: Codable, Equatable, Sendable { public var title, detail, unitId: String }
public struct GlossaryTerm: Codable, Equatable, Hashable, Sendable { public var term, definition, unitId: String }

public struct Unit: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var subtitle: String
    public var blurb: String
    public var rung: Int
    public var isFree: Bool
    public var isStub: Bool
    public var lessons: [Lesson]
}

public struct Lesson: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var xp: Int
    public var isUnitCheck: Bool
    public var passFraction: Double
    public var steps: [Step]

    enum CodingKeys: String, CodingKey { case id, title, xp, isUnitCheck, passFraction, steps }
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 10
        isUnitCheck = try c.decodeIfPresent(Bool.self, forKey: .isUnitCheck) ?? false
        passFraction = try c.decodeIfPresent(Double.self, forKey: .passFraction) ?? 0
        steps = try c.decode([Step].self, forKey: .steps)
    }
    /// Number of graded steps (explain and handoff are not graded).
    public var gradedCount: Int { steps.filter(\.isGraded).count }
}

public struct Explain: Codable, Equatable, Sendable { public var title: String; public var text: String; public var diagram: [String]?; public var note: String? }
public struct Choice: Codable, Equatable, Sendable { public var question: String; public var options: [String]; public var answer: Int; public var explain: String? }
public struct TrueFalse: Codable, Equatable, Sendable { public var statement: String; public var answer: Bool; public var explain: String? }
public struct MultiSelect: Codable, Equatable, Sendable { public var question: String; public var options: [String]; public var answers: [Int]; public var explain: String? }
public struct SpotBetter: Codable, Equatable, Sendable { public var question: String; public var a: String; public var b: String; public var better: Int; public var explain: String? }
public struct FixPrompt: Codable, Equatable, Sendable {
    public struct Chip: Codable, Equatable, Sendable { public var label, text: String; public var correct: Bool }
    public var base: String; public var chips: [Chip]; public var explain: String?
}
public struct Match: Codable, Equatable, Sendable { public var prompt: String; public var pairs: [[String]] }
public struct Order: Codable, Equatable, Sendable { public var prompt: String; public var items: [String] }
public struct Handoff: Codable, Equatable, Sendable { public var intro: String; public var prompt: String; public var checklist: [String] }

public enum Step: Codable, Equatable, Sendable {
    case explain(Explain), choice(Choice), trueFalse(TrueFalse), multiSelect(MultiSelect)
    case spotBetter(SpotBetter), fixPrompt(FixPrompt), match(Match), order(Order), handoff(Handoff)
    case unknown(String)

    private enum K: String, CodingKey { case type }
    public init(from d: Decoder) throws {
        let type = try d.container(keyedBy: K.self).decode(String.self, forKey: .type)
        switch type {
        case "explain": self = .explain(try Explain(from: d))
        case "choice": self = .choice(try Choice(from: d))
        case "trueFalse": self = .trueFalse(try TrueFalse(from: d))
        case "multiSelect": self = .multiSelect(try MultiSelect(from: d))
        case "spotBetter": self = .spotBetter(try SpotBetter(from: d))
        case "fixPrompt": self = .fixPrompt(try FixPrompt(from: d))
        case "match": self = .match(try Match(from: d))
        case "order": self = .order(try Order(from: d))
        case "handoff": self = .handoff(try Handoff(from: d))
        default: self = .unknown(type) // forward-compatible: newer content won't crash old apps
        }
    }
    public func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: K.self)
        switch self {
        case .explain(let v): try c.encode("explain", forKey: .type); try v.encode(to: e)
        case .choice(let v): try c.encode("choice", forKey: .type); try v.encode(to: e)
        case .trueFalse(let v): try c.encode("trueFalse", forKey: .type); try v.encode(to: e)
        case .multiSelect(let v): try c.encode("multiSelect", forKey: .type); try v.encode(to: e)
        case .spotBetter(let v): try c.encode("spotBetter", forKey: .type); try v.encode(to: e)
        case .fixPrompt(let v): try c.encode("fixPrompt", forKey: .type); try v.encode(to: e)
        case .match(let v): try c.encode("match", forKey: .type); try v.encode(to: e)
        case .order(let v): try c.encode("order", forKey: .type); try v.encode(to: e)
        case .handoff(let v): try c.encode("handoff", forKey: .type); try v.encode(to: e)
        case .unknown(let t): try c.encode(t, forKey: .type)
        }
    }
    public var isGraded: Bool {
        switch self { case .explain, .handoff, .unknown: return false; default: return true }
    }
}
