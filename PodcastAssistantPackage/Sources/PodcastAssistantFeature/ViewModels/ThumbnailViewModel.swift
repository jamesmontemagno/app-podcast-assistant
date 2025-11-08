import Foundation
import SwiftUI
import AppKit

/// ViewModel for thumbnail generation functionality
@MainActor
public class ThumbnailViewModel: ObservableObject {
    @Published public var backgroundImage: NSImage? {
        didSet { generateThumbnail() }
    }
    @Published public var overlayImage: NSImage? {
        didSet { generateThumbnail() }
    }
    @Published public var episodeNumber: String = "" {
        didSet { generateThumbnail() }
    }
    @Published public var selectedFont: String = "Helvetica-Bold" {
        didSet { generateThumbnail() }
    }
    @Published public var fontSize: Double = 72 {
        didSet { generateThumbnail() }
    }
    @Published public var episodeNumberPosition: ThumbnailGenerator.TextPosition = .topRight {
        didSet { generateThumbnail() }
    }
    @Published public var horizontalPadding: Double = 40 {
        didSet { generateThumbnail() }
    }
    @Published public var verticalPadding: Double = 40 {
        didSet { generateThumbnail() }
    }
    @Published public var generatedThumbnail: NSImage?
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    
    private let generator = ThumbnailGenerator()
    private let defaults = UserDefaults.standard
    private let overlayImageBookmarkKey = "ThumbnailOverlayImageBookmark"
    private let customFontsKey = "ThumbnailCustomFonts"
    
    public var availableFonts: [String] {
        var fonts = [
            "Helvetica-Bold",
            "Arial-BoldMT",
            "Futura-Bold",
            "Impact",
            "Menlo-Bold",
            "AvenirNext-Bold",
            "GillSans-Bold"
        ]
        
        // Add custom fonts
        if let customFonts = defaults.stringArray(forKey: customFontsKey) {
            fonts.append(contentsOf: customFonts)
        }
        
        return fonts
    }
    
    public init() {
        loadSavedOverlay()
    }
    
    /// Imports a background image
    public func importBackgroundImage() {
        selectImage(saveToOverlay: false) { [weak self] image, _ in
            self?.backgroundImage = image
            self?.successMessage = "Background image loaded"
            self?.errorMessage = nil
        }
    }
    
    /// Imports an overlay image
    public func importOverlayImage() {
        selectImage(saveToOverlay: true) { [weak self] image, url in
            guard let self = self else { return }
            self.overlayImage = image
            if let url = url {
                self.saveOverlayImageBookmark(url)
            }
            self.successMessage = "Overlay image loaded"
            self.errorMessage = nil
        }
    }
    
    /// Removes the overlay image
    public func removeOverlayImage() {
        overlayImage = nil
        defaults.removeObject(forKey: overlayImageBookmarkKey)
        successMessage = "Overlay removed"
        errorMessage = nil
    }
    
