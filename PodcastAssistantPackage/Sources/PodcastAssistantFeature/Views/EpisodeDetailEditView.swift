import SwiftUI
import AppKit

/// View for editing episode details and settings
public struct EpisodeDetailEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    public let episode: Episode
    
    // Form fields
    @State private var title: String = ""
    @State private var episodeNumber: Int = 1
    
    // UI state
    @State private var errorMessage: String?
    
    public init(episode: Episode) {
        self.episode = episode
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Episode Information") {
                    TextField("Episode Title", text: $title)
                    
                    HStack {
                        Text("Episode Number")
                        Spacer()
                        TextField("Number", value: $episodeNumber, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $episodeNumber, in: 1...9999)
                            .labelsHidden()
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Episode Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEpisode()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        title = episode.title
        episodeNumber = Int(episode.episodeNumber)
    }
    
    // MARK: - Save
    
    private func saveEpisode() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Episode title is required"
            return
        }
        
        episode.title = trimmedTitle
        episode.episodeNumber = Int32(episodeNumber)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
