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
            markDirty()
        }
    }
    @Published public var outlineEnabled: Bool = true {
        didSet {
            markDirty()
        }
    }
    @Published public var outlineColor: Color = .black {
        didSet {
            markDirty()
        }
    }
    @Published public var episodeNumber: String = "" {
        didSet {
            markDirty()
        }
    }
    @Published public var selectedFont: String = "Helvetica-Bold" {
        didSet {
            markDirty()
        }
    }
    @Published public var fontSize: Double = 72 {
        didSet {
            markDirty()
        }
    }
    @Published public var episodeNumberPosition: ThumbnailGenerator.TextPosition = .topRight {
        didSet {
            markDirty()
        }
    }
    @Published public var horizontalPadding: Double = 40 {
        didSet {
            markDirty()
        }
    }
    @Published public var verticalPadding: Double = 40 {
        didSet {
            markDirty()
        }
    }
    @Published public var selectedResolution: ThumbnailGenerator.CanvasResolution = .hd1080 {
        didSet {
            markDirty()
        }
    }
    @Published public var customWidth: String = "1920" {
        didSet {
            markDirty()
        }
    }
    @Published public var customHeight: String = "1080" {
        didSet {
            markDirty()
        }
    }
    @Published public var backgroundScaling: ThumbnailGenerator.BackgroundScaling = .aspectFill {
        didSet {
            markDirty()
        }
    }
    @Published public var generatedThumbnail: NSImage?
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var isLoading: Bool = false
    
    // Cached images - loaded lazily to prevent blocking on init
    @Published public var backgroundImage: NSImage? = nil
    @Published public var overlayImage: NSImage? = nil
    
    // Dirty state tracking
    @Published public var hasUnsavedChanges: Bool = false
    
    private let generator = ThumbnailGenerator()
    private let fontManager: FontManager
    private var hasLoadedImages = false
    
    // SwiftData episode
    public let episode: Episode
    private let context: ModelContext
    private var appSettings: AppSettings?
    
    // Debouncing for thumbnail generation only (no auto-save)
    private var debounceTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var currentGenerationID = UUID()
    
    // Cache last generation parameters to avoid redundant work
    private var lastGenerationHash: Int = 0
    
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
        
        // Add imported fonts from AppSettings
        if let settings = appSettings {
            fonts.append(contentsOf: settings.importedFonts)
        }
        
        return fonts.sorted()
    }
    
    public init(episode: Episode, context: ModelContext, fontManager: FontManager = FontManager()) {
        self.episode = episode
        self.context = context
        self.fontManager = fontManager
        
        // Font color
        if let hex = episode.fontColorHex, let color = Color(hex: hex) {
            self.fontColor = color
        }
        self.outlineEnabled = episode.outlineEnabled
        if let hex = episode.outlineColorHex, let color = Color(hex: hex) {
            self.outlineColor = color
        }
        
        // Load AppSettings
        loadSettings()
        
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
    
    deinit {
        // Cancel any pending tasks when view model is deallocated
        debounceTask?.cancel()
        renderTask?.cancel()
    }
    
    /// Mark that there are unsaved changes
    private func markDirty() {
        hasUnsavedChanges = true
    }
    
    /// Loads images from SwiftData asynchronously (called once on view appear)
    private func loadImagesIfNeeded() async {
        guard !hasLoadedImages else { return }
        hasLoadedImages = true
        
        // Load images off main thread to prevent UI blocking
        let bgData = episode.thumbnailBackgroundData
        let overlayData = episode.thumbnailOverlayData
        
        await Task.detached {
            let bgImage = bgData.flatMap { ImageUtilities.loadImage(from: $0) }
            let ovImage = overlayData.flatMap { ImageUtilities.loadImage(from: $0) }
            
            await MainActor.run {
                self.backgroundImage = bgImage
                self.overlayImage = ovImage
            }
        }.value
    }
    
    /// Performs initial thumbnail generation with a delay to allow UI to settle
    public func performInitialGeneration() {
        Task { @MainActor in
            // Load images from SwiftData first (off main thread)
            await loadImagesIfNeeded()
            
            // Give the UI time to load and render
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            self.requestGeneration(force: true, showSuccessFeedback: false)
        }
    }
    
    /// Schedule a debounced thumbnail generation (800ms delay to wait for user to finish adjusting)
    private func scheduleDebouncedGeneration() {
        // Cancel any existing debounce task
        debounceTask?.cancel()
        renderTask?.cancel()
        
        // Create a new task that waits before generating
        debounceTask = Task { @MainActor [weak self] in
            // Wait for 800ms - if another change happens, this task gets cancelled
            try? await Task.sleep(nanoseconds: 800_000_000)

            // Check if we were cancelled
            guard !Task.isCancelled else { return }

            guard let viewModel = self else { return }
            // Generate the thumbnail (with caching to skip redundant work)
            viewModel.generateThumbnailIfNeeded()
        }
    }
    
    /// Save changes to SwiftData
    public func saveChanges() {
        let thumbnailWrapper = generatedThumbnail.map { ImageBox(image: $0) }
        let hadThumbnail = thumbnailWrapper != nil
        let preserveTransparency = overlayImage != nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let processedData = thumbnailWrapper.flatMap { box in
                ImageUtilities.processImageForStorage(box.image, preserveTransparency: preserveTransparency)
            }

            await MainActor.run { [weak self] in
                self?.applySaveResult(processedData: processedData, hadThumbnail: hadThumbnail)
            }
        }
    }

    @MainActor
    private func applySaveResult(processedData: Data?, hadThumbnail: Bool) {
        if hadThumbnail && processedData == nil {
            errorMessage = "Failed to prepare thumbnail for saving"
            successMessage = nil
            return
        }

        // Update all episode properties from current ViewModel state
        episode.fontColorHex = fontColor.toHexString()
        episode.outlineEnabled = outlineEnabled
        episode.outlineColorHex = outlineColor.toHexString()
        episode.fontName = selectedFont
        episode.fontSize = fontSize
        episode.textPositionX = episodeNumberPosition.relativePosition.x
        episode.textPositionY = episodeNumberPosition.relativePosition.y
        episode.horizontalPadding = horizontalPadding
        episode.verticalPadding = verticalPadding
        
        // Update canvas size
        if selectedResolution != .custom {
            let size = selectedResolution.size
            episode.canvasWidth = size.width
            episode.canvasHeight = size.height
        } else {
            if let width = Double(customWidth) {
                episode.canvasWidth = width
            }
            if let height = Double(customHeight) {
                episode.canvasHeight = height
            }
        }
        
        episode.backgroundScaling = backgroundScaling.rawValue
        
        // Save background image if changed
        if let bgImage = backgroundImage {
            episode.thumbnailBackgroundData = ImageUtilities.processImageForStorage(bgImage)
        }
        
        // Save overlay image if changed
        if let ovImage = overlayImage {
            episode.thumbnailOverlayData = ImageUtilities.processImageForStorage(ovImage, preserveTransparency: true)
        } else {
            episode.thumbnailOverlayData = nil
        }

        if let data = processedData {
            episode.thumbnailOutputData = data
        }

        do {
            if context.hasChanges {
                try context.save()
            }
            hasUnsavedChanges = false
            successMessage = "Changes saved successfully"
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }
    
    /// Discard unsaved changes
    public func discardChanges() {
        context.rollback()
        hasUnsavedChanges = false
        // Reload values from episode
        reloadFromEpisode()
    }
    
    /// Reload all values from the episode model
    private func reloadFromEpisode() {
        episodeNumber = "\(episode.episodeNumber)"
        selectedFont = episode.fontName ?? "Helvetica-Bold"
        fontSize = episode.fontSize
        horizontalPadding = episode.horizontalPadding
        verticalPadding = episode.verticalPadding
        
        if let hex = episode.fontColorHex, let color = Color(hex: hex) {
            fontColor = color
        }
        outlineEnabled = episode.outlineEnabled
        if let hex = episode.outlineColorHex, let color = Color(hex: hex) {
            outlineColor = color
        }
        
        episodeNumberPosition = ThumbnailGenerator.TextPosition.fromRelativePosition(
            x: episode.textPositionX,
            y: episode.textPositionY
        )
        
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
        
        requestGeneration(force: true, showSuccessFeedback: false)
    }
    
    /// Imports a background image
    public func importBackgroundImage() {
        selectImage { [weak self] image in
            guard let self = self else { return }
            self.backgroundImage = image
            if image != nil {
                self.markDirty()
            }
            self.successMessage = "Background image loaded"
            self.errorMessage = nil
            // Immediate generation for image imports
            self.debounceTask?.cancel()
            self.generateThumbnail()
        }
    }
    
    /// Imports an overlay image
    public func importOverlayImage() {
        selectImage { [weak self] image in
            guard let self = self else { return }
            self.overlayImage = image
            if image != nil {
                self.markDirty()
            }
            self.successMessage = "Overlay image loaded"
            self.errorMessage = nil
            // Immediate generation for image imports
            self.debounceTask?.cancel()
            self.generateThumbnail()
        }
    }
    
    /// Removes the overlay image
    public func removeOverlayImage() {
        overlayImage = nil
        markDirty()
        successMessage = "Overlay removed"
        errorMessage = nil
        // Immediate generation for removals
        debounceTask?.cancel()
        generateThumbnail()
    }
    
    /// Pastes image from clipboard for background
    public func pasteBackgroundFromClipboard() {
        if let image = getImageFromClipboard() {
            backgroundImage = image
            markDirty()
            successMessage = "Background pasted from clipboard"
            errorMessage = nil
            // Immediate generation for image pastes
            debounceTask?.cancel()
            generateThumbnail()
        } else {
            errorMessage = "No image found in clipboard"
        }
    }
    
    /// Pastes image from clipboard for overlay
    public func pasteOverlayFromClipboard() {
        if let image = getImageFromClipboard() {
            overlayImage = image
            markDirty()
            successMessage = "Overlay pasted from clipboard"
            errorMessage = nil
            // Immediate generation for image pastes
            debounceTask?.cancel()
            generateThumbnail()
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
    
    /// Load or create AppSettings
    private func loadSettings() {
        let descriptor = FetchDescriptor<AppSettings>()
        
        do {
            let allSettings = try context.fetch(descriptor)
            
            if let existingSettings = allSettings.first {
                appSettings = existingSettings
            } else {
                // Create new settings
                let newSettings = AppSettings()
                context.insert(newSettings)
                try context.save()
                appSettings = newSettings
            }
        } catch {
            print("Error loading settings: \(error)")
            // Create fallback settings
            let newSettings = AppSettings()
            context.insert(newSettings)
            appSettings = newSettings
        }
    }
    
    /// Registers a custom font and saves it to global AppSettings
    private func registerCustomFont(from url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Failed to access font file: Permission denied"
            return
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let fontName = try fontManager.importFont(from: url)
            
            // Add to AppSettings imported fonts list if not already present
            guard let settings = appSettings else {
                errorMessage = "Settings not available"
                return
            }
            
            if !settings.importedFonts.contains(fontName) {
                settings.importedFonts.append(fontName)
                settings.importedFonts.sort()
                settings.updatedAt = Date()
                try context.save()
            }
            
            let displayName = fontManager.getDisplayName(for: fontName)
            selectedFont = fontName
            successMessage = "Font '\(displayName)' loaded and added to global fonts"
            errorMessage = nil
            objectWillChange.send() // Refresh available fonts list
        } catch {
            errorMessage = "Failed to load font: \(error.localizedDescription)"
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
    
    /// Generates the thumbnail with caching to avoid redundant work
    private func generateThumbnailIfNeeded() {
        requestGeneration(force: false, showSuccessFeedback: false)
    }
    
    /// Calculate hash of current generation parameters to detect changes
    private func calculateGenerationHash() -> Int {
        var hasher = Hasher()
        hasher.combine(episodeNumber)
        hasher.combine(selectedFont)
        hasher.combine(fontSize)
        hasher.combine(episodeNumberPosition.rawValue)
        hasher.combine(horizontalPadding)
        hasher.combine(verticalPadding)
        hasher.combine(selectedResolution.rawValue)
        hasher.combine(customWidth)
        hasher.combine(customHeight)
        hasher.combine(backgroundScaling.rawValue)
        hasher.combine(fontColor.description)
        hasher.combine(outlineEnabled)
        hasher.combine(outlineColor.description)
        // Note: We don't hash images as they're expensive to compare
        return hasher.finalize()
    }
    
    /// Generates the thumbnail on demand (used by toolbar button)
    public func generateThumbnail() {
        markDirty()
        requestGeneration(force: true, showSuccessFeedback: true)
    }

    private func requestGeneration(force: Bool, showSuccessFeedback: Bool) {
        guard let snapshot = makeSnapshot() else {
            renderTask?.cancel()
            currentGenerationID = UUID()
            generatedThumbnail = nil
            isLoading = false
            return
        }

        let currentHash = calculateGenerationHash()
        if !force && currentHash == lastGenerationHash {
            return
        }
        lastGenerationHash = currentHash

        startRender(with: snapshot, showSuccessFeedback: showSuccessFeedback)
    }

    private func makeSnapshot() -> ThumbnailRenderSnapshot? {
        guard let background = backgroundImage else {
            return nil
        }

        return ThumbnailRenderSnapshot(
            backgroundImage: background,
            overlayImage: overlayImage,
            episodeNumber: episodeNumber,
            fontName: selectedFont,
            fontSize: CGFloat(fontSize),
            position: episodeNumberPosition,
            horizontalPadding: CGFloat(horizontalPadding),
            verticalPadding: CGFloat(verticalPadding),
            canvasSize: determineCanvasSize(),
            backgroundScaling: backgroundScaling,
            fontColor: NSColor(fontColor),
            outlineEnabled: outlineEnabled,
            outlineColor: NSColor(outlineColor)
        )
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

    private func startRender(with snapshot: ThumbnailRenderSnapshot, showSuccessFeedback: Bool) {
        renderTask?.cancel()
        let generationID = UUID()
        currentGenerationID = generationID
        isLoading = true
        errorMessage = nil

        renderTask = Task.detached(priority: .userInitiated) { [weak self, snapshot, showSuccessFeedback, generationID] in
            if Task.isCancelled { return }

            let image: NSImage? = autoreleasepool {
                ThumbnailGenerator().generateThumbnail(
                    backgroundImage: snapshot.backgroundImage,
                    overlayImage: snapshot.overlayImage,
                    episodeNumber: snapshot.episodeNumber,
                    fontName: snapshot.fontName,
                    fontSize: snapshot.fontSize,
                    position: snapshot.position,
                    horizontalPadding: snapshot.horizontalPadding,
                    verticalPadding: snapshot.verticalPadding,
                    canvasSize: snapshot.canvasSize,
                    backgroundScaling: snapshot.backgroundScaling,
                    fontColor: snapshot.fontColor,
                    outlineEnabled: snapshot.outlineEnabled,
                    outlineColor: snapshot.outlineColor
                )
            }

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard
                    let strongSelf = self,
                    strongSelf.currentGenerationID == generationID
                else { return }
                strongSelf.isLoading = false
                strongSelf.renderTask = nil

                if let image = image {
                    strongSelf.generatedThumbnail = image
                    if showSuccessFeedback {
                        strongSelf.successMessage = "Thumbnail generated successfully!"
                    }
                } else {
                    strongSelf.generatedThumbnail = nil
                    strongSelf.errorMessage = "Failed to generate thumbnail"
                    strongSelf.successMessage = nil
                }
            }
        }
    }

    private struct ThumbnailRenderSnapshot: @unchecked Sendable {
        let backgroundImage: NSImage
        let overlayImage: NSImage?
        let episodeNumber: String
        let fontName: String
        let fontSize: CGFloat
        let position: ThumbnailGenerator.TextPosition
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let canvasSize: NSSize
        let backgroundScaling: ThumbnailGenerator.BackgroundScaling
        let fontColor: NSColor
        let outlineEnabled: Bool
        let outlineColor: NSColor
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
        backgroundImage = nil
        overlayImage = nil
        generatedThumbnail = nil
        episode.thumbnailBackgroundData = nil
        episode.thumbnailOverlayData = nil
        episode.thumbnailOutputData = nil
        markDirty()
        errorMessage = nil
        successMessage = nil
        debounceTask?.cancel()
        renderTask?.cancel()
        currentGenerationID = UUID()
        lastGenerationHash = 0
        isLoading = false
    }
    
    private struct ImageBox: @unchecked Sendable {
        let image: NSImage
    }
}
