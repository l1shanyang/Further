import Foundation

struct ReflectionExpressionState: Equatable, Sendable {
    let activityID: ActivityID
    let environment: RunningEnvironment
    let silenceColor: SilenceColor
    var feelingColor: FeelingColor?
    var note: String

    var draft: ReflectionDraft {
        get throws {
            let savedNote = note.isEmpty ? nil : note
            let expression: RecordExpression = if let feelingColor {
                .feeling(color: feelingColor, note: savedNote)
            } else {
                .silence(color: silenceColor, note: savedNote)
            }
            return try ReflectionDraft(expression: expression)
        }
    }
}

struct IndoorDistanceState: Equatable, Sendable {
    let activityID: ActivityID
    var distanceInput: String
    var showsValidationError: Bool
}

enum ReflectionFlowViewState: Equatable, Sendable {
    case expression(ReflectionExpressionState)
    case indoorDistance(IndoorDistanceState)
    case enteringArtwork(
        record: SharedActivityRecordV1,
        artwork: CurrentArtworkViewState
    )
}

enum ManualDistanceParser {
    static func meters(from input: String, unit: DistanceUnit = .kilometers) -> Double? {
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let distance = Double(normalized),
              distance.isFinite,
              distance > 0 else {
            return nil
        }
        let meters = distance * unit.metersPerUnit
        return meters.isFinite ? meters : nil
    }
}

struct FeelingColorOption: Identifiable, Equatable, Sendable {
    static let paletteVersion = "feeling-v1"

    let id: String
    let color: FeelingColor

    init(id: String, red: Int, green: Int, blue: Int) {
        guard let value = try? RecordColorValue(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        ) else {
            preconditionFailure("Feeling palette contains an invalid color")
        }
        self.id = id
        color = FeelingColor(
            identifier: id,
            paletteVersion: Self.paletteVersion,
            value: value
        )
    }

    static let all: [FeelingColorOption] = [
        FeelingColorOption(id: "ember", red: 216, green: 102, blue: 82),
        FeelingColorOption(id: "sun", red: 224, green: 166, blue: 73),
        FeelingColorOption(id: "moss", red: 91, green: 139, blue: 104),
        FeelingColorOption(id: "tide", red: 75, green: 132, blue: 158),
        FeelingColorOption(id: "dusk", red: 106, green: 100, blue: 158),
        FeelingColorOption(id: "clay", red: 157, green: 112, blue: 105),
    ]

    static func accessibilityNumber(for color: FeelingColor) -> Int? {
        all.firstIndex(where: {
            $0.color.identifier == color.identifier
                && $0.color.paletteVersion == color.paletteVersion
        }).map { $0 + 1 }
    }
}
