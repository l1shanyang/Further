import Foundation

struct RecordColorValue: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) throws {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        try validate()
    }

    func validate() throws {
        let components = [red, green, blue, opacity]
        guard components.allSatisfy({ $0.isFinite && (0 ... 1).contains($0) }) else {
            throw DomainValidationError.invalidColorComponent
        }
    }
}

struct FeelingColor: Codable, Equatable, Sendable {
    let identifier: String
    let paletteVersion: String
    let value: RecordColorValue
}

struct SilenceColor: Codable, Equatable, Sendable {
    let identifier: String
    let generationRuleVersion: String
    let value: RecordColorValue
}

enum RecordExpression: Codable, Equatable, Sendable {
    case feeling(color: FeelingColor, note: String?)
    case silence(color: SilenceColor, note: String?)

    var note: String? {
        switch self {
        case let .feeling(_, note), let .silence(_, note):
            note
        }
    }

    var isSilence: Bool {
        if case .silence = self {
            return true
        }

        return false
    }

    var recordColor: RecordColorValue {
        switch self {
        case let .feeling(color, _):
            color.value
        case let .silence(color, _):
            color.value
        }
    }
}
