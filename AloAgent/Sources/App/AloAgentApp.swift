import SwiftUI

@main
struct AloAgentApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Menubar — always-on tray icon
        MenuBarExtra("Alo", systemImage: appState.isConnected ? "waveform.circle.fill" : "waveform.circle") {
            MenubarView()
                .environmentObject(appState)
                .environmentObject(appState.livekitService)
                .environmentObject(appState.agentController)
        }
        .menuBarExtraStyle(.window)

        // Main window
        WindowGroup("Alo Agent") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.livekitService)
                .environmentObject(appState.agentController)
                .frame(minWidth: 400, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)

        // Settings
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
