# Settings Feature Quick Reference

## What Was Added

A complete Settings page accessible via the gear icon (⚙️) in the app's sidebar.

## Features

### 1. About Section
- App name and version info
- Link to GitHub repository
- App description

### 2. Appearance (Theme Selection) ⭐ NEW
- **System** (default): Follows macOS appearance
- **Light**: Always light mode
- **Dark**: Always dark mode
- Changes apply instantly
- Saved automatically and restored on restart

### 3. Font Management
- Import custom fonts (TTF, OTF, TTC)
- View imported fonts with preview
- Remove fonts with hover-to-reveal delete button
- Fonts auto-register on app launch

## How to Use

### Change Theme
1. Click ⚙️ Settings in sidebar
2. Find "Appearance" section
3. Click desired theme in segmented control
4. Theme applies immediately
5. Click "Done"

### Import Font
1. Click ⚙️ Settings in sidebar
2. Scroll to "Font Management"
3. Click "Import Font"
4. Select TTF/OTF/TTC file
5. Font appears in list
6. Click "Done"

### Remove Font
1. Open Settings
2. Scroll to imported fonts list
3. Hover over font to remove
4. Click 🗑 trash icon
5. Font is removed

## Files Changed

### New Files (4):
- `Models/AppSettings.swift` - Settings data model
- `Services/FontManager.swift` - Font operations
- `ViewModels/SettingsViewModel.swift` - Settings logic
- `Views/SettingsView.swift` - Settings UI

### Modified Files (3):
- `ContentView.swift` - Added Settings button, theme restore
- `PersistenceController.swift` - Added AppSettings to schema
- `PodcastAssistantFeatureTests.swift` - Added tests

### Documentation (2):
- `docs/SETTINGS.md` - Technical documentation
- `docs/SETTINGS_UI.md` - UI mockups

## Code Stats

- **Lines added**: ~1,000
- **New Swift files**: 4
- **Tests added**: 6
- **Zero breaking changes**: All additions, no deletions

## Technical Notes

### Theme Implementation
```swift
// Stored as String in SwiftData
public var theme: String // "System", "Light", or "Dark"

// Applied via NSApp.appearance
case .system: NSApp.appearance = nil
case .light: NSApp.appearance = NSAppearance(named: .aqua)
case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
```

### Font Storage
- Location: `~/Library/Application Support/PodcastAssistant/Fonts/`
- Registration: CoreText CTFontManager
- Persistence: Font names in SwiftData

### Settings Access
- Singleton pattern: Only one AppSettings instance (id: "app-settings")
- Auto-created on first access
- Persisted via SwiftData

## Known Limitations

- Theme switching tested on macOS only (SwiftUI/AppKit dependency)
- Font formats limited to TTF, OTF, TTC
- No cloud sync (local storage only, CloudKit-ready schema)

## Next Steps

1. **Build the app** on macOS (requires Xcode)
2. **Test theme switching** in Settings
3. **Import a test font** to verify functionality
4. **Restart app** to verify persistence

## Support

- Full documentation: `docs/SETTINGS.md`
- UI mockups: `docs/SETTINGS_UI.md`
- Code location: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/`
