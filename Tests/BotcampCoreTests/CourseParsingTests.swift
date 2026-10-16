import XCTest
@testable import BotcampCore

final class CourseParsingTests: XCTestCase {
    static var courseURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Botcamp/Resources/course.json")
    }
    static func loadCourse() throws -> Course { try Course.decode(Data(contentsOf: courseURL)) }

    func testBundledCourseDecodesAndValidates() throws {
        let c = try Self.loadCourse()
        XCTAssertEqual(c.units.count, 10)
        XCTAssertEqual(c.rungs.count, 6)
        XCTAssertFalse(c.glossary.isEmpty)
    }

    func testFreeTierIsUnitsOneToThree() throws {
        let c = try Self.loadCourse()
        XCTAssertEqual(c.units.filter(\.isFree).map(\.id), ["m1", "m2", "m3"])
    }

    func testUnitsOneToThreeFullyBuilt() throws {
        let c = try Self.loadCourse()
        for u in c.units.prefix(3) {
            XCTAssertFalse(u.isStub)
            XCTAssertGreaterThanOrEqual(u.lessons.count, 4)
            XCTAssertTrue(u.lessons.contains { $0.isUnitCheck }, "\(u.id) needs a unit check")
            XCTAssertTrue(u.lessons.flatMap(\.steps).contains { if case .handoff = $0 { return true }; return false })
        }
        XCTAssertTrue(c.units.dropFirst(3).allSatisfy(\.isStub))
    }

    func testEveryPlannedLessonTypeAppears() throws {
        let steps = try Self.loadCourse().allLessons.flatMap(\.steps)
        var kinds = Set<String>()
        for s in steps {
            switch s {
            case .explain: kinds.insert("explain"); case .choice: kinds.insert("choice")
            case .trueFalse: kinds.insert("trueFalse"); case .multiSelect: kinds.insert("multiSelect")
            case .spotBetter: kinds.insert("spotBetter"); case .fixPrompt: kinds.insert("fixPrompt")
            case .match: kinds.insert("match"); case .order: kinds.insert("order")
            case .handoff: kinds.insert("handoff"); case .unknown(let t): XCTFail("unknown step \(t)")
            }
        }
        XCTAssertEqual(kinds.count, 9)
    }

    func testUnknownStepTypeIsTolerated() throws {
        let json = #"[{"type":"hologram","x":1},{"type":"trueFalse","statement":"s","answer":true}]"#
        let steps = try JSONDecoder().decode([Step].self, from: Data(json.utf8))
        XCTAssertEqual(steps.first, .unknown("hologram"))
        XCTAssertFalse(steps[0].isGraded)
    }

    func testStepRoundTrip() throws {
        let c = try Self.loadCourse()
        let again = try Course.decode(JSONEncoder().encode(c))
        XCTAssertEqual(c, again)
    }

    func testValidationCatchesBadAnswerIndex() {
        let json = #"{"version":1,"lastChecked":"x","rungs":[],"glossary":[],"units":[{"id":"m1","number":1,"title":"t","subtitle":"s","blurb":"b","rung":0,"isFree":true,"isStub":false,"lessons":[{"id":"l","title":"t","steps":[{"type":"choice","question":"q","options":["a"],"answer":3}]}]}]}"#
        XCTAssertThrowsError(try Course.decode(Data(json.utf8)))
    }

    func testGlossaryPointsAtRealUnits() throws {
        let c = try Self.loadCourse()
        for t in c.glossary { XCTAssertNotNil(c.unit(id: t.unitId), t.term) }
    }
}
