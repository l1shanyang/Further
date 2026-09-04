import Foundation
import XCTest
@testable import Further

final class ReflectionFlowTests: XCTestCase {
    func testFourExpressionCombinationsProduceValidDrafts() throws {
        let silenceColor = try silenceColor()
        let feelingColor = FeelingColorOption.all[0].color
        let cases: [(FeelingColor?, String, Bool, String?)] = [
            (feelingColor, "", false, nil),
            (feelingColor, "steady", false, "steady"),
            (nil, "", true, nil),
            (nil, "quiet finish", true, "quiet finish"),
        ]

        for (feeling, note, expectsSilence, expectedNote) in cases {
            let state = ReflectionExpressionState(
                activityID: ActivityID(),
                environment: .indoor,
                silenceColor: silenceColor,
                feelingColor: feeling,
                note: note
            )
            let expression = try state.draft.expression

            XCTAssertEqual(expression.isSilence, expectsSilence)
            XCTAssertEqual(expression.note, expectedNote)
        }
    }

    func testManualDistanceAcceptsDecimalSeparatorsAndRejectsInvalidValues() {
        XCTAssertEqual(ManualDistanceParser.meters(fromKilometers: "5.25"), 5_250)
        XCTAssertEqual(ManualDistanceParser.meters(fromKilometers: " 5,25 "), 5_250)
        XCTAssertNil(ManualDistanceParser.meters(fromKilometers: ""))
        XCTAssertNil(ManualDistanceParser.meters(fromKilometers: "0"))
        XCTAssertNil(ManualDistanceParser.meters(fromKilometers: "-2"))
        XCTAssertNil(ManualDistanceParser.meters(fromKilometers: "five"))
        XCTAssertNil(ManualDistanceParser.meters(fromKilometers: "1e308"))
    }

    private func silenceColor() throws -> SilenceColor {
        SilenceColor(
            identifier: "silence-test",
            generationRuleVersion: "silence-v1",
            value: try RecordColorValue(red: 0.3, green: 0.4, blue: 0.5)
        )
    }
}
