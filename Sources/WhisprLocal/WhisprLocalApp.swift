import SwiftUI
import WhisprLocalCore
import WhisprLocalUI

@main
struct WhisprLocalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: appDelegate.controller)
        } label: {
            MenuBarIcon(state: appDelegate.controller.appState.recordingState)
        }
        .menuBarExtraStyle(.window)

        Window("WhisprLocal Settings", id: "settings") {
            SettingsView(controller: appDelegate.controller)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .defaultSize(width: 520, height: 440)
        .windowResizability(.contentSize)
    }
}

/// Dynamic menu bar icon based on recording state.
struct MenuBarIcon: View {
    let state: RecordingState

    var body: some View {
        switch state {
        case .idle:
            Image(systemName: "waveform")
        case .recording:
            Image(systemName: "mic.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red)
        case .transcribing:
            Image(systemName: "ellipsis.circle")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.blue)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow)
        }
    }
}
