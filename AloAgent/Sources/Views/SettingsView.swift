import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("LiveKit Connection") {
                TextField("Server URL", text: $appState.livekitURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Room Name", text: $appState.roomName)
                    .textFieldStyle(.roundedBorder)

                TextField("Identity", text: $appState.userIdentity)
                    .textFieldStyle(.roundedBorder)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Agent", value: "Alo (Grok Realtime)")
                LabeledContent("Voice", value: "Eve (Multilingual)")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .navigationTitle("Settings")
    }
}
