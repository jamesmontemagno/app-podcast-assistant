import Foundation
import SwiftData

/// App appearance theme options
public enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    public var displayName: String {
        return self.rawValue
    }
}

/// App-wide settings model
@Model
public final class AppSettings {
    @Attribute(.unique) public var id: String
    public var importedFonts: [String] // Array of imported font names
    public var theme: String // Stored as String for SwiftData compatibility
    public var autoUpdateThumbnail: Bool // Auto-regenerate thumbnail on value changes
    public var createdAt: Date
    public var updatedAt: Date
    
    // Computed property for type-safe theme access
    public var appTheme: AppTheme {
        get {
            return AppTheme(rawValue: theme) ?? .system
        }
        set {
            theme = newValue.rawValue
        }
    }
    
    public init() {
        self.id = "app-settings" // Singleton pattern - only one settings instance
        self.importedFonts = []
        self.theme = AppTheme.system.rawValue
        self.autoUpdateThumbnail = true // Default to manual regeneration for better performance
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension AppSettings: Identifiable {
    
}
