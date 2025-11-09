import SwiftUI
import SwiftData

/// Settings view for app-wide configuration
public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    
    public init() {
    }
    
    public var body: some View {
        SettingsContentView(modelContext: modelContext)
    }
}

/// Internal content view that properly manages the view model
private struct SettingsContentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - About Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "app.badge")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(SettingsViewModel.appName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    Text("Version \(SettingsViewModel.appVersion) (\(SettingsViewModel.appBuild))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("A powerful tool for managing podcast transcripts and thumbnails.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                Link(destination: SettingsViewModel.githubURL) {
                                    HStack {
                                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        Text("View on GitHub")
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    } label: {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                    }
                    
                    // MARK: - Font Management Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Import custom fonts to use in your podcast thumbnails.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                Text("Supported formats: TTF, OTF, TTC")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Divider()
                            
                            // Import button
                            Button {
                                viewModel.importFont()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Import Font")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Imported fonts list
                            if viewModel.importedFonts.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "textformat")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("No custom fonts imported")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Imported Fonts (\(viewModel.importedFonts.count))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    
                                    Divider()
                                    
                                    ForEach(viewModel.importedFonts, id: \.self) { fontName in
                                        FontRow(
                                            fontName: fontName,
                                            displayName: viewModel.getDisplayName(for: fontName),
                                            onDelete: {
                                                viewModel.removeFont(fontName)
                                            }
                                        )
                                    }
                                }
                            }
                            
                            // Messages
                            if let error = viewModel.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption)
                                    Spacer()
                                    Button {
                                        viewModel.clearError()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            if let success = viewModel.successMessage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(success)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                    } label: {
                        Label("Font Management", systemImage: "textformat")
                            .font(.headline)
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

// MARK: - Supporting Views

/// Row view for displaying an imported font
private struct FontRow: View {
    let fontName: String
    let displayName: String
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            // Font preview
            Text("Aa")
                .font(.custom(fontName, size: 20))
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.body)
                
                Text(fontName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isHovered {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovered ? Color.gray.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
