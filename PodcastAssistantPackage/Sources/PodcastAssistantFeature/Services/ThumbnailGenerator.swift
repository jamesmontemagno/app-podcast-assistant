import AppKit
import CoreGraphics
import CoreText

/// Service responsible for generating podcast thumbnails
public class ThumbnailGenerator {
    
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
    /// - Returns: The generated thumbnail image
    public func generateThumbnail(
        backgroundImage: NSImage,
        overlayImage: NSImage?,
        episodeNumber: String,
        fontName: String = "Helvetica-Bold",
        fontSize: CGFloat = 72,
        position: TextPosition = .topRight,
        horizontalPadding: CGFloat = 40,
        verticalPadding: CGFloat = 40
    ) -> NSImage? {
        
        // Get the size of the background image
        let size = backgroundImage.size
        
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
        
        // Draw background image (scaled to fit)
        backgroundImage.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: backgroundImage.size),
            operation: .copy,
            fraction: 1.0
        )
        
        // Draw overlay image if provided
        if let overlayImage = overlayImage {
            overlayImage.draw(
                in: NSRect(origin: .zero, size: size),
                from: NSRect(origin: .zero, size: overlayImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
        }
        
        // Draw episode number at specified position if provided
        if !episodeNumber.isEmpty {
            let font = NSFont(name: fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize)
        
        let paragraphStyle = NSMutableParagraphStyle()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
            .strokeColor: NSColor.black,
            .strokeWidth: -3.0  // Negative for fill and stroke
        ]
        
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
