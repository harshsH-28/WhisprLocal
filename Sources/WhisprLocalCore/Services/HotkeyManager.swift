import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The global hotkey for toggling dictation.
    public static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: .option))
}

/// Manages the global hotkey for starting/stopping dictation.
public final class HotkeyManager {
    private var onToggle: (() -> Void)?

    public init() {}

    /// Set up the hotkey handler. The callback fires each time the hotkey is pressed.
    public func register(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            self?.onToggle?()
        }
    }

    /// Remove the hotkey handler.
    public func unregister() {
        KeyboardShortcuts.disable(.toggleDictation)
        onToggle = nil
    }
}
