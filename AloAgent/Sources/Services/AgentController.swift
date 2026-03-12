import Foundation
import LiveKit
import Combine

@MainActor
final class AgentController: ObservableObject {
    @Published var isTalking = false
    @Published var isPushToTalk = false
    @Published var agentState: AgentState = .idle

    let livekitService: LiveKitService

    init(livekitService: LiveKitService) {
        self.livekitService = livekitService
    }

    // MARK: - Push to Talk

    func startTalking() async {
        guard isPushToTalk else { return }
        isTalking = true
        try? await livekitService.room.localParticipant.setMicrophone(enabled: true)
        livekitService.isMicEnabled = true
    }

    func stopTalking() async {
        guard isPushToTalk else { return }
        isTalking = false
        try? await livekitService.room.localParticipant.setMicrophone(enabled: false)
        livekitService.isMicEnabled = false
    }

    func togglePushToTalk() {
        isPushToTalk.toggle()
        if isPushToTalk {
            // Disable mic by default in PTT mode
            Task {
                try? await livekitService.room.localParticipant.setMicrophone(enabled: false)
                livekitService.isMicEnabled = false
            }
        }
    }

    // MARK: - RPC to Agent

    func sendRPC(method: String, payload: String) async throws -> String {
        guard let agentIdentity = livekitService.agentParticipant?.identity else {
            throw AloError.noScreenSource
        }
        let response = try await livekitService.room.localParticipant.performRpc(
            destinationIdentity: agentIdentity,
            method: method,
            payload: payload
        )
        return response
    }
}

enum AgentState {
    case idle
    case listening
    case thinking
    case speaking
}
