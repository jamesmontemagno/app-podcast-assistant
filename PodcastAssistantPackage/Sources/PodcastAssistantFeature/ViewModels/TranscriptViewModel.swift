import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel for transcript conversion functionality
@MainActor
public class TranscriptViewModel: ObservableObject {
    @Published public var inputText: String = ""
    @Published public var outputSRT: String = ""
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    
    private let converter = TranscriptConverter()
    
    public init() {}
    
    /// Imports a text file
    public func importFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.message = "Select a transcript text file"
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        self.inputText = content
                        self.errorMessage = nil
                        self.successMessage = "File loaded successfully"
                    } catch {
                        self.errorMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// Converts the input text to SRT format
    public func convertToSRT() {
        guard !inputText.isEmpty else {
            errorMessage = "Please provide input text"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        Task { @MainActor in
            do {
                let srt = try converter.convertToSRT(from: inputText)
                self.outputSRT = srt
                self.successMessage = "Conversion successful!"
                self.isProcessing = false
            } catch {
                self.errorMessage = "Conversion failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    /// Exports the SRT to a file
    public func exportSRT() {
        guard !outputSRT.isEmpty else {
            errorMessage = "No SRT content to export"
            return
        }
        
        let panel = NSSavePanel()
        // Create proper UTType for SRT files
        if let srtType = UTType(filenameExtension: "srt") {
            panel.allowedContentTypes = [srtType]
        } else {
            // Fallback to plain text if SRT type isn't recognized
            panel.allowedContentTypes = [.plainText]
        }
        panel.nameFieldStringValue = "transcript.srt"
        panel.message = "Save SRT file"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    do {
                        try self.outputSRT.write(to: url, atomically: true, encoding: .utf8)
                        self.successMessage = "SRT file saved successfully to \(url.lastPathComponent)"
                        self.errorMessage = nil
                    } catch {
                        self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    /// Clears all fields
    public func clear() {
        inputText = ""
        outputSRT = ""
        errorMessage = nil
        successMessage = nil
    }
}
