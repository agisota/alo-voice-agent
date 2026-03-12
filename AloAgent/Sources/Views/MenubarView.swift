import SwiftUI

struct MenubarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var livekitService: LiveKitService
    @EnvironmentObject var agentController: AgentController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status header
            HStack {
                Circle()
                    .fill(livekitService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(livekitService.isConnected ? "Alo — на связи" : "Alo — offline")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            if livekitService.isConnected {
                // Quick controls
                Button(action: {
                    Task { try? await livekitService.toggleMicrophone() }
                }) {
                    Label(
                        livekitService.isMicEnabled ? "Выключить микрофон" : "Включить микрофон",
                        systemImage: livekitService.isMicEnabled ? "mic.fill" : "mic.slash.fill"
                    )
                }
                .padding(.horizontal)

                Button(action: {
                    Task { try? await livekitService.toggleScreenShare() }
                }) {
                    Label(
                        livekitService.isScreenSharing ? "Остановить шаринг экрана" : "Поделиться экраном",
                        systemImage: livekitService.isScreenSharing ? "rectangle.badge.minus" : "rectangle.badge.plus"
                    )
                }
                .padding(.horizontal)

                Button(action: {
                    agentController.togglePushToTalk()
                }) {
                    Label(
                        agentController.isPushToTalk ? "PTT: ВКЛ" : "PTT: ВЫКЛ",
                        systemImage: agentController.isPushToTalk ? "hand.raised.fill" : "hand.raised"
                    )
                }
                .padding(.horizontal)

                Divider()

                Button(action: {
                    Task { await appState.disconnect() }
                }) {
                    Label("Отключиться", systemImage: "phone.down.fill")
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
            } else {
                Button(action: {
                    Task { await appState.connect() }
                }) {
                    Label("Подключиться", systemImage: "bolt.fill")
                }
                .padding(.horizontal)
            }

            Divider()

            Button(action: {
                NSApp.terminate(nil)
            }) {
                Label("Выход", systemImage: "power")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 250)
        .buttonStyle(.plain)
    }
}
