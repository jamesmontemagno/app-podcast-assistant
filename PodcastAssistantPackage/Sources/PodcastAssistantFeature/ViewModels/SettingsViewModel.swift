import Foundation
import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// ViewModel for managing app settings
@MainActor
public class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var importedFonts: [String] = []
    @Published public var selectedTheme: AppTheme = .system
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    
    // MARK: - Dependencies
    
    private let fontManager: FontManager
    private let modelContext: ModelContext
    private var settings: AppSettings?
    
    // MARK: - Constants
    
    public static let githubURL = URL(string: "https://github.com/jamesmontemagno/app-podcast-assistant")!
    public static let appName = "Podcast Assistant"
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    public static let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext, fontManager: FontManager = FontManager()) {
        self.modelContext = modelContext
        self.fontManager = fontManager
        
        // Load or create settings
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let descriptor = FetchDescriptor<AppSettings>()
        
        do {
            let allSettings = try modelContext.fetch(descriptor)
            
            if let existingSettings = allSettings.first {
                settings = existingSettings
                importedFonts = existingSettings.importedFonts
                selectedTheme = existingSettings.appTheme
            } else {
                // Create new settings
                let newSettings = AppSettings()
                modelContext.insert(newSettings)
                try modelContext.save()
                settings = newSettings
                importedFonts = []
                selectedTheme = .system
            }
        } catch {
            print("Error loading settings: \(error)")
            // Create fallback settings
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            settings = newSettings
            importedFonts = []
            selectedTheme = .system
        }
    }
    
    private func saveSettings() {
        guard let settings = settings else { return }
        
        settings.importedFonts = importedFonts
        settings.appTheme = selectedTheme
        settings.updatedAt = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving settings: \(error)")
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Theme Management
    
    /// Update the app theme
    public func updateTheme(_ theme: AppTheme) {
        selectedTheme = theme
        saveSettings()
        applyTheme(theme)
    }
    
    /// Apply the theme to the app appearance
    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    /// Apply the current theme (called on app launch)
    public func applyCurrentTheme() {
        applyTheme(selectedTheme)
    }
    
    // MARK: - Font Management
    
    /// Import a font file
    public func importFont() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select a font file to import"
        
        // Set allowed file types
        if let ttfType = UTType(filenameExtension: "ttf"),
           let otfType = UTType(filenameExtension: "otf"),
           let ttcType = UTType(filenameExtension: "ttc") {
            panel.allowedContentTypes = [ttfType, otfType, ttcType]
        } else {
            panel.allowedContentTypes = []
        }
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            
            Task { @MainActor in
                self?.importFontFile(url: url)
            }
        }
    }
    
    private func importFontFile(url: URL) {
        do {
            let fontName = try fontManager.importFont(from: url)
            
            // Check if this font is already in our imported fonts list
            if importedFonts.contains(fontName) {
                let displayName = fontManager.getDisplayName(for: fontName)
                errorMessage = "Font '\(displayName)' is already imported"
                return
            }
            
            // Add to imported fonts list
            importedFonts.append(fontName)
            importedFonts.sort()
            saveSettings()
            
            let displayName = fontManager.getDisplayName(for: fontName)
            successMessage = "Successfully imported '\(displayName)'"
            
            // Clear success message after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if self.successMessage == "Successfully imported '\(displayName)'" {
                        self.successMessage = nil
                    }
                }
            }
        } catch {
            errorMessage = "Failed to import font: \(error.localizedDescription)"
        }
    }
    
    /// Remove an imported font
    public func removeFont(_ fontName: String) {
        do {
            try fontManager.removeFont(fontName)
            
            // Remove from list
            importedFonts.removeAll { $0 == fontName }
            saveSettings()
            
            successMessage = "Font removed successfully"
            
            // Clear success message after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if self.successMessage == "Font removed successfully" {
                        self.successMessage = nil
                    }
                }
            }
        } catch {
            errorMessage = "Failed to remove font: \(error.localizedDescription)"
        }
    }
    
    /// Get display name for a font
    public func getDisplayName(for fontName: String) -> String {
        return fontManager.getDisplayName(for: fontName)
    }
    
    /// Clear error message
    public func clearError() {
        errorMessage = nil
    }
}
