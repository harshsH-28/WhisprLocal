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
                    Label("Models", systemImage: "cpu")
                }
                .tag(1)

            SetupView(controller: controller, selectedTab: $selectedTab)
                .tabItem {
                    Label("Setup", systemImage: "checkmark.circle")
                }
                .tag(2)
        }
        .frame(width: 520, height: 440)
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
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?

    private var modelManager: ModelManager { controller.modelManager }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(WhisperModelType.allCases) { model in
                        ModelRow(
                            model: model,
                            isActive: controller.appState.selectedModelType == model,
                            isInstalled: modelManager.isModelAvailable(model),
                            isDownloading: controller.appState.downloadingModelType == model
                                && controller.appState.downloadError == nil,
                            downloadProgress: controller.appState.downloadingModelType == model
                                ? controller.appState.downloadProgress : nil,
                            downloadError: controller.appState.downloadingModelType == model
                                ? controller.appState.downloadError : nil,
                            anyDownloadActive: controller.appState.isDownloading
                                && controller.appState.downloadError == nil,
                            onSelect: { selectModel(model) },
                            onDownload: { startDownload(model) },
                            onCancel: { cancelDownload() },
                            onRetry: {
                                controller.appState.downloadError = nil
                                startDownload(model)
                            },
                            onDelete: {
                                modelToDelete = model
                                showDeleteConfirmation = true
                            }
                        )

                        if model != WhisperModelType.allCases.last {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                Text("Click an installed model to use it for transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .alert("Delete \"\(modelToDelete?.displayName ?? "")\" model?",
               isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text("This will free up \(model.sizeDescription) of disk space. You can re-download it anytime.")
            }
        }
    }

    private func selectModel(_ model: WhisperModelType) {
        guard modelManager.isModelAvailable(model) else { return }
        controller.appState.selectedModelType = model
        controller.appState.isModelLoaded = false
        Task {
            try? await controller.ensureModelLoaded()
        }
    }

    private func startDownload(_ model: WhisperModelType) {
        guard !controller.appState.isDownloading else { return }
        controller.appState.downloadingModelType = model
        controller.appState.downloadProgress = 0
        controller.appState.downloadError = nil

        let mgr = controller.modelManager
        Task {
            do {
                try await mgr.downloadModel(model) { fraction in
                    Task { @MainActor in
                        controller.appState.downloadProgress = fraction
                    }
                }
                await MainActor.run {
                    controller.appState.downloadingModelType = nil
                    controller.appState.downloadProgress = nil
                    controller.refreshStatus()
                }
            } catch is CancellationError {
                await MainActor.run {
                    controller.appState.downloadingModelType = nil
                    controller.appState.downloadProgress = nil
                    controller.appState.downloadError = nil
                }
            } catch {
                await MainActor.run {
                    controller.appState.downloadProgress = nil
                    controller.appState.downloadError = error.localizedDescription
                }
            }
        }
    }

    private func cancelDownload() {
        controller.modelManager.cancelDownload()
        controller.appState.downloadingModelType = nil
        controller.appState.downloadProgress = nil
        controller.appState.downloadError = nil
    }

    private func deleteModel(_ model: WhisperModelType) {
        do {
            try controller.modelManager.deleteModel(model)
            controller.refreshStatus()
        } catch {
            controller.appState.lastError = error.localizedDescription
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: WhisperModelType
    let isActive: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let downloadError: String?
    let anyDownloadActive: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDelete: () -> Void

    private var isSelectable: Bool { isInstalled && !isActive }
    private var showRetryButton: Bool { downloadError != nil }
    private var showDownloadButton: Bool { !isInstalled && !isDownloading && downloadError == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                radioButton
                    .frame(width: 18, height: 18)

                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))

                    Text(model.sizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Spacer()

                // Actions — error (Retry) checked before downloading (Cancel)
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isInstalled {
                    Button("Delete", action: onDelete)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else if showRetryButton {
                    Button("Retry", action: onRetry)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if isDownloading {
                    HStack(spacing: 8) {
                        if let progress = downloadProgress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Cancel", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                } else if showDownloadButton {
                    Button("Download", action: onDownload)
                        .font(.caption)
                        .disabled(anyDownloadActive)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectable { onSelect() }
            }
            .background(isActive ? Color.green.opacity(0.06) : Color.clear)

            // Download progress bar
            if isDownloading, let progress = downloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.blue)

                    let downloaded = Int64(progress * Double(model.approximateSize))
                    let formatter = ByteCountFormatter()
                    Text("\(formatter.string(fromByteCount: downloaded)) of \(model.sizeDescription)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 46)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }

            // Error message
            if let error = downloadError {
                Text("Download failed — \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 46)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var radioButton: some View {
        if isInstalled || isActive {
            Circle()
                .strokeBorder(isActive ? .green : .secondary.opacity(0.5), lineWidth: 2)
                .background(
                    Circle()
                        .fill(isActive ? .green : .clear)
                        .padding(4)
                )
        } else {
            Circle()
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 2)
        }
    }
}
