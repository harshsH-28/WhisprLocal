import KeyboardShortcuts
import SwiftUI
import WhisprLocalCore

public struct SettingsView: View {
    let controller: DictationController
    @State private var selectedTab = 0

    public init(controller: DictationController) {
        self.controller = controller
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(controller: controller)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            ModelSettingsTab(controller: controller)
                .tabItem {
                    Label("Model", systemImage: "cpu")
                }
                .tag(1)

            SetupView(controller: controller)
                .tabItem {
                    Label("Setup", systemImage: "checkmark.circle")
                }
                .tag(2)
        }
        .frame(width: 450, height: 320)
    }
}

// MARK: - General Settings

private struct GeneralSettingsTab: View {
    let controller: DictationController

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Toggle Dictation:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleDictation)
                }
            }

            Section("Status") {
                LabeledContent("Recording State") {
                    Text(stateDescription)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Model Loaded") {
                    Image(systemName: controller.appState.isModelLoaded ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(controller.appState.isModelLoaded ? .green : .red)
                }
            }

            if !controller.appState.lastTranscription.isEmpty {
                Section("Last Transcription") {
                    Text(controller.appState.lastTranscription)
                        .textSelection(.enabled)
                        .font(.body)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var stateDescription: String {
        switch controller.appState.recordingState {
        case .idle: return "Idle"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Model Settings

private struct ModelSettingsTab: View {
    let controller: DictationController

    var body: some View {
        Form {
            Section("Selected Model") {
                Picker("Model", selection: Bindable(controller.appState).selectedModelType) {
                    ForEach(WhisperModelType.allCases) { model in
                        HStack {
                            Text(model.displayName)
                            Text("(\(model.sizeDescription))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }

                Text(controller.appState.selectedModelType.qualityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Model File") {
                let modelManager = ModelManager()
                let path = modelManager.modelPath(for: controller.appState.selectedModelType).path

                LabeledContent("Status") {
                    if controller.appState.isModelAvailable {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Found", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }

                LabeledContent("Expected Path") {
                    Text(path)
                        .font(.caption)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }

                if !controller.appState.isModelAvailable {
                    Text(modelManager.modelInstructions(for: controller.appState.selectedModelType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh") {
                    controller.refreshStatus()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
