import AppIntents

// The mode value, exposed to Shortcuts and Siri as a typed parameter.
enum ScrollFlipMode: String, AppEnum {
    case auto, on, off

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scroll Flip Mode"
    static var caseDisplayRepresentations: [ScrollFlipMode: DisplayRepresentation] = [
        .auto: "Auto (reverse only when lid closed)",
        .on:   "On (always reverse)",
        .off:  "Off",
    ]
}

// Shortcuts action: Set Scroll Flip Mode. Runs in the background, no window.
struct SetScrollFlipModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Scroll Flip Mode"
    static var description = IntentDescription("Set when the mouse wheel scroll direction is reversed.")
    static var openAppWhenRun = false

    @Parameter(title: "Mode")
    var mode: ScrollFlipMode

    func perform() async throws -> some IntentResult & ProvidesDialog {
        ModeStore.write(mode.rawValue)
        return .result(dialog: "Scroll flip set to \(mode.rawValue).")
    }
}

// Parameterless action, used for the Siri phrase below.
struct CycleScrollFlipModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Cycle Scroll Flip Mode"
    static var description = IntentDescription("Cycle scroll flip mode between auto, on, and off.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let next = ModeStore.cycle()
        return .result(dialog: "Scroll flip set to \(next).")
    }
}

// Registers a Siri phrase and a Spotlight/Shortcuts entry automatically.
// ponytail: only the parameterless intent gets a phrase. Add per-mode intents
// later if you want "turn scroll flip on" by voice.
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
