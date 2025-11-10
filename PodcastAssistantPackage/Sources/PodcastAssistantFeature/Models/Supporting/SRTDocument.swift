import Foundation
import UniformTypeIdentifiers
import SwiftUI

/// A document type representing SRT (SubRip Subtitle) files
public struct SRTDocument: FileDocument {
    public static var readableContentTypes: [UTType] {
        if let srtType = UTType(filenameExtension: "srt") {
            return [srtType]
        }
        return [.plainText]
    }
    
    public var text: String
    
    public init(text: String = "") {
        self.text = text
    }
    
    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
