import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// ViewModel for managing app settings
@MainActor
public class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties (backed by UserDefaults via @AppStorage)
    
    @AppStorage("importedFonts") private var importedFontsJSON: String = "[]"
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("autoUpdateThumbnail") public var autoUpdateThumbnail: Bool = false
    
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    
    // MARK: - Computed Properties
    
    public var importedFonts: [String] {
        get {
            guard let data = importedFontsJSON.data(using: .utf8),
                  let fonts = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return fonts
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }
            importedFontsJSON = json
            objectWillChange.send()
        }
    }
    
    public var selectedTheme: AppTheme {
        get {
            return AppTheme(rawValue: selectedThemeRaw) ?? .system
        }
        set {
            selectedThemeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    // MARK: - Dependencies
    
    private let fontManager: FontManager
    
    // MARK: - Constants
    
    public static let githubURL = URL(string: "https://github.com/jamesmontemagno/app-podcast-assistant")!
    public static let appName = "Podcast Assistant"
    public static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    public static let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - Initialization
    
    public init(fontManager: FontManager = FontManager()) {
        self.fontManager = fontManager
    }
    
    // MARK: - Theme Management
    
    /// Update the app theme
    public func updateTheme(_ theme: AppTheme) {
        selectedTheme = theme
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
            var currentFonts = importedFonts
            if currentFonts.contains(fontName) {
                let displayName = fontManager.getDisplayName(for: fontName)
                errorMessage = "Font '\(displayName)' is already imported"
                return
            }
            
            // Add to imported fonts list
            currentFonts.append(fontName)
            currentFonts.sort()
            importedFonts = currentFonts
            
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
            var currentFonts = importedFonts
            currentFonts.removeAll { $0 == fontName }
            importedFonts = currentFonts
            
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
