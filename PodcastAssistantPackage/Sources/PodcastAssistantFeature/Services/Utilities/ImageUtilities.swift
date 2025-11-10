import Foundation
import AppKit

/// Utilities for processing images before storing in Core Data.
/// Handles resizing and compression to keep database size manageable.
public enum ImageUtilities {
    
    // MARK: - Constants
    
    /// Maximum dimension (width or height) for stored images
    public static let maxDimension: CGFloat = 1024
    
    /// JPEG compression quality (0.0 = maximum compression, 1.0 = no compression)
    public static let compressionQuality: CGFloat = 0.8
    
    // MARK: - Public Methods
    
    /// Processes an image for storage in Core Data by resizing and compressing it.
    /// - Parameters:
    ///   - image: The source NSImage to process
    ///   - preserveTransparency: If true, saves as PNG to preserve alpha channel. If false, saves as JPEG (smaller file size)
    /// - Returns: Compressed image data (PNG or JPEG), or nil if processing fails
    public static func processImageForStorage(_ image: NSImage, preserveTransparency: Bool = false) -> Data? {
        guard let resizedImage = resize(image: image, maxDimension: maxDimension) else {
            return nil
        }
        
        if preserveTransparency {
            return compressToPNG(image: resizedImage)
        } else {
            return compressToJPEG(image: resizedImage, quality: compressionQuality)
        }
    }
    
    /// Loads an NSImage from Data (typically from Core Data)
    /// - Parameter data: Image data (JPEG, PNG, etc.)
    /// - Returns: NSImage if data is valid, nil otherwise
    public static func loadImage(from data: Data) -> NSImage? {
        return NSImage(data: data)
    }
    
    // MARK: - Private Methods
    
    /// Resizes an image to fit within a maximum dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - image: Source image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image, or nil if resizing fails
    private static func resize(image: NSImage, maxDimension: CGFloat) -> NSImage? {
        let imageSize = image.size
        
        // Check if resizing is needed
        if imageSize.width <= maxDimension && imageSize.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = imageSize.width / imageSize.height
        var newSize: NSSize
        
        if imageSize.width > imageSize.height {
            newSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create resized image
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        
        // Draw with high quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: imageSize),
                   operation: .copy,
                   fraction: 1.0)
        
        newImage.unlockFocus()
        
        return newImage
    }
    
    /// Compresses an image to JPEG format with specified quality
    /// - Parameters:
    ///   - image: Source image
    ///   - quality: Compression quality (0.0 to 1.0)
    /// - Returns: JPEG data, or nil if compression fails
    private static func compressToJPEG(image: NSImage, quality: CGFloat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    
    /// Compresses an image to PNG format (preserves transparency)
    /// - Parameter image: Source image
    /// - Returns: PNG data, or nil if compression fails
    private static func compressToPNG(image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
