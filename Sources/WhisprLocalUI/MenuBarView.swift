import KeyboardShortcuts
import SwiftUI
import WhisprLocalCore

public struct MenuBarView: View {
    let controller: DictationController
    @State private var showCopiedFeedback = false

    public init(controller: DictationController) {
        self.controller = controller
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Status header
                StatusSection(
                    state: controller.appState.recordingState,
                    modelName: controller.appState.isModelLoaded
                        ? controller.appState.selectedModelType.displayName : nil
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Error banner (shown when in error state)
                if case .error(let message) = controller.appState.recordingState {
                    ErrorBanner(message: message) {
                        controller.appState.clearError()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // Setup prompt if not ready
                if !controller.appState.isSetupComplete,
                   !controller.appState.recordingState.isRecording,
                   !controller.appState.recordingState.isTranscribing {
                    Divider().padding(.horizontal, 16)
                    SetupPromptSection(appState: controller.appState)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                // Last transcription
                if !controller.appState.lastTranscription.isEmpty,
                   !controller.appState.recordingState.isRecording,
                   !controller.appState.recordingState.isTranscribing {
                    Divider().padding(.horizontal, 16)
                    LastTranscriptionSection(
                        text: controller.appState.lastTranscription,
                        showCopiedFeedback: $showCopiedFeedback
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Shortcut hint (only when idle)
                if controller.appState.recordingState.isIdle {
                    Divider().padding(.horizontal, 16)
                    ShortcutSection()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }

                // Footer
                Divider().padding(.horizontal, 16)
                FooterSection()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 400)
    }
}

// MARK: - Sub-sections

private struct StatusSection: View {
    let state: RecordingState
    let modelName: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let modelName, state.isIdle {
                Text("\(modelName) model loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.isRecording {
                Text("Press ⌥D to stop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.isTranscribing {
                Text("Just a moment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dotColor: Color {
        switch state {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .blue
        case .error: return .orange
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .error: return "Error"
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            Button("Dismiss", action: onDismiss)
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SetupPromptSection: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !appState.hasMicrophonePermission {
                Label("Microphone permission needed", systemImage: "mic.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !appState.hasAccessibilityPermission {
                Label("Accessibility permission needed", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !appState.isModelAvailable {
                Label("Whisper model not found", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button("Open Setup...") {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    if #available(macOS 14, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
            }
            .font(.caption)
        }
    }
}

private struct LastTranscriptionSection: View {
    let text: String
    @Binding var showCopiedFeedback: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    showCopiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Text(showCopiedFeedback ? "Copied!" : "Copy")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct ShortcutSection: View {
    var body: some View {
        HStack {
            Text("Shortcut")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("⌥D")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

private struct FooterSection: View {
    var body: some View {
        HStack {
            Button("Settings...") {
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    if #available(macOS 14, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
            }
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
