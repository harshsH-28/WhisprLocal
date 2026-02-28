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
    @State private var showAllLanguages = false

    private static let commonLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-Detect"),
        ("en", "English"),
        ("zh", "Chinese"),
        ("de", "German"),
        ("es", "Spanish"),
        ("ru", "Russian"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("ja", "Japanese"),
        ("pt", "Portuguese"),
        ("tr", "Turkish"),
        ("pl", "Polish"),
        ("it", "Italian"),
        ("hi", "Hindi"),
        ("ar", "Arabic"),
        ("nl", "Dutch"),
    ]

    private static let allLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-Detect"),
        ("af", "Afrikaans"), ("am", "Amharic"), ("ar", "Arabic"), ("as", "Assamese"),
        ("az", "Azerbaijani"), ("ba", "Bashkir"), ("be", "Belarusian"), ("bg", "Bulgarian"),
        ("bn", "Bengali"), ("bo", "Tibetan"), ("br", "Breton"), ("bs", "Bosnian"),
        ("ca", "Catalan"), ("cs", "Czech"), ("cy", "Welsh"), ("da", "Danish"),
        ("de", "German"), ("el", "Greek"), ("en", "English"), ("es", "Spanish"),
        ("et", "Estonian"), ("eu", "Basque"), ("fa", "Persian"), ("fi", "Finnish"),
        ("fo", "Faroese"), ("fr", "French"), ("gl", "Galician"), ("gu", "Gujarati"),
        ("ha", "Hausa"), ("haw", "Hawaiian"), ("he", "Hebrew"), ("hi", "Hindi"),
        ("hr", "Croatian"), ("ht", "Haitian Creole"), ("hu", "Hungarian"), ("hy", "Armenian"),
        ("id", "Indonesian"), ("is", "Icelandic"), ("it", "Italian"), ("ja", "Japanese"),
        ("jw", "Javanese"), ("ka", "Georgian"), ("kk", "Kazakh"), ("km", "Khmer"),
        ("kn", "Kannada"), ("ko", "Korean"), ("la", "Latin"), ("lb", "Luxembourgish"),
        ("ln", "Lingala"), ("lo", "Lao"), ("lt", "Lithuanian"), ("lv", "Latvian"),
        ("mg", "Malagasy"), ("mi", "Maori"), ("mk", "Macedonian"), ("ml", "Malayalam"),
        ("mn", "Mongolian"), ("mr", "Marathi"), ("ms", "Malay"), ("mt", "Maltese"),
        ("my", "Myanmar"), ("ne", "Nepali"), ("nl", "Dutch"), ("nn", "Nynorsk"),
        ("no", "Norwegian"), ("oc", "Occitan"), ("pa", "Panjabi"), ("pl", "Polish"),
        ("ps", "Pashto"), ("pt", "Portuguese"), ("ro", "Romanian"), ("ru", "Russian"),
        ("sa", "Sanskrit"), ("sd", "Sindhi"), ("si", "Sinhala"), ("sk", "Slovak"),
        ("sl", "Slovenian"), ("sn", "Shona"), ("so", "Somali"), ("sq", "Albanian"),
        ("sr", "Serbian"), ("su", "Sundanese"), ("sv", "Swedish"), ("sw", "Swahili"),
        ("ta", "Tamil"), ("te", "Telugu"), ("tg", "Tajik"), ("th", "Thai"),
        ("tk", "Turkmen"), ("tl", "Tagalog"), ("tr", "Turkish"), ("tt", "Tatar"),
        ("uk", "Ukrainian"), ("ur", "Urdu"), ("uz", "Uzbek"), ("vi", "Vietnamese"),
        ("yi", "Yiddish"), ("yo", "Yoruba"), ("yue", "Cantonese"), ("zh", "Chinese"),
    ]

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Toggle Dictation:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleDictation)
                }
            }

            Section("Language") {
                Picker("Language", selection: Bindable(controller.appState).selectedLanguage) {
                    let languages = showAllLanguages ? Self.allLanguages : Self.commonLanguages
                    ForEach(languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }

                Toggle("Show all languages", isOn: $showAllLanguages)
                    .font(.caption)
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

    private func startDownload(modelManager: ModelManager) {
        let modelType = controller.appState.selectedModelType
        controller.appState.downloadProgress = 0
        Task {
            do {
                try await modelManager.downloadModel(modelType) { fraction in
                    Task { @MainActor in
                        controller.appState.downloadProgress = fraction
                    }
                }
                await MainActor.run {
                    controller.appState.downloadProgress = nil
                    controller.refreshStatus()
                }
            } catch {
                await MainActor.run {
                    controller.appState.downloadProgress = nil
                    controller.appState.lastError = error.localizedDescription
                }
            }
        }
    }

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
                    if controller.appState.isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: controller.appState.downloadProgress ?? 0)
                            HStack {
                                Text("\(Int((controller.appState.downloadProgress ?? 0) * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Cancel") {
                                    modelManager.cancelDownload()
                                    controller.appState.downloadProgress = nil
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        Button("Download \(controller.appState.selectedModelType.displayName) (\(controller.appState.selectedModelType.sizeDescription))") {
                            startDownload(modelManager: modelManager)
                        }

                        Text(modelManager.modelInstructions(for: controller.appState.selectedModelType))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
