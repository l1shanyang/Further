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
    static let prepareRun = String(
        localized: "run.prepare",
        defaultValue: "Prepare to run",
        comment: "Primary action on the current artwork."
    )
    static let chooseRunEnvironment = String(
        localized: "run.environment.title",
        defaultValue: "Where will you run?",
        comment: "Title on the running environment selection page."
    )
    static let indoorRunMessage = String(
        localized: "run.environment.indoor.message",
        defaultValue: "Indoor running works without location or route tracking.",
        comment: "Explanation for the indoor running path."
    )
    static let indoorRun = String(
        localized: "run.environment.indoor",
        defaultValue: "Indoor run",
        comment: "Indoor running environment option."
    )
    static let outdoorRun = String(
        localized: "run.environment.outdoor",
        defaultValue: "Outdoor run",
        comment: "Outdoor running environment option."
    )
    static let outdoorLocationUnavailable = String(
        localized: "run.environment.outdoor.location-unavailable",
        defaultValue: "Location is unavailable. You can still run; route and distance may be missing.",
        comment: "Non-blocking explanation when outdoor location cannot be recorded."
    )
    static let cancel = String(
        localized: "action.cancel",
        defaultValue: "Cancel",
        comment: "Generic cancel action."
    )
    static let readyToRun = String(
        localized: "run.ready.title",
        defaultValue: "Ready to run?",
        comment: "Title before the final start action."
    )
    static let startRunPromise = String(
        localized: "run.ready.message",
        defaultValue: "Starting creates this run immediately, then begins the countdown.",
        comment: "Explains the start-is-a-record product promise."
    )
    static let startRun = String(
        localized: "run.start",
        defaultValue: "Start run",
        comment: "Final action that creates the running session."
    )
    static let runHasStarted = String(
        localized: "run.countdown.message",
        defaultValue: "Your run has started.",
        comment: "Message shown during the non-cancellable countdown."
    )
    static let runInProgress = String(
        localized: "run.tracking.active",
        defaultValue: "Running",
        comment: "Active running state label."
    )
    static let runPaused = String(
        localized: "run.tracking.paused",
        defaultValue: "Paused",
        comment: "Paused running state label."
    )
    static let distance = String(
        localized: "run.distance",
        defaultValue: "Distance",
        comment: "Distance label on the run tracking page."
    )
    static let notRecorded = String(
        localized: "run.distance.not-recorded",
        defaultValue: "Not recorded",
        comment: "Displayed when distance is unknown."
    )
    static let pauseRun = String(
        localized: "run.pause",
        defaultValue: "Pause",
        comment: "Pause the current run."
    )
    static let resumeRun = String(
        localized: "run.resume",
        defaultValue: "Resume",
        comment: "Resume the paused run."
    )
    static let endRun = String(
        localized: "run.end",
        defaultValue: "End run",
        comment: "End the current run."
    )
    static let keepRunning = String(
        localized: "run.end.keep",
        defaultValue: "Keep running",
        comment: "Cancel ending and return to the prior run state."
    )
    static let endRunTitle = String(
        localized: "run.end.title",
        defaultValue: "End this run?",
        comment: "Title for the explicit end confirmation."
    )
    static let endRunMessage = String(
        localized: "run.end.message",
        defaultValue: "The reliable details so far will be saved.",
        comment: "Message for the explicit end confirmation."
    )
    static let runSaved = String(
        localized: "run.saved.title",
        defaultValue: "Run saved",
        comment: "Stage boundary shown after normal ending."
    )
    static let runSavedMessage = String(
        localized: "run.saved.message",
        defaultValue: "Your run facts and silent expression are ready for reflection.",
        comment: "Explains the handoff from tracking to reflection."
    )
    static let howDidItFeel = String(
        localized: "reflection.expression.title",
        defaultValue: "How did it feel?",
        comment: "Title for the post-run feeling reflection."
    )
    static let chooseFeelingColor = String(
        localized: "reflection.expression.message",
        defaultValue: "Choose a color, add a short note, or keep this run silent.",
        comment: "Explanation for the reflection choices."
    )
    static let shortNote = String(
        localized: "reflection.note.title",
        defaultValue: "Short note",
        comment: "Label for the optional reflection note."
    )
    static let shortNotePlaceholder = String(
        localized: "reflection.note.placeholder",
        defaultValue: "A detail you want to remember",
        comment: "Placeholder for the optional reflection note."
    )
    static let finishExpression = String(
        localized: "reflection.expression.finish",
        defaultValue: "Finish expression",
        comment: "Locks the current color and note selection."
    )
    static let keepSilence = String(
        localized: "reflection.expression.silence",
        defaultValue: "Keep this run silent",
        comment: "Completes reflection with a silence expression."
    )
    static let addIndoorDistance = String(
        localized: "reflection.distance.title",
        defaultValue: "Add indoor distance?",
        comment: "Title for optional indoor manual distance entry."
    )
    static let indoorDistanceMessage = String(
        localized: "reflection.distance.message",
        defaultValue: "Enter the distance shown by your treadmill or indoor equipment.",
        comment: "Explanation for manual indoor distance."
    )
    static let distancePlaceholder = String(
        localized: "reflection.distance.placeholder",
        defaultValue: "5.00",
        comment: "Example value for indoor distance input."
    )
    static let kilometers = String(
        localized: "unit.kilometers",
        defaultValue: "km",
        comment: "Abbreviated kilometer unit."
    )
    static let validDistanceRequired = String(
        localized: "reflection.distance.invalid",
        defaultValue: "Enter a distance greater than zero.",
        comment: "Validation message for manual indoor distance."
    )
    static let saveDistance = String(
        localized: "reflection.distance.save",
        defaultValue: "Save distance",
        comment: "Saves the manual indoor distance and completes the record."
    )
    static let skipDistance = String(
        localized: "reflection.distance.skip",
        defaultValue: "Skip distance",
        comment: "Completes an indoor record while leaving distance unknown."
    )
    static let recordJoinedArtwork = String(
        localized: "reflection.artwork.title",
        defaultValue: "This run is now part of your artwork.",
        comment: "Causal feedback after the finalized record enters its artwork."
    )
    static let artworkCompletedByRun = String(
        localized: "reflection.artwork.completed",
        defaultValue: "This mark completed the artwork.",
        comment: "Feedback when the newly added record completes the artwork."
    )
    static let viewArtwork = String(
        localized: "reflection.artwork.view",
        defaultValue: "View artwork",
        comment: "Leaves record-entry feedback for the current artwork."
    )

    static func feelingColor(_ number: Int) -> String {
        String.localizedStringWithFormat(
            String(
                localized: "reflection.color.accessibility",
                defaultValue: "Feeling color %lld",
                comment: "Neutral numbered accessibility label for an unlabeled feeling color."
            ),
            number
        )
    }

    static func artworkNowHasMarks(_ count: Int) -> String {
        String.localizedStringWithFormat(
            String(
                localized: "reflection.artwork.mark-count",
                defaultValue: "Your artwork now holds %lld marks.",
                comment: "Record-entry feedback with the current number of artwork marks."
            ),
            count
        )
    }
}
