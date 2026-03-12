import Foundation
import AppKit
import LiveKit
import Combine
import Carbon.HIToolbox

@MainActor
final class AgentController: ObservableObject {
    @Published var isTalking = false
    @Published var isPushToTalk = false
    @Published var agentState: AgentState = .idle

    let livekitService: LiveKitService

    private var eventMonitor: Any?

    init(livekitService: LiveKitService) {
        self.livekitService = livekitService
    }

    // MARK: - Global Hotkey (Left Control)

    func startGlobalHotkey() {
        stopGlobalHotkey()

        // Monitor key down — left control pressed
        let downMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let isLeftControl = event.modifierFlags.contains(.control)
                && event.keyCode == UInt16(kVK_Control)

            Task { @MainActor in
                if isLeftControl && !self.isTalking && self.isPushToTalk {
                    await self.startTalking()
                } else if !isLeftControl && self.isTalking && self.isPushToTalk {
                    await self.stopTalking()
                }
            }
        }
        eventMonitor = downMonitor

        // Also monitor local events (when app is focused)
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let isLeftControl = event.modifierFlags.contains(.control)
                && event.keyCode == UInt16(kVK_Control)

            Task { @MainActor in
                if isLeftControl && !self.isTalking && self.isPushToTalk {
                    await self.startTalking()
                } else if !isLeftControl && self.isTalking && self.isPushToTalk {
                    await self.stopTalking()
                }
            }
            return event
        }
    }

    func stopGlobalHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
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
            startGlobalHotkey()
            Task {
                try? await livekitService.room.localParticipant.setMicrophone(enabled: false)
                livekitService.isMicEnabled = false
            }
        } else {
            stopGlobalHotkey()
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

    deinit {
        // eventMonitor cleanup handled in stopGlobalHotkey
    }
}

enum AgentState {
    case idle
    case listening
    case thinking
    case speaking
}
