import SwiftUI
import WhisprLocalCore

public struct SetupView: View {
    let controller: DictationController
    @Binding var selectedTab: Int
    private let permissionManager = PermissionManager()

    public init(controller: DictationController, selectedTab: Binding<Int>) {
        self.controller = controller
        self._selectedTab = selectedTab
    }

    private var anyModelInstalled: Bool {
        !controller.modelManager.installedModels().isEmpty
    }

    private var allComplete: Bool {
        controller.appState.hasMicrophonePermission
            && controller.appState.hasAccessibilityPermission
            && anyModelInstalled
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    // Microphone
                    SetupRow(
                        icon: "🎙",
                        title: "Microphone",
                        subtitle: controller.appState.hasMicrophonePermission
                            ? nil : "Required to capture audio",
                        isGranted: controller.appState.hasMicrophonePermission,
                        action: {
                            Task {
                                let granted = await permissionManager.requestMicrophonePermission()
                                await MainActor.run {
                                    controller.appState.hasMicrophonePermission = granted
                                }
                            }
                        },
                        actionLabel: "Grant"
                    )

                    Divider().padding(.leading, 56)

                    // Accessibility
                    SetupRow(
                        icon: "⌨️",
                        title: "Accessibility",
                        subtitle: controller.appState.hasAccessibilityPermission
                            ? nil : "Required to paste transcribed text",
                        isGranted: controller.appState.hasAccessibilityPermission,
                        action: {
                            permissionManager.requestAccessibilityPermission()
                        },
                        actionLabel: "Open Settings"
                    )

                    Divider().padding(.leading, 56)

                    // Model
                    SetupRow(
                        icon: "🧠",
                        title: "Whisper Model",
                        subtitle: anyModelInstalled
                            ? nil : "Download a model to start transcribing",
                        isGranted: anyModelInstalled,
                        action: { selectedTab = 1 },
                        actionLabel: "Go to Models"
                    )
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                if allComplete {
                    HStack {
                        Spacer()
                        Text("All set — press ⌥D anywhere to start dictating")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                        Spacer()
                    }
                    .padding(12)
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Setup Row

private struct SetupRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isGranted: Bool
    let action: (() -> Void)?
    let actionLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
                .frame(width: 28, height: 28)
                .background(isGranted ? Color.green.opacity(0.1) : Color(nsColor: .quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if let action {
                Button(actionLabel, action: action)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