    /// Loads saved overlay image from UserDefaults using security-scoped bookmark
    private func loadSavedOverlay() {
        guard let bookmarkData = defaults.data(forKey: overlayImageBookmarkKey) else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            if let image = NSImage(contentsOf: url) {
                overlayImage = image
            }
            
            // If bookmark is stale, recreate it
            if isStale {
                saveOverlayImageBookmark(url)
            }
        } catch {
            // Bookmark couldn't be resolved, remove it
            defaults.removeObject(forKey: overlayImageBookmarkKey)
        }
    }
    
    /// Saves overlay image URL as a security-scoped bookmark to UserDefaults
    private func saveOverlayImageBookmark(_ url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmarkData, forKey: overlayImageBookmarkKey)
        } catch {
            errorMessage = "Failed to save overlay image reference: \(error.localizedDescription)"
        }
    }
    
    /// Pastes image from clipboard for background
    public func pasteBackgroundFromClipboard() {
        if let image = getImageFromClipboard() {
            backgroundImage = image
            successMessage = "Background pasted from clipboard"
            errorMessage = nil
        } else {
            errorMessage = "No image found in clipboard"
        }
    }
    
    /// Pastes image from clipboard for overlay
    public func pasteOverlayFromClipboard() {
        if let image = getImageFromClipboard() {
            overlayImage = image
            successMessage = "Overlay pasted from clipboard"
            errorMessage = nil
        } else {
            errorMessage = "No image found in clipboard"
        }
    }
    
    /// Gets image from clipboard
    private func getImageFromClipboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let imageData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData) {
            return image
        } else if let imageData = pasteboard.data(forType: .png),
                  let image = NSImage(data: imageData) {
            return image
        }
        return nil
    }
    
    /// Loads a custom font from file
    public func loadCustomFont() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "ttf")!, .init(filenameExtension: "otf")!]
        panel.message = "Select a font file (.ttf or .otf)"
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    self.registerCustomFont(from: url)
                }
            }
        }
    }
    
    /// Registers a custom font and saves it
    private func registerCustomFont(from url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Failed to access font file: Permission denied"
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        guard let fontDataProvider = CGDataProvider(url: url as CFURL),
              let font = CGFont(fontDataProvider),
              let fontName = font.postScriptName as String? else {
            errorMessage = "Failed to load font file"
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error) as String
                // Font might already be registered, which is fine
                if !errorDescription.contains("already registered") {
                    self.errorMessage = "Failed to register font: \(errorDescription)"
                    return
                }
            }
        }
        
        // Save font name to UserDefaults
        var customFonts = defaults.stringArray(forKey: customFontsKey) ?? []
        if !customFonts.contains(fontName) {
            customFonts.append(fontName)
            defaults.set(customFonts, forKey: customFontsKey)
            selectedFont = fontName
            successMessage = "Custom font '\(fontName)' loaded successfully"
            errorMessage = nil
            objectWillChange.send()
        } else {
            selectedFont = fontName
            successMessage = "Font already available"
        }
    }
    
    /// Generic image selection helper
    private func selectImage(saveToOverlay: Bool, completion: @escaping (NSImage?, URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .image]
        panel.message = "Select an image file"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    // Start accessing security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        self.errorMessage = "Failed to access file: Permission denied"
                        completion(nil, nil)
                        return
                    }
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    if let image = NSImage(contentsOf: url) {
                        completion(image, saveToOverlay ? url : nil)
                    } else {
                        self.errorMessage = "Failed to load image"
                        completion(nil, nil)
                    }
                }
            }
        }
    }
    
    /// Generates the thumbnail
    public func generateThumbnail() {
        guard let background = backgroundImage else {
            errorMessage = "Please select a background image"
            return
        }
        
        errorMessage = nil
        successMessage = nil
        
        if let thumbnail = generator.generateThumbnail(
            backgroundImage: background,
            overlayImage: overlayImage,
            episodeNumber: episodeNumber,
            fontName: selectedFont,
            fontSize: CGFloat(fontSize),
            position: episodeNumberPosition,
            horizontalPadding: CGFloat(horizontalPadding),
            verticalPadding: CGFloat(verticalPadding)
        ) {
            generatedThumbnail = thumbnail
            successMessage = "Thumbnail generated successfully!"
        } else {
            errorMessage = "Failed to generate thumbnail"
        }
    }
    
    /// Exports the generated thumbnail
    public func exportThumbnail() {
        guard let thumbnail = generatedThumbnail else {
            errorMessage = "No thumbnail to export"
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "podcast-thumbnail-ep\(episodeNumber).png"
        panel.message = "Save thumbnail"
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    let format: ThumbnailGenerator.ImageFormat = url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" ? .jpeg(quality: 0.9) : .png
                    
                    if self.generator.saveImage(thumbnail, to: url, format: format) {
                        self.successMessage = "Thumbnail saved successfully"
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Failed to save thumbnail"
                    }
                }
            }
        }
    }
    
    /// Clears all fields
    public func clear() {
        backgroundImage = nil
        overlayImage = nil
        episodeNumber = ""
        generatedThumbnail = nil
        errorMessage = nil
        successMessage = nil
    }
}
