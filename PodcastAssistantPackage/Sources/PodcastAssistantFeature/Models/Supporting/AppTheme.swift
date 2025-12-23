import Foundation

/// App appearance theme options
public enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var displayName: String {
        rawValue
    }
}
