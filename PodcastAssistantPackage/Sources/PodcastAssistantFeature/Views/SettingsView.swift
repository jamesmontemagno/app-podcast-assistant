import SwiftUI

/// Settings view for app-wide configuration
public struct SettingsView: View {
    public init() {
    }
    
    public var body: some View {
        SettingsContentView()
    }
}

/// Internal content view that properly manages the view model
private struct SettingsContentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    init() {
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // MARK: - General Tab
                GeneralSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                // MARK: - Appearance Tab
                AppearanceSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                
                // MARK: - Fonts Tab
                FontsSettingsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Fonts", systemImage: "textformat")
                    }
                
                // MARK: - About Tab
                AboutSettingsTab()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
            }
            .padding(.top, 20)
            
            // Close button at bottom
            Divider()
            
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 550, idealHeight: 600)
        .onAppear {
            viewModel.applyCurrentTheme()
        }
    }
}

// MARK: - General Settings Tab

private struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Text("General app settings and preferences")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                Toggle(isOn: $viewModel.autoUpdateThumbnail) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-update Thumbnails")
                            .font(.body)
                        Text("Automatically regenerate thumbnails when settings change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            } header: {
                Text("Thumbnail Behavior")
            } footer: {
                Text("When disabled, thumbnails only update when you press the Generate button")
                    .font(.caption)
            }
            
            // Placeholder for future general settings
            Section {
                LabeledContent("App Name") {
                    Text(SettingsViewModel.appName)
                        .foregroundStyle(.secondary)
                }
                
                LabeledContent("Version") {
                    Text("\(SettingsViewModel.appVersion) (\(SettingsViewModel.appBuild))")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Information")
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
}

// MARK: - Appearance Settings Tab

private struct AppearanceSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section {
                Text("Customize how the app looks")
                    .foregroundStyle(.secondary)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Theme selection as radio buttons
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            viewModel.updateTheme(theme)
                        } label: {
                            HStack(spacing: 12) {
                                // Icon
                                Image(systemName: iconForTheme(theme))
                                    .font(.title2)
                                    .foregroundStyle(viewModel.selectedTheme == theme ? .blue : .secondary)
                                    .frame(width: 32)
                                
                                // Theme info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(descriptionForTheme(theme))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Selection indicator
                                if viewModel.selectedTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.selectedTheme == theme ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.selectedTheme == theme ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Theme")
            } footer: {
                Text("Changes apply immediately")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
    
    private func iconForTheme(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    private func descriptionForTheme(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "Match system appearance"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        }
    }
}

// MARK: - Fonts Settings Tab

private struct FontsSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Import custom fonts to use in your podcast thumbnails")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Text("Supported formats: TTF, OTF, TTC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button {
                    viewModel.importFont()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Import Font")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Fonts list
            ScrollView {
                if viewModel.importedFonts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "textformat")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No custom fonts imported")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text("Click the button above to import a font")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(viewModel.importedFonts.count) \(viewModel.importedFonts.count == 1 ? "Font" : "Fonts") Imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                        
                        ForEach(viewModel.importedFonts, id: \.self) { fontName in
                            FontRow(
                                fontName: fontName,
                                displayName: viewModel.getDisplayName(for: fontName),
                                onDelete: {
                                    viewModel.removeFont(fontName)
                                }
                            )
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            
            // Messages
            if let error = viewModel.errorMessage {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                    Spacer()
                    Button {
                        viewModel.clearError()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
            }
            
            if let success = viewModel.successMessage {
                Divider()
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(success)
                        .font(.callout)
                    Spacer()
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
            }
        }
    }
}

// MARK: - About Settings Tab

private struct AboutSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App icon and info
                VStack(spacing: 12) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    
                    Text(SettingsViewModel.appName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version \(SettingsViewModel.appVersion) (\(SettingsViewModel.appBuild))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                Divider()
                    .padding(.horizontal, 40)
                
                // Description
                Text("A powerful tool for managing podcast transcripts and thumbnails")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // GitHub link
                Link(destination: SettingsViewModel.githubURL) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("View on GitHub")
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Copyright
                Text("© 2025 James Montemagno")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
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
