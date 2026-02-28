import AppKit
import Carbon.HIToolbox
import Foundation

/// Errors during text injection.
public enum TextInjectorError: Error, LocalizedError, Equatable {
    case emptyText
    case eventCreationFailed
    case accessibilityNotGranted

    public var errorDescription: String? {
        switch self {
        case .emptyText: return "No text to inject"
        case .eventCreationFailed: return "Failed to create keyboard event"
        case .accessibilityNotGranted: return "Accessibility permission not granted"
        }
    }
}

/// Injects text into the focused app via clipboard + simulated Cmd+V.
public final class TextInjector {
    private let pasteboard: NSPasteboard
    /// Delay in seconds between setting clipboard and simulating Cmd+V.
    private let pasteDelay: TimeInterval
    /// Delay in seconds before restoring original clipboard contents.
    private let restoreDelay: TimeInterval

    public init(
        pasteboard: NSPasteboard = .general,
        pasteDelay: TimeInterval = 0.05,
        restoreDelay: TimeInterval = 0.1
    ) {
        self.pasteboard = pasteboard
        self.pasteDelay = pasteDelay
        self.restoreDelay = restoreDelay
    }

    /// Inject text by: save clipboard → set text → Cmd+V → restore clipboard.
    public func inject(text: String) async throws {
        guard !text.isEmpty else { throw TextInjectorError.emptyText }
        guard AXIsProcessTrusted() else { throw TextInjectorError.accessibilityNotGranted }

        // Save current clipboard contents
        let savedContents = saveClipboard()

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        try await Task.sleep(nanoseconds: UInt64(pasteDelay * 1_000_000_000))

        // Simulate Cmd+V
        try simulatePaste()

        // Wait then restore original clipboard
        try await Task.sleep(nanoseconds: UInt64(restoreDelay * 1_000_000_000))
        restoreClipboard(savedContents)
    }

    // MARK: - Private

    private func simulatePaste() throws {
        let vKeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            throw TextInjectorError.eventCreationFailed
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func saveClipboard() -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { item in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            return newItem
        } ?? []
    }

    private func restoreClipboard(_ items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
