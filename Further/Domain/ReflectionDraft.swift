import Foundation

struct ReflectionDraft: Codable, Equatable, Sendable {
    let expression: RecordExpression

    init(expression: RecordExpression) throws {
        self.expression = expression
        try expression.recordColor.validate()
    }
}
