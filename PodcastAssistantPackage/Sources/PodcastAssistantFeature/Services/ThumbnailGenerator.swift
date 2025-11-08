import AppKit
import CoreGraphics
import CoreText

/// Service responsible for generating podcast thumbnails
public class ThumbnailGenerator {
    
    /// Canvas resolution presets
    public enum CanvasResolution: String, CaseIterable, Identifiable {
        case hd1080 = "1920×1080 (Full HD)"
        case hd720 = "1280×720 (HD)"
        case uhd4k = "3840×2160 (4K)"
        case square1080 = "1080×1080 (Square)"
        case custom = "Custom"
        
        public var id: String { rawValue }
        
        public var size: NSSize {
            switch self {
            case .hd1080: return NSSize(width: 1920, height: 1080)
            case .hd720: return NSSize(width: 1280, height: 720)
            case .uhd4k: return NSSize(width: 3840, height: 2160)
            case .square1080: return NSSize(width: 1080, height: 1080)
            case .custom: return NSSize(width: 1920, height: 1080) // Default for custom
            }
        }
    }
    
    /// Background image scaling mode
    public enum BackgroundScaling: String, CaseIterable, Identifiable {
        case fill = "Fill (Stretch)"
        case fit = "Fit (Letterbox)"
        case aspectFill = "Aspect Fill (Crop)"
        
        public var id: String { rawValue }
    }
    
    /// Text position options for episode number
    public enum TextPosition: String, CaseIterable, Identifiable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case topCenter = "Top Center"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case bottomCenter = "Bottom Center"
        case center = "Center"
        
        public var id: String { rawValue }
        
        /// Converts the position to relative coordinates (0.0 to 1.0)
        public var relativePosition: (x: Double, y: Double) {
            switch self {
            case .topLeft: return (0.0, 0.0)
            case .topRight: return (1.0, 0.0)
            case .topCenter: return (0.5, 0.0)
            case .bottomLeft: return (0.0, 1.0)
            case .bottomRight: return (1.0, 1.0)
            case .bottomCenter: return (0.5, 1.0)
            case .center: return (0.5, 0.5)
            }
        }
        
