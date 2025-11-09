import Foundation
import SwiftData

/// App-wide settings model
@Model
public final class AppSettings {
    @Attribute(.unique) public var id: String
    public var importedFonts: [String] // Array of imported font names
    public var createdAt: Date
    public var updatedAt: Date
    
    public init() {
        self.id = "app-settings" // Singleton pattern - only one settings instance
        self.importedFonts = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension AppSettings: Identifiable {
    
}
