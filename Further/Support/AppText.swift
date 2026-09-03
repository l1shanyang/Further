import Foundation

enum AppText {
    static let productName = String(
        localized: "app.name",
        defaultValue: "Further",
        comment: "The product name shown on the launch page."
    )

    static let launchTagline = String(
        localized: "launch.tagline",
        defaultValue: "still going.",
        comment: "The quiet tagline shown below the product name."
    )
}
