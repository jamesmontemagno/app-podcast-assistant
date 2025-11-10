import Foundation
import SwiftUI
import AppKit

/// ViewModel for thumbnail generation
@MainActor
public class ThumbnailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var fontColor: Color = .white {
        didSet { scheduleGeneration() }
    }
    @Published public var outlineEnabled: Bool = true {
        didSet { scheduleGeneration() }
    }
    @Published public var outlineColor: Color = .black {
        didSet { scheduleGeneration() }
    }
    @Published public var episodeNumber: String = "" {
        didSet { scheduleGeneration() }
    }
    @Published public var selectedFont: String = "Helvetica-Bold" {
        didSet { scheduleGeneration() }
    }
    @Published public var fontSize: Double = 72 {
        didSet { scheduleGeneration() }
    }
    @Published public var episodeNumberPosition: ThumbnailGenerator.TextPosition = .topRight {
        didSet { scheduleGeneration() }
    }
    @Published public var horizontalPadding: Double = 40 {
        didSet { scheduleGeneration() }
    }
    @Published public var verticalPadding: Double = 40 {
        didSet { scheduleGeneration() }
    }
    @Published public var selectedResolution: ThumbnailGenerator.CanvasResolution = .hd1080 {
        didSet { scheduleGeneration() }
    }
    @Published public var customWidth: String = "1920" {
        didSet { scheduleGeneration() }
    }
    @Published public var customHeight: String = "1080" {
        didSet { scheduleGeneration() }
    }
    @Published public var backgroundScaling: ThumbnailGenerator.BackgroundScaling = .aspectFill {
        didSet { scheduleGeneration() }
    }
    @Published public var generatedThumbnail: NSImage?
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isLoading: Bool = false
    @Published public var backgroundImage: NSImage? = nil
    @Published public var overlayImage: NSImage? = nil
    
    // MARK: - Dependencies
    
    private let episode: EpisodePOCO
    private let store: PodcastLibraryStore
    private let generator = ThumbnailGenerator()
    private let fontManager = FontManager()
    
    private var debounceTask: Task<Void, Never>?
    private var hasInitializedFromEpisode = false
    
    public var availableFonts: [String] {
        [
            "Helvetica-Bold",
            "Arial-BoldMT",
            "Futura-Bold",
            "Impact",
            "Menlo-Bold",
            "AvenirNext-Bold",
            "GillSans-Bold"
        ].sorted()
    }
    
    // MARK: - Initialization
    
    public init(episode: EpisodePOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.store = store
        self.episodeNumber = "\(episode.episodeNumber)"
    }
    
    // MARK: - Data Loading
    
    public func loadInitialData() {
        guard !hasInitializedFromEpisode else { return }
        hasInitializedFromEpisode = true
        
        Task { @MainActor in
            // Load saved settings from episode
            if let hex = episode.fontColorHex, let color = Color(hex: hex) {
                fontColor = color
            }
            outlineEnabled = episode.outlineEnabled
            if let hex = episode.outlineColorHex, let color = Color(hex: hex) {
                outlineColor = color
            }
            
            if let fontName = episode.fontName {
                selectedFont = fontName
            }
            fontSize = episode.fontSize
            
            episodeNumberPosition = ThumbnailGenerator.TextPosition.fromRelativePosition(
                x: episode.textPositionX,
                y: episode.textPositionY
            )
            
            horizontalPadding = episode.horizontalPadding
            verticalPadding = episode.verticalPadding
            
            // Load canvas size
            let canvasSize = NSSize(width: episode.canvasWidth, height: episode.canvasHeight)
            if canvasSize == ThumbnailGenerator.CanvasResolution.hd1080.size {
                selectedResolution = .hd1080
            } else if canvasSize == ThumbnailGenerator.CanvasResolution.hd720.size {
                selectedResolution = .hd720
            } else if canvasSize == ThumbnailGenerator.CanvasResolution.uhd4k.size {
                selectedResolution = .uhd4k
            } else if canvasSize == ThumbnailGenerator.CanvasResolution.square1080.size {
                selectedResolution = .square1080
            } else {
                selectedResolution = .custom
                customWidth = "\(Int(episode.canvasWidth))"
                customHeight = "\(Int(episode.canvasHeight))"
            }
            
            backgroundScaling = ThumbnailGenerator.BackgroundScaling.allCases.first {
                $0.rawValue == episode.backgroundScaling
            } ?? .aspectFill
            
            // Load images
            if let bgData = episode.thumbnailBackgroundData {
                backgroundImage = ImageUtilities.loadImage(from: bgData)
            }
            
            if let overlayData = episode.thumbnailOverlayData {
                overlayImage = ImageUtilities.loadImage(from: overlayData)
            }
            
            if let outputData = episode.thumbnailOutputData {
                generatedThumbnail = ImageUtilities.loadImage(from: outputData)
            }
            
            // Generate if we have background image but no output
            if backgroundImage != nil && generatedThumbnail == nil {
                try? await Task.sleep(nanoseconds: 300_000_000)
                generateThumbnail()
            }
        }
    }
    
    // MARK: - Image Import/Paste
    
    public func importBackgroundImage() {
        selectImage { [weak self] image in
            guard let self = self else { return }
            self.backgroundImage = image
            if image != nil {
                self.successMessage = "Background image loaded"
                self.errorMessage = nil
                self.generateThumbnail()
            }
        }
    }
    
    public func importOverlayImage() {
        selectImage { [weak self] image in
            guard let self = self else { return }
            self.overlayImage = image
            if image != nil {
                self.successMessage = "Overlay image loaded"
                self.errorMessage = nil
                self.generateThumbnail()
            }
        }
    }
    
    public func removeOverlayImage() {
        overlayImage = nil
        successMessage = "Overlay removed"
        errorMessage = nil
        generateThumbnail()
    }
    
    public func pasteBackgroundFromClipboard() {
        if let image = getImageFromClipboard() {
            backgroundImage = image
            successMessage = "Background pasted from clipboard"
            errorMessage = nil
            generateThumbnail()
        } else {
            errorMessage = "No image found in clipboard"
        }
    }
    
    public func pasteOverlayFromClipboard() {
        if let image = getImageFromClipboard() {
            overlayImage = image
            successMessage = "Overlay pasted from clipboard"
            errorMessage = nil
            generateThumbnail()
        } else {
            errorMessage = "No image found in clipboard"
        }
    }
    
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
    
    // MARK: - Thumbnail Generation
    
    private func scheduleGeneration() {
        guard hasInitializedFromEpisode else { return }
        
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            self?.generateThumbnail()
        }
    }
    
    public func generateThumbnail() {
        guard let background = backgroundImage else {
            generatedThumbnail = nil
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let canvasSize = determineCanvasSize()
        let fontColorNS = NSColor(fontColor)
        let outlineColorNS = NSColor(outlineColor)
        let outlineEnabledValue = outlineEnabled
        let fontSizeValue = fontSize
        let selectedFontValue = selectedFont
        let episodeNumberValue = episodeNumber
        let positionValue = episodeNumberPosition
        let horizontalPaddingValue = horizontalPadding
        let verticalPaddingValue = verticalPadding
        let backgroundScalingValue = backgroundScaling
        let overlayValue = overlayImage
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            let image = await Task.detached(priority: .userInitiated) {
                let generator = ThumbnailGenerator()
                
                return generator.generateThumbnail(
                    backgroundImage: background,
                    overlayImage: overlayValue,
                    episodeNumber: episodeNumberValue,
                    fontName: selectedFontValue,
                    fontSize: CGFloat(fontSizeValue),
                    position: positionValue,
                    horizontalPadding: CGFloat(horizontalPaddingValue),
                    verticalPadding: CGFloat(verticalPaddingValue),
                    canvasSize: canvasSize,
                    backgroundScaling: backgroundScalingValue,
                    fontColor: fontColorNS,
                    outlineEnabled: outlineEnabledValue,
                    outlineColor: outlineColorNS
                )
            }.value
            
            self.isLoading = false
            if let image = image {
                self.generatedThumbnail = image
                self.successMessage = "Thumbnail generated successfully!"
            } else {
                self.generatedThumbnail = nil
                self.errorMessage = "Failed to generate thumbnail"
            }
        }
    }
    
    private func determineCanvasSize() -> NSSize {
        if selectedResolution == .custom {
            if let width = Double(customWidth), let height = Double(customHeight) {
                return NSSize(width: width, height: height)
            }
            return ThumbnailGenerator.CanvasResolution.hd1080.size
        }
        return selectedResolution.size
    }
    
    // MARK: - Save & Export
    
    public func saveToEpisode() {
        guard let thumbnail = generatedThumbnail else {
            errorMessage = "No thumbnail to save"
            return
        }
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let preserveTransparency = await self.overlayImage != nil
            let bgImage = await self.backgroundImage
            let ovImage = await self.overlayImage
            
            let thumbnailData = ImageUtilities.processImageForStorage(thumbnail, preserveTransparency: preserveTransparency)
            let backgroundData = bgImage.map { ImageUtilities.processImageForStorage($0) }
            let overlayData = ovImage.map { ImageUtilities.processImageForStorage($0, preserveTransparency: true) }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                // Update episode POCO
                self.episode.thumbnailOutputData = thumbnailData
                if let bgData = backgroundData {
                    self.episode.thumbnailBackgroundData = bgData
                }
                if let ovData = overlayData {
                    self.episode.thumbnailOverlayData = ovData
                }
                
                // Save settings
                self.episode.fontColorHex = self.fontColor.toHexString()
                self.episode.outlineEnabled = self.outlineEnabled
                self.episode.outlineColorHex = self.outlineColor.toHexString()
                self.episode.fontName = self.selectedFont
                self.episode.fontSize = self.fontSize
                self.episode.textPositionX = self.episodeNumberPosition.relativePosition.x
                self.episode.textPositionY = self.episodeNumberPosition.relativePosition.y
                self.episode.horizontalPadding = self.horizontalPadding
                self.episode.verticalPadding = self.verticalPadding
                
                if self.selectedResolution != .custom {
                    let size = self.selectedResolution.size
                    self.episode.canvasWidth = size.width
                    self.episode.canvasHeight = size.height
                } else {
                    if let width = Double(self.customWidth) {
                        self.episode.canvasWidth = width
                    }
                    if let height = Double(self.customHeight) {
                        self.episode.canvasHeight = height
                    }
                }
                
                self.episode.backgroundScaling = self.backgroundScaling.rawValue
                
                do {
                    try self.store.updateEpisode(self.episode)
                    self.successMessage = "Thumbnail saved to episode"
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Failed to save: \(error.localizedDescription)"
                }
            }
        }
    }
    
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
                        self.successMessage = "Thumbnail exported successfully"
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = "Failed to export thumbnail"
                    }
                }
            }
        }
    }
    
    /// Resets all settings and images to default state
    public func resetAll() {
        // Cancel any pending debounce tasks
        debounceTask?.cancel()
        debounceTask = nil
        
        // Reset images
        backgroundImage = nil
        overlayImage = nil
        generatedThumbnail = nil
        
        // Reset to default settings
        fontColor = .white
        outlineEnabled = true
        outlineColor = .black
        selectedFont = "Helvetica-Bold"
        fontSize = 72
        episodeNumberPosition = .topRight
        horizontalPadding = 40
        verticalPadding = 40
        selectedResolution = .hd1080
        customWidth = "1920"
        customHeight = "1080"
        backgroundScaling = .aspectFill
        
        // Reset episode number to current episode
        episodeNumber = "\(episode.episodeNumber)"
        
        // Clear messages
        errorMessage = nil
        successMessage = "Settings reset to defaults"
        
        // Clear initialization flag so loadInitialData can run again if needed
        hasInitializedFromEpisode = false
    }
}
