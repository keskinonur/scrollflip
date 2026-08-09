import AppIntents

extension ScrollFlipMode {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "ScrollFlip Mode"
    static var caseDisplayRepresentations: [ScrollFlipMode: DisplayRepresentation] = [
        .auto: DisplayRepresentation(
            title: "Auto",
            subtitle: "Reverse only when the Mac lid is closed"
        ),
        .on: DisplayRepresentation(
            title: "On",
            subtitle: "Always reverse wheel mice"
        ),
        .off: DisplayRepresentation(
            title: "Off",
            subtitle: "Leave every scroll event unchanged"
        ),
    ]
}

struct SetScrollFlipModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set ScrollFlip Mode"
    static var description = IntentDescription(
        "Choose when ScrollFlip reverses mouse-wheel scrolling. Trackpad gestures are never changed."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Mode")
    var mode: ScrollFlipMode

    static var parameterSummary: some ParameterSummary {
        Summary("Set ScrollFlip to \(\.$mode)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ModeStore.write(mode)
        return .result(dialog: "ScrollFlip is now \(mode.title.lowercased()).")
    }
}

struct CycleScrollFlipModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Cycle ScrollFlip Mode"
    static var description = IntentDescription(
        "Move ScrollFlip from Auto to On to Off, then back to Auto."
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let next = try ModeStore.cycle()
        return .result(dialog: "ScrollFlip is now \(next.title.lowercased()).")
    }
}

struct ScrollFlipShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CycleScrollFlipModeIntent(),
            phrases: [
                "Cycle \(.applicationName)",
                "Flip my scroll with \(.applicationName)",
            ],
            shortTitle: "Cycle Mode",
            systemImageName: "arrow.up.arrow.down"
        )
    }
}
