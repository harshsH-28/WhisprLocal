import SwiftUI
import WhisprLocalCore

public struct SetupView: View {
    let controller: DictationController
    private let permissionManager = PermissionManager()

    public init(controller: DictationController) {
        self.controller = controller
    }

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

    public var body: some View {
        Form {
            Section("Permissions") {
                // Microphone
                HStack {
                    Image(systemName: controller.appState.hasMicrophonePermission
                          ? "checkmark.circle.fill" : "mic.slash")
                        .foregroundStyle(controller.appState.hasMicrophonePermission ? .green : .orange)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("Microphone Access")
                            .font(.body)
                        Text("Required to record your voice for transcription")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !controller.appState.hasMicrophonePermission {
                        Button("Grant") {
                            Task {
                                let granted = await permissionManager.requestMicrophonePermission()
                                await MainActor.run {
                                    controller.appState.hasMicrophonePermission = granted
                                }
                            }
                        }
                    } else {
                        Text("Granted")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                // Accessibility
                HStack {
                    Image(systemName: controller.appState.hasAccessibilityPermission
                          ? "checkmark.circle.fill" : "lock.shield")
                        .foregroundStyle(controller.appState.hasAccessibilityPermission ? .green : .orange)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("Accessibility Access")
                            .font(.body)
                        Text("Required to paste text into other applications")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !controller.appState.hasAccessibilityPermission {
                        Button("Open Settings") {
                            permissionManager.requestAccessibilityPermission()
                        }
                    } else {
                        Text("Granted")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                if !controller.appState.hasAccessibilityPermission {
                    Text("If you rebuilt the app, toggle WhisprLocal OFF then ON in System Settings > Privacy & Security > Accessibility.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }

            Section("Whisper Model") {
                HStack {
                    Image(systemName: controller.appState.isModelAvailable
                          ? "checkmark.circle.fill" : "arrow.down.circle")
                        .foregroundStyle(controller.appState.isModelAvailable ? .green : .orange)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text("Model: \(controller.appState.selectedModelType.displayName)")
                            .font(.body)
                        Text("Place \(controller.appState.selectedModelType.fileName) in the models folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if controller.appState.isModelAvailable {
                        Text("Ready")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                if !controller.appState.isModelAvailable {
                    let modelManager = ModelManager()

                    if controller.appState.isDownloading {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: controller.appState.downloadProgress ?? 0)
                            HStack {
                                Text("Downloading... \(Int((controller.appState.downloadProgress ?? 0) * 100))%")
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
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Or place the model file manually at:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(modelManager.modelPath(for: controller.appState.selectedModelType).path)
                            .font(.caption)
                            .textSelection(.enabled)
                            .foregroundStyle(.blue)

                        Button("Open Models Folder") {
                            try? modelManager.ensureModelsDirectory()
                            NSWorkspace.shared.open(modelManager.modelsDirectory)
                        }
                        .font(.caption)
                    }
                }
            }

            Section {
                Button("Refresh Status") {
                    controller.refreshStatus()
                }

                if controller.appState.isSetupComplete {
                    Label("Setup Complete — WhisprLocal is ready!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            controller.refreshStatus()
        }
        .task {
            while !Task.isCancelled {
                controller.refreshStatus()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
}
