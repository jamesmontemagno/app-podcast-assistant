import Foundation
import SwiftUI
import AppKit
import SwiftData

/// ViewModel for thumbnail generation functionality
/// Binds directly to SwiftData Episode model
@MainActor
public class ThumbnailViewModel: ObservableObject {
        @Published public var fontColor: Color = .white {
            didSet {
                episode.fontColorHex = fontColor.toHexString()
                saveContext()
                generateThumbnail()
            }
        }
        @Published public var outlineEnabled: Bool = true {
            didSet {
                episode.outlineEnabled = outlineEnabled
                saveContext()
                generateThumbnail()
            }
        }
        @Published public var outlineColor: Color = .black {
            didSet {
                episode.outlineColorHex = outlineColor.toHexString()
                saveContext()
                generateThumbnail()
            }
        }
    @Published public var episodeNumber: String = "" {
        didSet { generateThumbnail() }
    }
    @Published public var selectedFont: String = "Helvetica-Bold" {
        didSet { 
            episode.fontName = selectedFont
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var fontSize: Double = 72 {
        didSet { 
            episode.fontSize = fontSize
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var episodeNumberPosition: ThumbnailGenerator.TextPosition = .topRight {
        didSet { 
            episode.textPositionX = episodeNumberPosition.relativePosition.x
            episode.textPositionY = episodeNumberPosition.relativePosition.y
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var horizontalPadding: Double = 40 {
        didSet {
            episode.horizontalPadding = horizontalPadding
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var verticalPadding: Double = 40 {
        didSet {
            episode.verticalPadding = verticalPadding
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var selectedResolution: ThumbnailGenerator.CanvasResolution = .hd1080 {
        didSet {
            if selectedResolution != .custom {
                let size = selectedResolution.size
                episode.canvasWidth = size.width
                episode.canvasHeight = size.height
                saveContext()
                generateThumbnail()
            }
        }
    }
    @Published public var customWidth: String = "1920" {
        didSet {
            if selectedResolution == .custom, let width = Double(customWidth) {
                episode.canvasWidth = width
                saveContext()
                generateThumbnail()
            }
        }
    }
    @Published public var customHeight: String = "1080" {
        didSet {
            if selectedResolution == .custom, let height = Double(customHeight) {
                episode.canvasHeight = height
                saveContext()
                generateThumbnail()
            }
        }
    }
    @Published public var backgroundScaling: ThumbnailGenerator.BackgroundScaling = .aspectFill {
        didSet {
            episode.backgroundScaling = backgroundScaling.rawValue
            saveContext()
            generateThumbnail()
        }
    }
    @Published public var generatedThumbnail: NSImage?
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isLoading: Bool = false
    
    private let generator = ThumbnailGenerator()
    private let defaults = UserDefaults.standard
    private let customFontsKey = "ThumbnailCustomFonts"
    
    // SwiftData episode
    public let episode: Episode
    private let context: ModelContext
    
    // Computed properties for images from Core Data
    public var backgroundImage: NSImage? {
        get {
            guard let data = episode.thumbnailBackgroundData else { return nil }
            return ImageUtilities.loadImage(from: data)
        }
        set {
            if let image = newValue {
                episode.thumbnailBackgroundData = ImageUtilities.processImageForStorage(image)
            } else {
                episode.thumbnailBackgroundData = nil
            }
            saveContext()
            objectWillChange.send()
            generateThumbnail()
        }
    }
    
    public var overlayImage: NSImage? {
        get {
            guard let data = episode.thumbnailOverlayData else { return nil }
            return ImageUtilities.loadImage(from: data)
        }
        set {
            if let image = newValue {
                // Preserve transparency for overlay images (save as PNG instead of JPEG)
                episode.thumbnailOverlayData = ImageUtilities.processImageForStorage(image, preserveTransparency: true)
            } else {
                episode.thumbnailOverlayData = nil
            }
            saveContext()
            objectWillChange.send()
            generateThumbnail()
        }
    }
    
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
    
    public init(episode: Episode, context: ModelContext) {
                // Font color
                if let hex = episode.fontColorHex, let color = Color(hex: hex) {
                    self.fontColor = color
                }
                self.outlineEnabled = episode.outlineEnabled
                if let hex = episode.outlineColorHex, let color = Color(hex: hex) {
                    self.outlineColor = color
                }
        self.episode = episode
        self.context = context
        
        // Initialize episodeNumber from episode
        self.episodeNumber = "\(episode.episodeNumber)"
        
        // Initialize font settings from episode
        if let fontName = episode.fontName {
            self.selectedFont = fontName
        }
        self.fontSize = episode.fontSize
        
        // Initialize position from episode
        self.episodeNumberPosition = ThumbnailGenerator.TextPosition.fromRelativePosition(
            x: episode.textPositionX,
            y: episode.textPositionY
        )
        
        // Initialize padding from episode
        self.horizontalPadding = episode.horizontalPadding
        self.verticalPadding = episode.verticalPadding
        
        // Initialize canvas size from episode
        let canvasSize = NSSize(width: episode.canvasWidth, height: episode.canvasHeight)
        if canvasSize == ThumbnailGenerator.CanvasResolution.hd1080.size {
            self.selectedResolution = .hd1080
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.hd720.size {
            self.selectedResolution = .hd720
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.uhd4k.size {
            self.selectedResolution = .uhd4k
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.square1080.size {
            self.selectedResolution = .square1080
        } else {
            self.selectedResolution = .custom
            self.customWidth = "\(Int(episode.canvasWidth))"
            self.customHeight = "\(Int(episode.canvasHeight))"
        }
        
        // Initialize background scaling from episode
        self.backgroundScaling = ThumbnailGenerator.BackgroundScaling.allCases.first {
            $0.rawValue == episode.backgroundScaling
        } ?? .aspectFill
    }
    
    /// Performs initial thumbnail generation with a delay to allow UI to settle
    public func performInitialGeneration() {
        Task { @MainActor in
            // Give the UI time to load and render
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            self.generateThumbnail()
        }
    }
    
    /// Save the SwiftData context
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    /// Imports a background image
    public func importBackgroundImage() {
        selectImage { [weak self] image in
            self?.backgroundImage = image
            self?.successMessage = "Background image loaded"
            self?.errorMessage = nil
        }
    }
    
    /// Imports an overlay image
    public func importOverlayImage() {
        selectImage { [weak self] image in
            self?.overlayImage = image
            self?.successMessage = "Overlay image loaded"
            self?.errorMessage = nil
        }
    }
    
    /// Removes the overlay image
    public func removeOverlayImage() {
        overlayImage = nil
        successMessage = "Overlay removed"
        errorMessage = nil
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
    private func selectImage(completion: @escaping (NSImage?) -> Void) {
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
                        completion(nil)
                        return
                    }
                    defer {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    if let image = NSImage(contentsOf: url) {
                        completion(image)
                    } else {
                        self.errorMessage = "Failed to load image"
                        completion(nil)
                    }
                }
            }
        }
    }
    
    /// Generates the thumbnail
    public func generateThumbnail() {
        guard let background = backgroundImage else {
            generatedThumbnail = nil
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Determine canvas size
        let canvasSize: NSSize
        if selectedResolution == .custom {
            if let width = Double(customWidth), let height = Double(customHeight) {
                canvasSize = NSSize(width: width, height: height)
            } else {
                canvasSize = ThumbnailGenerator.CanvasResolution.hd1080.size
            }
        } else {
            canvasSize = selectedResolution.size
        }
        
        if let thumbnail = generator.generateThumbnail(
            backgroundImage: background,
            overlayImage: overlayImage,
            episodeNumber: episodeNumber,
            fontName: selectedFont,
            fontSize: CGFloat(fontSize),
            position: episodeNumberPosition,
            horizontalPadding: CGFloat(horizontalPadding),
            verticalPadding: CGFloat(verticalPadding),
            canvasSize: canvasSize,
            backgroundScaling: backgroundScaling,
            fontColor: NSColor(fontColor),
            outlineEnabled: outlineEnabled,
            outlineColor: NSColor(outlineColor)
        ) {
            generatedThumbnail = thumbnail
            
            // Save the generated thumbnail to Core Data (preserve transparency if overlay is used)
            let hasTransparency = overlayImage != nil
            episode.thumbnailOutputData = ImageUtilities.processImageForStorage(thumbnail, preserveTransparency: hasTransparency)
            saveContext()
            
            successMessage = "Thumbnail generated successfully!"
            isLoading = false
        } else {
            generatedThumbnail = nil
            errorMessage = "Failed to generate thumbnail"
            isLoading = false
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
        panel.canCreateDirectories = true
        
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
        episode.thumbnailBackgroundData = nil
        episode.thumbnailOverlayData = nil
        episode.thumbnailOutputData = nil
        saveContext()
        generatedThumbnail = nil
        errorMessage = nil
        successMessage = nil
        objectWillChange.send()
    }
}
