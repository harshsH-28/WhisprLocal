import Foundation

/// Orchestrates the full dictation pipeline: record → transcribe → paste.
@Observable
public final class DictationController {
    private let audioRecorder: AudioRecorder
    private let transcriber: WhisperTranscriber
    private let textInjector: TextInjector
    private let modelManager: ModelManager
    private let hotkeyManager: HotkeyManager

    public let appState: AppState

    public init(
        appState: AppState = AppState(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        transcriber: WhisperTranscriber = WhisperTranscriber(),
        textInjector: TextInjector = TextInjector(),
        modelManager: ModelManager = ModelManager(),
        hotkeyManager: HotkeyManager = HotkeyManager()
    ) {
        self.appState = appState
        self.audioRecorder = audioRecorder
        self.transcriber = transcriber
        self.textInjector = textInjector
        self.modelManager = modelManager
        self.hotkeyManager = hotkeyManager
    }

    /// Set up hotkey and initial state.
    public func setup() {
        hotkeyManager.register { [weak self] in
            self?.toggleDictation()
        }
    }

    /// Toggle dictation: start if idle, stop if recording.
    public func toggleDictation() {
        switch appState.recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break // Ignore toggle during transcription or error
        }
    }

    /// Begin recording audio.
    public func startRecording() {
        guard appState.transition(to: .recording) else { return }

        do {
            try audioRecorder.startRecording()
        } catch {
            appState.transition(to: .error("Failed to start recording: \(error.localizedDescription)"))
        }
    }

    /// Stop recording and begin transcription pipeline.
    public func stopRecording() {
        guard appState.recordingState.isRecording else { return }

        do {
            let samples = try audioRecorder.stopRecording()
            appState.transition(to: .transcribing)

            Task {
                await transcribeAndInject(samples: samples)
            }
        } catch {
            appState.transition(to: .error("Failed to stop recording: \(error.localizedDescription)"))
        }
    }

    /// Cancel current recording without transcribing.
    public func cancelRecording() {
        audioRecorder.cancelRecording()
        appState.transition(to: .idle)
    }

    /// Load the selected model if not already loaded.
    public func ensureModelLoaded() async throws {
        guard !appState.isModelLoaded else { return }

        let modelPath = modelManager.modelPath(for: appState.selectedModelType)
        guard modelManager.isModelAvailable(appState.selectedModelType) else {
            throw TranscriberError.modelLoadFailed(modelPath.path)
        }

        try await transcriber.loadModel(path: modelPath.path)
        appState.isModelLoaded = true
    }

    /// Unload the current model from memory.
    public func unloadModel() async {
        await transcriber.unloadModel()
        appState.isModelLoaded = false
    }

    /// Refresh permission and model status.
    public func refreshStatus() {
        let permissionManager = PermissionManager()
        appState.hasMicrophonePermission = permissionManager.checkMicrophonePermission()
        appState.hasAccessibilityPermission = permissionManager.checkAccessibilityPermission()
        appState.isModelAvailable = modelManager.isModelAvailable(appState.selectedModelType)
    }

    // MARK: - Private

    private func transcribeAndInject(samples: [Float]) async {
        do {
            // Ensure model is loaded
            try await ensureModelLoaded()

            // Transcribe
            let language = await MainActor.run { self.appState.selectedLanguage }
            let text = try await transcriber.transcribe(samples: samples, language: language)

            _ = await MainActor.run {
                self.appState.lastTranscription = text
            }

            // Refresh permissions before injection so AXIsProcessTrusted() is current
            await MainActor.run { self.refreshStatus() }

            // Inject text into focused app
            if !text.isEmpty {
                try await textInjector.inject(text: text)
            }

            _ = await MainActor.run {
                self.appState.transition(to: .idle)
            }
        } catch {
            _ = await MainActor.run {
                self.appState.transition(to: .error("Transcription failed: \(error.localizedDescription)"))
            }
        }
    }
}
