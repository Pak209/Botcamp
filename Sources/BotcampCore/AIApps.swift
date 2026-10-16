import Foundation

/// Hand-off targets. Plain-text names only (no logos, no implied partnership).
public struct AIApp: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let appURL: String   // custom scheme; may not be installed
    public let webURL: String   // fallback
    public static let all: [AIApp] = [
        AIApp(id: "grok", name: "Grok", appURL: "grok://", webURL: "https://grok.com"),
        AIApp(id: "chatgpt", name: "ChatGPT", appURL: "chatgpt://", webURL: "https://chatgpt.com"),
        AIApp(id: "claude", name: "Claude", appURL: "claude://", webURL: "https://claude.ai"),
    ]
    /// Schemes to declare in Info.plist LSApplicationQueriesSchemes.
    public static var querySchemes: [String] { all.compactMap { URL(string: $0.appURL)?.scheme } }
}
