import Foundation

/// Available AI providers for generation
public enum AIProvider: String, CaseIterable, Codable {
    case apple = "apple"
    case openAI = "openai"
    
    public var displayName: String {
        switch self {
        case .apple: return "On-Device (Apple Intelligence)"
        case .openAI: return "OpenAI"
        }
    }
}
