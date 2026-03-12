import Foundation

/// Configuration for agent connection
struct AgentConfig: Codable {
    var livekitURL: String
    var roomName: String
    var identity: String
    var apiKey: String
    var apiSecret: String

    static let defaultConfig = AgentConfig(
        livekitURL: "ws://localhost:7880",
        roomName: "alo-room",
        identity: "solofounder",
        apiKey: "devkey",
        apiSecret: "devsecret"
    )
}

/// Chat message from agent or user
struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: String
    let content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.id = UUID().uuidString
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}
