import Foundation
import LiveKit
import Combine

@MainActor
final class LiveKitService: ObservableObject {
    @Published var room = Room()
    @Published var isConnected = false
    @Published var isMicEnabled = false
    @Published var isScreenSharing = false
    @Published var agentParticipant: RemoteParticipant?

    private var roomDelegate: RoomDelegateHandler?

    func connect(url: String, roomName: String, identity: String) async throws {
        let token = try await fetchToken(roomName: roomName, identity: identity)

        let connectOptions = ConnectOptions(autoSubscribe: true)
        let roomOptions = RoomOptions()

        let delegate = RoomDelegateHandler(service: self)
        self.roomDelegate = delegate
        room.add(delegate: delegate)

        try await room.connect(url: url, token: token, connectOptions: connectOptions, roomOptions: roomOptions)
        isConnected = true
        isMicEnabled = room.localParticipant.isMicrophoneEnabled()

        for (_, participant) in room.remoteParticipants {
            if participant.identity?.stringValue.contains("agent") == true {
                agentParticipant = participant
                break
            }
        }
    }

    func disconnect() async {
        await room.disconnect()
        isConnected = false
        isMicEnabled = false
        isScreenSharing = false
        agentParticipant = nil
    }

    func toggleMicrophone() async throws {
        let newState = !isMicEnabled
        try await room.localParticipant.setMicrophone(enabled: newState)
        isMicEnabled = newState
    }

    // MARK: - Realtime Screen Streaming

    func startScreenShare() async throws {
        try await room.localParticipant.setScreenShare(enabled: true)
        isScreenSharing = true
    }

    func stopScreenShare() async throws {
        try await room.localParticipant.setScreenShare(enabled: false)
        isScreenSharing = false
    }

    func toggleScreenShare() async throws {
        if isScreenSharing {
            try await stopScreenShare()
        } else {
            try await startScreenShare()
        }
    }

    // MARK: - Token

    private func fetchToken(roomName: String, identity: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/lk")
        process.arguments = [
            "token", "create",
            "--api-key", "APIkgYvMNZJAqun",
            "--api-secret", "buH0XcsqH3JfqC1XuFBU5H81jnp8zfRLOIL6QmAfN0TB",
            "--join",
            "--room", roomName,
            "--identity", identity,
            "--valid-for", "24h",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            throw AloError.tokenGenerationFailed
        }
        return token
    }
}

// MARK: - Room Delegate

final class RoomDelegateHandler: RoomDelegate, @unchecked Sendable {
    weak var service: LiveKitService?

    init(service: LiveKitService) {
        self.service = service
    }

    nonisolated func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        Task { @MainActor in
            if participant.identity?.stringValue.contains("agent") == true {
                service?.agentParticipant = participant
            }
        }
    }

    nonisolated func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        Task { @MainActor in
            if participant.identity == service?.agentParticipant?.identity {
                service?.agentParticipant = nil
            }
        }
    }

    nonisolated func room(_ room: Room, participant: RemoteParticipant?, didReceiveData data: Data, forTopic topic: String, encryptionType: EncryptionType) {
        if topic == "lk-chat-topic" || topic == "transcription" {
            if let text = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    print("Received: \(text)")
                }
            }
        }
    }
}

// MARK: - Errors

enum AloError: LocalizedError {
    case noScreenSource
    case tokenGenerationFailed

    var errorDescription: String? {
        switch self {
        case .noScreenSource: return "No screen capture source available"
        case .tokenGenerationFailed: return "Failed to generate LiveKit token"
        }
    }
}
