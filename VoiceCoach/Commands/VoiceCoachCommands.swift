import SwiftUI

// MARK: - Exercise actions (provided by ExerciseDetailView via focusedSceneValue)

/// Bundle of actions dispatched from ExerciseDetailView to the menu bar.
/// @unchecked Sendable: all access is on the main actor.
struct ExerciseActions: @unchecked Sendable {
    var newAttempt: () -> Void = {}
    var previousAttempt: () -> Void = {}
    var nextAttempt: () -> Void = {}
    var rateAttempt: (Int) -> Void = { _ in }
    var canGoPrev: Bool = false
    var canGoNext: Bool = false
    var hasAttempt: Bool = false
}

private struct ExerciseActionsKey: FocusedValueKey {
    typealias Value = ExerciseActions
}

// MARK: - App navigation actions (provided by ContentView for tab switching)

struct AppNavigationActions: @unchecked Sendable {
    var switchTab: (Int) -> Void = { _ in }
}

private struct AppNavigationKey: FocusedValueKey {
    typealias Value = AppNavigationActions
}

// MARK: - FocusedValues extensions

extension FocusedValues {
    var exerciseActions: ExerciseActions? {
        get { self[ExerciseActionsKey.self] }
        set { self[ExerciseActionsKey.self] = newValue }
    }

    var appNavigation: AppNavigationActions? {
        get { self[AppNavigationKey.self] }
        set { self[AppNavigationKey.self] = newValue }
    }
}

// MARK: - Commands

struct VoiceCoachCommands: Commands {
    @FocusedValue(\.exerciseActions) var exercise: ExerciseActions?
    @FocusedValue(\.appNavigation) var nav: AppNavigationActions?

    var body: some Commands {
        // MARK: Exercise menu
        CommandMenu("Exercise") {
            Button("New Attempt") { exercise?.newAttempt() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(exercise == nil)

            Divider()

            // Shortcuts are also on the toolbar buttons so they work even if
            // @FocusedSceneValue is unreliable (AVPlayerViewController holds firstResponder).
            // Mac menu bar takes priority over UIKeyCommands when the item is enabled.
            Button("Previous Attempt") { exercise?.previousAttempt() }
                .keyboardShortcut(",", modifiers: [])
                .disabled(!(exercise?.canGoPrev ?? false))

            Button("Next Attempt") { exercise?.nextAttempt() }
                .keyboardShortcut(".", modifiers: [])
                .disabled(!(exercise?.canGoNext ?? false))

            Divider()

            Button("Rate 1 Star")  { exercise?.rateAttempt(1) }
                .keyboardShortcut("1", modifiers: .option)
                .disabled(!(exercise?.hasAttempt ?? false))
            Button("Rate 2 Stars") { exercise?.rateAttempt(2) }
                .keyboardShortcut("2", modifiers: .option)
                .disabled(!(exercise?.hasAttempt ?? false))
            Button("Rate 3 Stars") { exercise?.rateAttempt(3) }
                .keyboardShortcut("3", modifiers: .option)
                .disabled(!(exercise?.hasAttempt ?? false))
            Button("Rate 4 Stars") { exercise?.rateAttempt(4) }
                .keyboardShortcut("4", modifiers: .option)
                .disabled(!(exercise?.hasAttempt ?? false))
            Button("Rate 5 Stars") { exercise?.rateAttempt(5) }
                .keyboardShortcut("5", modifiers: .option)
                .disabled(!(exercise?.hasAttempt ?? false))
        }

        // MARK: View menu — tab switching
        // Mac Catalyst does NOT auto-generate these; we must add them explicitly.
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Exercises") { nav?.switchTab(0) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Feed")      { nav?.switchTab(1) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Playlists") { nav?.switchTab(2) }
                .keyboardShortcut("3", modifiers: .command)
        }
    }
}
