import KeyboardShortcuts
import SwiftUI
import WhisprLocalCore

public struct MenuBarView: View {
    let controller: DictationController

    public init(controller: DictationController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            StatusSection(state: controller.appState.recordingState)

            Divider()

            // Setup prompt if not ready
            if !controller.appState.isSetupComplete {
                SetupPromptSection(appState: controller.appState)
                Divider()
            }

            // Last transcription
            if !controller.appState.lastTranscription.isEmpty {
                LastTranscriptionSection(text: controller.appState.lastTranscription)
                Divider()
            }

            // Controls
            ControlsSection(controller: controller)

            Divider()

            // Footer
            FooterSection()
        }
        .padding(12)
        .frame(width: 280)
    }
}

// MARK: - Sub-sections

private struct StatusSection: View {
    let state: RecordingState

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text("WhisprLocal")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "waveform")
                .foregroundStyle(.green)
                .font(.title2)
        case .recording:
            Image(systemName: "mic.fill")
                .foregroundStyle(.red)
                .font(.title2)
                .symbolEffect(.pulse)
        case .transcribing:
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.blue)
                .font(.title2)
                .symbolEffect(.pulse)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.title2)
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Ready — press hotkey to start"
        case .recording: return "Recording... press hotkey to stop"
        case .transcribing: return "Transcribing..."
        case .error(let msg): return msg
        }
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

            SettingsLink {
                Text("Open Setup...")
            }
            .font(.caption)
        }
    }
}

private struct LastTranscriptionSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Transcription")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }
}

private struct ControlsSection: View {
    let controller: DictationController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hotkey:")
                    .font(.caption)
                Spacer()
                KeyboardShortcuts.Recorder(for: .toggleDictation)
                    .controlSize(.small)
            }

            HStack {
                Text("Model:")
                    .font(.caption)
                Spacer()
                Text(controller.appState.selectedModelType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if controller.appState.isModelLoaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
    }
}

private struct FooterSection: View {
    var body: some View {
        HStack {
            SettingsLink {
                Text("Settings...")
            }
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .font(.caption)
    }
}
