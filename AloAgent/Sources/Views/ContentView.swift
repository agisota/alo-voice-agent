import SwiftUI
import LiveKit
import LiveKitComponents

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var livekitService: LiveKitService
    @EnvironmentObject var agentController: AgentController

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(nsColor: .darkGray).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding()

                Divider()
                    .background(Color.white.opacity(0.1))

                if livekitService.isConnected {
                    // Agent room
                    agentRoomView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Controls bar
                    controlsBar
                        .padding()
                } else {
                    // Connect screen
                    connectView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundColor(livekitService.isConnected ? .green : .gray)

            Text("Alo Agent")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Connection indicator
            Circle()
                .fill(livekitService.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(livekitService.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Connect View

    private var connectView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            Text("Нажми Connect чтобы начать")
                .font(.headline)
                .foregroundColor(.secondary)

            Button(action: {
                Task { await appState.connect() }
            }) {
                Label("Connect", systemImage: "bolt.fill")
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
        }
    }

    // MARK: - Agent Room

    private var agentRoomView: some View {
        VStack(spacing: 16) {
            // Audio visualizer area
            if let agent = livekitService.agentParticipant {
                AgentAudioView(participant: agent)
                    .frame(height: 200)
            } else {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Waiting for agent...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(height: 200)
            }

            // Transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.transcriptLines) { line in
                            TranscriptBubble(line: line)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: appState.transcriptLines.count) { _ in
                    if let last = appState.transcriptLines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 20) {
            // Mic toggle
            Button(action: {
                Task { try? await livekitService.toggleMicrophone() }
            }) {
                Image(systemName: livekitService.isMicEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(livekitService.isMicEnabled ? .green : .red)

            // Push-to-talk (Left Control global hotkey)
            Button(action: {
                agentController.togglePushToTalk()
            }) {
                VStack(spacing: 2) {
                    Image(systemName: agentController.isPushToTalk ? "hand.raised.fill" : "hand.raised")
                        .font(.title2)
                    if agentController.isPushToTalk {
                        Text("L-Ctrl")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(agentController.isPushToTalk ? .orange : .gray)

            // Screen share
            Button(action: {
                Task { try? await livekitService.toggleScreenShare() }
            }) {
                Image(systemName: livekitService.isScreenSharing ? "rectangle.inset.filled.and.person.filled" : "rectangle.and.person.inset.filled")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(livekitService.isScreenSharing ? .blue : .gray)

            Spacer()

            // Disconnect
            Button(action: {
                Task { await appState.disconnect() }
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

// MARK: - Transcript Bubble

struct TranscriptBubble: View {
    let line: TranscriptLine

    var body: some View {
        HStack {
            if line.isAgent {
                agentBubble
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 60)
                userBubble
            }
        }
    }

    private var agentBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(.blue)

            Text(line.text)
                .font(.body)
                .padding(10)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(12)
        }
    }

    private var userBubble: some View {
        Text(line.text)
            .font(.body)
            .padding(10)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
    }
}

// MARK: - Agent Audio View

struct AgentAudioView: View {
    let participant: RemoteParticipant

    @State private var audioLevels: [CGFloat] = Array(repeating: 0.1, count: 40)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<audioLevels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: max(4, audioLevels[i] * 150))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels[i])
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onAppear {
            startVisualization()
        }
    }

    private func startVisualization() {
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            withAnimation {
                audioLevels = audioLevels.map { _ in
                    CGFloat.random(in: 0.05...0.8)
                }
            }
        }
    }
}