        /// Creates a TextPosition from relative coordinates
        public static func fromRelativePosition(x: Double, y: Double) -> TextPosition {
            // Match to closest position
            let epsilon = 0.1
            if abs(y - 0.0) < epsilon {
                if abs(x - 0.0) < epsilon { return .topLeft }
                if abs(x - 1.0) < epsilon { return .topRight }
                if abs(x - 0.5) < epsilon { return .topCenter }
            } else if abs(y - 1.0) < epsilon {
                if abs(x - 0.0) < epsilon { return .bottomLeft }
                if abs(x - 1.0) < epsilon { return .bottomRight }
                if abs(x - 0.5) < epsilon { return .bottomCenter }
            } else if abs(y - 0.5) < epsilon && abs(x - 0.5) < epsilon {
                return .center
            }
            // Default to topRight if no close match
            return .topRight
        }
    }
    
    public init() {}
    
    /// Generates a thumbnail by overlaying an episode number on a background image
    /// - Parameters:
    ///   - backgroundImage: The main background image
    ///   - overlayImage: Optional overlay image (e.g., podcast branding)
    ///   - episodeNumber: The episode number to display
    ///   - fontName: The font to use for the episode number
    ///   - fontSize: The size of the font
    ///   - position: The position where the episode number should appear
    ///   - horizontalPadding: Padding from left/right edges
    ///   - verticalPadding: Padding from top/bottom edges
    ///   - canvasSize: The output canvas size (defaults to 1920x1080)
    ///   - backgroundScaling: How to scale the background image to fit the canvas
    /// - Returns: The generated thumbnail image
    public func generateThumbnail(
        backgroundImage: NSImage,
        overlayImage: NSImage?,
        episodeNumber: String,
        fontName: String = "Helvetica-Bold",
        fontSize: CGFloat = 72,
        position: TextPosition = .topRight,
        horizontalPadding: CGFloat = 40,
        verticalPadding: CGFloat = 40,
        canvasSize: NSSize = NSSize(width: 1920, height: 1080),
        backgroundScaling: BackgroundScaling = .aspectFill,
        fontColor: NSColor = .white,
        outlineEnabled: Bool = true,
        outlineColor: NSColor = .black
    ) -> NSImage? {
        
        // Use canvas size instead of background image size
        let size = canvasSize
        
        // Create a new image context
        guard let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: imageRep) else {
            return nil
        }
        NSGraphicsContext.current = context
        
        // Calculate background image rect based on scaling mode
        let backgroundRect = calculateBackgroundRect(
            imageSize: backgroundImage.size,
            canvasSize: size,
            scaling: backgroundScaling
        )
        
        // Draw background image with chosen scaling
        backgroundImage.draw(
            in: backgroundRect,
            from: NSRect(origin: .zero, size: backgroundImage.size),
            operation: .copy,
            fraction: 1.0
        )
        
        // Draw overlay image if provided (always aspect fill)
        if let overlayImage = overlayImage {
            let overlayRect = calculateBackgroundRect(
                imageSize: overlayImage.size,
                canvasSize: size,
                scaling: .aspectFill
            )
            
            // Ensure we're drawing with alpha blending
            overlayImage.draw(
                in: overlayRect,
                from: NSRect(origin: .zero, size: overlayImage.size),
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: false,
                hints: [.interpolation: NSNumber(value: NSImageInterpolation.high.rawValue)]
            )
        }
        
        // Draw episode number at specified position if provided
        if !episodeNumber.isEmpty {
            let font = NSFont(name: fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
            let paragraphStyle = NSMutableParagraphStyle()
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: fontColor,
                .paragraphStyle: paragraphStyle
            ]
            if outlineEnabled {
                attributes[.strokeColor] = outlineColor
                attributes[.strokeWidth] = -3.0
            } else {
                attributes[.strokeWidth] = 0.0
            }
            let attributedString = NSAttributedString(string: episodeNumber, attributes: attributes)
            let textSize = attributedString.size()
            // Calculate position based on user preference with custom padding
            let textRect: NSRect
            switch position {
            case .topLeft:
                paragraphStyle.alignment = .left
                textRect = NSRect(
                    x: horizontalPadding,
                    y: size.height - textSize.height - verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .topRight:
                paragraphStyle.alignment = .right
                textRect = NSRect(
                    x: size.width - textSize.width - horizontalPadding,
                    y: size.height - textSize.height - verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .topCenter:
                paragraphStyle.alignment = .center
                textRect = NSRect(
                    x: (size.width - textSize.width) / 2,
                    y: size.height - textSize.height - verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .bottomLeft:
                paragraphStyle.alignment = .left
                textRect = NSRect(
                    x: horizontalPadding,
                    y: verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .bottomRight:
                paragraphStyle.alignment = .right
                textRect = NSRect(
                    x: size.width - textSize.width - horizontalPadding,
                    y: verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .bottomCenter:
                paragraphStyle.alignment = .center
                textRect = NSRect(
                    x: (size.width - textSize.width) / 2,
                    y: verticalPadding,
                    width: textSize.width,
                    height: textSize.height
                )
            case .center:
                paragraphStyle.alignment = .center
                textRect = NSRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
            }
            attributedString.draw(in: textRect)
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Create final image
        let finalImage = NSImage(size: size)
        finalImage.addRepresentation(imageRep)
        
        return finalImage
    }
    
    /// Calculates the rect for drawing an image based on the scaling mode
    private func calculateBackgroundRect(
        imageSize: NSSize,
        canvasSize: NSSize,
        scaling: BackgroundScaling
    ) -> NSRect {
        switch scaling {
        case .fill:
            // Stretch to fill entire canvas
            return NSRect(origin: .zero, size: canvasSize)
            
        case .fit:
            // Fit image inside canvas maintaining aspect ratio (letterbox)
            let imageAspect = imageSize.width / imageSize.height
            let canvasAspect = canvasSize.width / canvasSize.height
            
            let scaledSize: NSSize
            if imageAspect > canvasAspect {
                // Image is wider - fit to width
                scaledSize = NSSize(
                    width: canvasSize.width,
                    height: canvasSize.width / imageAspect
                )
            } else {
                // Image is taller - fit to height
                scaledSize = NSSize(
                    width: canvasSize.height * imageAspect,
                    height: canvasSize.height
                )
            }
            
            // Center the image
            let origin = NSPoint(
                x: (canvasSize.width - scaledSize.width) / 2,
                y: (canvasSize.height - scaledSize.height) / 2
            )
            
            return NSRect(origin: origin, size: scaledSize)
            
        case .aspectFill:
            // Fill canvas maintaining aspect ratio (crop edges)
            let imageAspect = imageSize.width / imageSize.height
            let canvasAspect = canvasSize.width / canvasSize.height
            
            let scaledSize: NSSize
            if imageAspect > canvasAspect {
                // Image is wider - fit to height and crop width
                scaledSize = NSSize(
                    width: canvasSize.height * imageAspect,
                    height: canvasSize.height
                )
            } else {
                // Image is taller - fit to width and crop height
                scaledSize = NSSize(
                    width: canvasSize.width,
                    height: canvasSize.width / imageAspect
                )
            }
            
            // Center the image
            let origin = NSPoint(
                x: (canvasSize.width - scaledSize.width) / 2,
                y: (canvasSize.height - scaledSize.height) / 2
            )
            
            return NSRect(origin: origin, size: scaledSize)
        }
    }
    
    /// Saves an image to a file
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: The file URL to save to
    ///   - format: The image format (png or jpeg)
    /// - Returns: True if successful
    public func saveImage(_ image: NSImage, to url: URL, format: ImageFormat = .png) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let imageData: Data?
        switch format {
        case .png:
            imageData = bitmapImage.representation(using: .png, properties: [:])
        case .jpeg(let quality):
            imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        
        guard let data = imageData else {
            return false
        }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Error saving image: \(error)")
            return false
        }
    }
    
    public enum ImageFormat {
        case png
        case jpeg(quality: Double)
    }
}
