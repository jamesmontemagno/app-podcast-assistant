import Foundation
import AppKit
import CoreText

/// Service for managing custom font imports and availability
public class FontManager {
    
    // MARK: - Error Types
    
    public enum FontError: LocalizedError {
        case invalidFontFile
        case fontAlreadyImported
        case fontRegistrationFailed
        case fontNotFound
        case fileOperationFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidFontFile:
                return "The selected file is not a valid font file"
            case .fontAlreadyImported:
                return "This font has already been imported"
            case .fontRegistrationFailed:
                return "Failed to register the font with the system"
            case .fontNotFound:
                return "Font file not found"
            case .fileOperationFailed:
                return "Failed to perform file operation"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    /// Directory where imported fonts are stored
    private var fontsDirectory: URL {
        get throws {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDir = appSupport.appendingPathComponent("PodcastAssistant", isDirectory: true)
            let fontsDir = appDir.appendingPathComponent("Fonts", isDirectory: true)
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: fontsDir.path) {
                try fileManager.createDirectory(at: fontsDir, withIntermediateDirectories: true)
            }
            
            return fontsDir
        }
    }
    
    // MARK: - Public Methods
    
    /// Import a font file and register it with the system
    /// - Parameter fontURL: URL of the font file to import
    /// - Returns: The PostScript name of the imported font
    public func importFont(from fontURL: URL) throws -> String {
        // Verify it's a valid font file
        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider),
              let postScriptName = font.postScriptName as String? else {
            throw FontError.invalidFontFile
        }
        
        // Check if font is already registered
        if isFontRegistered(postScriptName) {
            throw FontError.fontAlreadyImported
        }
        
        // Copy font file to app's fonts directory
        let fontsDir = try fontsDirectory
        let destinationURL = fontsDir.appendingPathComponent(fontURL.lastPathComponent)
        
        // Remove existing file if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: fontURL, to: destinationURL)
        
        // Register the font
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(destinationURL as CFURL, .process, &error) else {
            // Clean up the copied file
            try? fileManager.removeItem(at: destinationURL)
            throw FontError.fontRegistrationFailed
        }
        
        return postScriptName
    }
    
    /// Remove an imported font
    /// - Parameter fontName: PostScript name of the font to remove
    public func removeFont(_ fontName: String) throws {
        let fontsDir = try fontsDirectory
        
        // Find the font file
        let files = try fileManager.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)
        
        for fileURL in files {
            if let fontDataProvider = CGDataProvider(url: fileURL as CFURL),
               let font = CGFont(fontDataProvider),
               let postScriptName = font.postScriptName as String?,
               postScriptName == fontName {
                
                // Unregister the font
                CTFontManagerUnregisterFontsForURL(fileURL as CFURL, .process, nil)
                
                // Delete the file
                try fileManager.removeItem(at: fileURL)
                return
            }
        }
        
        throw FontError.fontNotFound
    }
    
    /// Check if a font is registered
    /// - Parameter fontName: PostScript name of the font
    /// - Returns: True if the font is registered
    public func isFontRegistered(_ fontName: String) -> Bool {
        return NSFont(name: fontName, size: 12) != nil
    }
    
    /// Get all available font names (system + imported)
    /// - Returns: Array of font names
    public func getAllAvailableFonts() -> [String] {
        let fontManager = NSFontManager.shared
        return fontManager.availableFonts.sorted()
    }
    
    /// Get display name for a font (converts PostScript name to readable name)
    /// - Parameter postScriptName: PostScript name of the font
    /// - Returns: Display name or the PostScript name if display name unavailable
    public func getDisplayName(for postScriptName: String) -> String {
        guard let font = NSFont(name: postScriptName, size: 12) else {
            return postScriptName
        }
        return font.displayName ?? postScriptName
    }
    
    /// Register all fonts from the fonts directory on app launch
    public func registerImportedFonts() throws {
        let fontsDir = try fontsDirectory
        
        guard fileManager.fileExists(atPath: fontsDir.path) else {
            return
        }
        
        let files = try fileManager.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)
        
        for fileURL in files {
            // Skip non-font files
            let ext = fileURL.pathExtension.lowercased()
            guard ["ttf", "otf", "ttc"].contains(ext) else { continue }
            
            // Register the font (ignore errors for already registered fonts)
            CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, nil)
        }
    }
}
