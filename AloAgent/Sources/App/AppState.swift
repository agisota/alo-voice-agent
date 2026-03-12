import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var isScreenSharing = false
    @Published var agentSpeaking = false
    @Published var transcriptLines: [TranscriptLine] = []

    let livekitService: LiveKitService
    let agentController: AgentController

    // Configuration (persisted)
    @AppStorage("livekitURL") var livekitURL = "ws://localhost:7880"
    @AppStorage("roomName") var roomName = "alo-room"
    @AppStorage("userIdentity") var userIdentity = "solofounder"

    private var cancellables = Set<AnyCancellable>()

    init() {
        let service = LiveKitService()
        self.livekitService = service
        self.agentController = AgentController(livekitService: service)

        // Bind service state
        service.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)

        service.$isScreenSharing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScreenSharing)
    }

    func connect() async {
        do {
            try await livekitService.connect(
                url: livekitURL,
                roomName: roomName,
                identity: userIdentity
            )
        } catch {
            print("Connection error: \(error)")
        }
    }

    func disconnect() async {
        await livekitService.disconnect()
    }

    func addTranscript(_ line: TranscriptLine) {
        transcriptLines.append(line)
        if transcriptLines.count > 100 {
            transcriptLines.removeFirst()
        }
    }
}

struct TranscriptLine: Identifiable {
    let id = UUID()
    let speaker: String
    let text: String
    let timestamp: Date

    var isAgent: Bool { speaker == "agent" }
}
