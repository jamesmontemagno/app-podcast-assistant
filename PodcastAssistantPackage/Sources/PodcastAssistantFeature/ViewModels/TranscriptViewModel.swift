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
    @Published public var showingExporter: Bool = false
    @Published public var showingImporter: Bool = false
    
    private let converter = TranscriptConverter()
    
    public init() {}
    
    /// Returns an SRTDocument for the current output
    public var srtDocument: SRTDocument {
        SRTDocument(text: outputSRT)
    }
    
    /// Triggers the file importer
    public func importFile() {
        showingImporter = true
    }
    
    /// Handles the imported file from fileImporter
    public func handleImportedFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Failed to access file: Permission denied"
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                inputText = content
                errorMessage = nil
                successMessage = "File loaded successfully"
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Failed to import file: \(error.localizedDescription)"
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
    
    /// Triggers the file exporter
    public func exportSRT() {
        guard !outputSRT.isEmpty else {
            errorMessage = "No SRT content to export"
            return
        }
        showingExporter = true
    }
    
    /// Handles the export completion from fileExporter
    public func handleExportCompletion(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            successMessage = "SRT file saved successfully to \(url.lastPathComponent)"
            errorMessage = nil
        case .failure(let error):
            errorMessage = "Failed to save file: \(error.localizedDescription)"
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
