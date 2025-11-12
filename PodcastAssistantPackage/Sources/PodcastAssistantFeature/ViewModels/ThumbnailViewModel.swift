import Foundation
import SwiftUI
import SwiftData
import AppKit

/// ViewModel for thumbnail generation
@MainActor
public class ThumbnailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var fontColor: Color = .white {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var outlineEnabled: Bool = true {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var outlineColor: Color = .black {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var episodeNumber: String = "" {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var selectedFont: String = "Helvetica-Bold" {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var fontSize: Double = 72 {
        didSet { 
            scheduleGeneration() 
        }
    }
    @Published public var episodeNumberPosition: ThumbnailGenerator.TextPosition = .topRight {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var horizontalPadding: Double = 40 {
        didSet { 
            scheduleGeneration() 
        }
    }
    @Published public var verticalPadding: Double = 40 {
        didSet { 
            scheduleGeneration() 
        }
    }
    @Published public var selectedResolution: ThumbnailGenerator.CanvasResolution = .hd1080 {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var customWidth: String = "1920" {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var customHeight: String = "1080" {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var backgroundScaling: ThumbnailGenerator.BackgroundScaling = .aspectFill {
        didSet { 
            if !isRestoringState { pushUndoState() }
            scheduleGeneration() 
        }
    }
    @Published public var generatedThumbnail: NSImage?
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isLoading: Bool = false
    @Published public var backgroundImage: NSImage? = nil
    @Published public var overlayImage: NSImage? = nil
    @Published public var canUndo: Bool = false
    @Published public var availableFonts: [String] = []
    
    /// Tracks whether there are unsaved changes
    public var hasUnsavedChanges: Bool {
        // If we have more than 1 item in undo stack, we have unsaved changes
        return undoStack.count > 1
    }
    
    // MARK: - Undo/Redo State
    
    private struct StateSnapshot {
        let fontColor: Color
        let outlineEnabled: Bool
        let outlineColor: Color
        let episodeNumber: String
        let selectedFont: String
        let fontSize: Double
        let episodeNumberPosition: ThumbnailGenerator.TextPosition
        let horizontalPadding: Double
        let verticalPadding: Double
        let selectedResolution: ThumbnailGenerator.CanvasResolution
        let customWidth: String
        let customHeight: String
        let backgroundScaling: ThumbnailGenerator.BackgroundScaling
        let backgroundImage: NSImage?
        let overlayImage: NSImage?
    }
    
    private var undoStack: [StateSnapshot] = []
    private var isRestoringState = false
    
    // MARK: - Dependencies
    
    private let episode: Episode
    private let modelContext: ModelContext
    private let generator = ThumbnailGenerator()
    private let fontManager = FontManager()
    
    private var debounceTask: Task<Void, Never>?
    private var hasInitializedFromEpisode = false
    
    // MARK: - Initialization
    
    public init(episode: Episode, modelContext: ModelContext) {
        self.episode = episode
        self.modelContext = modelContext
        self.episodeNumber = "\(episode.episodeNumber)"
        
        // Load available fonts on initialization
        self.availableFonts = loadAvailableFonts()
    }
    
    // MARK: - Font Management
    
    /// Loads all available fonts including system fonts and custom imported fonts
    private func loadAvailableFonts() -> [String] {
        // Get all system fonts
        let allFonts = fontManager.getAllAvailableFonts()
        
        // Filter to commonly used bold/display fonts for better UX
        let preferredFonts = allFonts.filter { font in
            let lowercased = font.lowercased()
            return lowercased.contains("bold") || 
                   lowercased.contains("black") ||
                   lowercased.contains("heavy") ||
                   ["Impact", "Futura-Medium", "Didot"].contains(font)
        }
        
        // If we have preferred fonts, return those. Otherwise return all.
        return preferredFonts.isEmpty ? allFonts : preferredFonts.sorted()
    }
    
    /// Refresh the available fonts list (call this after importing new fonts)
    public func refreshAvailableFonts() {
        availableFonts = loadAvailableFonts()
    }
    
    // MARK: - Data Loading
    
    public func loadInitialData() {
        guard !hasInitializedFromEpisode else { return }
        hasInitializedFromEpisode = true
        
        isRestoringState = true // Prevent undo tracking during initial load
        
        // Refresh fonts list in case new fonts were imported
        refreshAvailableFonts()
        
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
            
            isRestoringState = false // Re-enable undo tracking
            captureInitialSnapshot() // Capture the initial state
            
            // Generate if we have background image but no output
            if backgroundImage != nil && generatedThumbnail == nil {
                try? await Task.sleep(nanoseconds: 300_000_000)
                generateThumbnail()
            }
        }
    }
    
    // MARK: - Undo/Redo Management
    
    private func captureInitialSnapshot() {
        let snapshot = StateSnapshot(
            fontColor: fontColor,
            outlineEnabled: outlineEnabled,
            outlineColor: outlineColor,
            episodeNumber: episodeNumber,
            selectedFont: selectedFont,
            fontSize: fontSize,
            episodeNumberPosition: episodeNumberPosition,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            selectedResolution: selectedResolution,
            customWidth: customWidth,
            customHeight: customHeight,
            backgroundScaling: backgroundScaling,
            backgroundImage: backgroundImage,
            overlayImage: overlayImage
        )
        undoStack = [snapshot] // Start with initial state
        canUndo = false
    }
    
    private func pushUndoState() {
        let snapshot = StateSnapshot(
            fontColor: fontColor,
            outlineEnabled: outlineEnabled,
            outlineColor: outlineColor,
            episodeNumber: episodeNumber,
            selectedFont: selectedFont,
            fontSize: fontSize,
            episodeNumberPosition: episodeNumberPosition,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            selectedResolution: selectedResolution,
            customWidth: customWidth,
            customHeight: customHeight,
            backgroundScaling: backgroundScaling,
            backgroundImage: backgroundImage,
            overlayImage: overlayImage
        )
        undoStack.append(snapshot)
        canUndo = undoStack.count > 1
    }
    
    public func undo() {
        guard undoStack.count > 1 else { return }
        
        // Remove current state
        undoStack.removeLast()
        
        // Restore previous state
        if let previousState = undoStack.last {
            isRestoringState = true
            
            fontColor = previousState.fontColor
            outlineEnabled = previousState.outlineEnabled
            outlineColor = previousState.outlineColor
            episodeNumber = previousState.episodeNumber
            selectedFont = previousState.selectedFont
            fontSize = previousState.fontSize
            episodeNumberPosition = previousState.episodeNumberPosition
            horizontalPadding = previousState.horizontalPadding
            verticalPadding = previousState.verticalPadding
            selectedResolution = previousState.selectedResolution
            customWidth = previousState.customWidth
            customHeight = previousState.customHeight
            backgroundScaling = previousState.backgroundScaling
            backgroundImage = previousState.backgroundImage
            overlayImage = previousState.overlayImage
            
            isRestoringState = false
            canUndo = undoStack.count > 1
            
            generateThumbnail()
        }
    }
    
    /// Called when slider editing ends to push undo state
    public func onSliderEditingEnded() {
        if !isRestoringState {
            pushUndoState()
        }
    }
    
    private func clearUndoStack() {
        captureInitialSnapshot()
    }
    
    // MARK: - Image Import/Paste
    
    public func importBackgroundImage() {
        selectImage { [weak self] image in
            guard let self = self else { return }
            if !self.isRestoringState { self.pushUndoState() }
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
            if !self.isRestoringState { self.pushUndoState() }
            self.overlayImage = image
            if image != nil {
                self.successMessage = "Overlay image loaded"
                self.errorMessage = nil
                self.generateThumbnail()
            }
        }
    }
    
    public func removeOverlayImage() {
        if !isRestoringState { pushUndoState() }
        overlayImage = nil
        successMessage = "Overlay removed"
        errorMessage = nil
        generateThumbnail()
    }
    
    public func pasteBackgroundFromClipboard() {
        if let image = getImageFromClipboard() {
            if !isRestoringState { pushUndoState() }
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
            if !isRestoringState { pushUndoState() }
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
                    try self.modelContext.save()
                    self.successMessage = "Thumbnail saved to episode"
                    self.errorMessage = nil
                    self.clearUndoStack() // Clear undo history after successful save
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
        
        isRestoringState = true
        
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
        
        isRestoringState = false
        
        // Clear messages
        errorMessage = nil
        successMessage = "Settings reset to defaults"
        
        // Clear initialization flag and undo stack
        hasInitializedFromEpisode = false
        clearUndoStack()
    }
}
