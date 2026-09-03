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

    static let chooseCycleTitle = String(
        localized: "cycle.choose.title",
        defaultValue: "Choose an artwork cycle.",
        comment: "Title for the first artwork cycle selection page."
    )
    static let chooseCycleMessage = String(
        localized: "cycle.choose.message",
        defaultValue: "A cycle gives this artwork a boundary. It begins with your first run.",
        comment: "Explanation shown before choosing an artwork cycle."
    )
    static let timeCycle = String(
        localized: "cycle.time",
        defaultValue: "Time",
        comment: "Time cycle section title."
    )
    static let milestoneCycle = String(
        localized: "cycle.milestone",
        defaultValue: "Milestone",
        comment: "Milestone cycle section title."
    )
    static let oneMonth = String(
        localized: "cycle.one-month",
        defaultValue: "One month",
        comment: "One month cycle."
    )
    static let threeMonths = String(
        localized: "cycle.three-months",
        defaultValue: "Three months",
        comment: "Three month cycle."
    )
    static let oneYear = String(
        localized: "cycle.one-year",
        defaultValue: "One year",
        comment: "One year cycle."
    )
    static let tenKilometers = String(
        localized: "cycle.ten-kilometers",
        defaultValue: "10 kilometers",
        comment: "Ten kilometer milestone."
    )
    static let halfMarathon = String(
        localized: "cycle.half-marathon",
        defaultValue: "Half marathon",
        comment: "Half marathon milestone."
    )
    static let marathon = String(
        localized: "cycle.marathon",
        defaultValue: "Marathon",
        comment: "Marathon milestone."
    )
    static let beginArtwork = String(
        localized: "cycle.begin",
        defaultValue: "Begin this artwork",
        comment: "Button that creates the selected first artwork."
    )
    static let blankArtworkTitle = String(
        localized: "artwork.blank.title",
        defaultValue: "A new artwork",
        comment: "Title for a blank current artwork."
    )
    static let blankArtworkMessage = String(
        localized: "artwork.blank.message",
        defaultValue: "Your first run will leave the first mark.",
        comment: "Explanation for a blank artwork with no run marks."
    )
    static let accumulatingArtworkTitle = String(
        localized: "artwork.accumulating.title",
        defaultValue: "Your current artwork",
        comment: "Title for an accumulating current artwork."
    )
    static let completedArtworkTitle = String(
        localized: "artwork.completed.title",
        defaultValue: "This artwork is complete",
        comment: "Title for a completed current artwork."
    )
    static let artworkCanvas = String(
        localized: "artwork.canvas",
        defaultValue: "Current artwork",
        comment: "Accessibility label for the artwork canvas."
    )
    static let dataUnavailableTitle = String(
        localized: "error.data-unavailable.title",
        defaultValue: "Your data couldn’t be opened.",
        comment: "Blocking title when the local database cannot be opened."
    )
    static let dataUnavailableMessage = String(
        localized: "error.data-unavailable.message",
        defaultValue: "Nothing has been replaced. Try opening Further again.",
        comment: "Blocking database error explanation."
    )
    static let tryAgain = String(
        localized: "action.try-again",
        defaultValue: "Try again",
        comment: "Retry button title."
    )
    static let ok = String(
        localized: "action.ok",
        defaultValue: "OK",
        comment: "Dismiss button title."
    )
    static let recoveryNoticeTitle = String(
        localized: "recovery.title",
        defaultValue: "Your run was saved",
        comment: "Title for a one-time startup recovery notice."
    )
    static let interruptedRunSaved = String(
        localized: "recovery.interrupted-run",
        defaultValue: "The last reliable details from your previous run were saved.",
        comment: "Message after an interrupted run is finalized on startup."
    )
    static let reflectionSaved = String(
        localized: "recovery.reflection",
        defaultValue: "Your last saved expression was added to the artwork.",
        comment: "Message after a reflection draft is finalized on startup."
    )
}
