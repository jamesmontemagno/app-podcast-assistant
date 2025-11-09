# Settings Page Implementation

This document describes the Settings page implementation for the Podcast Assistant app.

## Overview

A comprehensive Settings page has been added to the app with:
1. **About Section** - App information and GitHub repository link
2. **Font Management** - Import and manage custom fonts for use in thumbnails

## User Features

### About Section
- Displays app name, version, and build number
- Shows app description
- Provides direct link to GitHub repository (https://github.com/jamesmontemagno/app-podcast-assistant)

### Font Management
- **Import Fonts**: Click "Import Font" button to select and import TTF, OTF, or TTC font files
- **View Fonts**: See all imported custom fonts with preview and PostScript name
- **Remove Fonts**: Hover over a font and click the trash icon to remove it
- **Auto-loading**: Imported fonts are automatically registered when the app launches

## Accessing Settings

Click the gear icon (⚙️) in the sidebar header next to the "New Podcast" button.

## Architecture

### Components

#### 1. AppSettings Model (`Models/AppSettings.swift`)
- SwiftData model storing app-wide settings
- Uses singleton pattern with unique ID "app-settings"
- Persists list of imported font names
- Automatically included in SwiftData schema

#### 2. FontManager Service (`Services/FontManager.swift`)
- Handles all font-related operations
- **Import**: Validates, copies, and registers font files
- **Storage**: Fonts stored in `~/Library/Application Support/PodcastAssistant/Fonts/`
- **Registration**: Uses CoreText (CTFontManager) for macOS font registration
- **Cleanup**: Removes fonts from filesystem and unregisters them

#### 3. SettingsViewModel (`ViewModels/SettingsViewModel.swift`)
- ObservableObject managing settings state
- Handles file picker dialogs
- Manages error and success messages
- Auto-dismisses success messages after 3 seconds

#### 4. SettingsView (`Views/SettingsView.swift`)
- Two-part structure for proper StateObject initialization
- Public wrapper passes ModelContext to private content view
- Responsive UI with hover states and visual feedback

### Integration Points

#### ContentView Changes
1. Added `showingSettings` state variable
2. Added Settings button in sidebar header
3. Added `.sheet(isPresented: $showingSettings)` to show Settings
4. Added `registerImportedFonts()` method called in `onAppear`

#### PersistenceController Changes
- Added `AppSettings.self` to SwiftData schema

## Testing

Tests added in `PodcastAssistantFeatureTests.swift`:
- `testAppSettingsCreation()` - Verify AppSettings model creation
- `testAppSettingsFontManagement()` - Test font list management
- `testFontManagerAvailableFonts()` - Check font availability
- `testFontManagerDisplayName()` - Verify display name retrieval

**Note**: Tests can only run on macOS due to AppKit/SwiftUI dependencies.

## File Locations

### New Files
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Models/AppSettings.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/FontManager.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ViewModels/SettingsViewModel.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Views/SettingsView.swift`

### Modified Files
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ContentView.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/PersistenceController.swift`
- `PodcastAssistantPackage/Tests/PodcastAssistantFeatureTests/PodcastAssistantFeatureTests.swift`

## Usage Flow

1. User clicks Settings gear icon in sidebar
2. Settings sheet opens with About and Font Management sections
3. To import a font:
   - Click "Import Font" button
   - File picker opens (filtered to .ttf, .otf, .ttc files)
   - Select font file
   - Font is validated, copied to app directory, and registered
   - Success message appears
   - Font appears in imported fonts list
4. To remove a font:
   - Hover over font in list
   - Click trash icon
   - Font is unregistered and file deleted
   - Success message appears
5. Click "Done" to close settings

## Error Handling

Errors are displayed with red background and can be dismissed:
- Invalid font file
- Font already imported
- Font registration failed
- File operation errors

## Technical Notes

### Why Two-Part View Structure?

SettingsView uses a wrapper pattern because:
1. `@StateObject` requires initialization before the view body
2. We need `ModelContext` from environment
3. The wrapper gets `ModelContext` and passes it to the content view
4. Content view can then use `@StateObject` with the proper context

### Font Storage Location

```
~/Library/Application Support/PodcastAssistant/Fonts/
```

This location:
- Is user-specific
- Persists across app launches
- Follows macOS conventions
- Is automatically created if missing

### Supported Font Formats

- **TTF** (TrueType Font)
- **OTF** (OpenType Font)
- **TTC** (TrueType Collection)

## Future Enhancements

Potential improvements:
- Font preview with custom sample text
- Export/share font configuration
- Cloud sync for imported fonts (via CloudKit)
- Bulk font import
- Font search/filter
- Font categories/tags
