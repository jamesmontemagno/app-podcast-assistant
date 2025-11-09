# Translation Features - SRT & Episode Translation

## Overview

Podcast Assistant includes comprehensive translation features using macOS's built-in Translation API for high-quality, on-device translation. Two distinct translation features are available:

1. **SRT Translation** - Translate subtitle files to other languages while preserving timestamps
2. **Episode Translation** - Translate episode titles and descriptions for multilingual podcast content

All translation happens **locally on your Mac** with no cloud services or API keys required.

## Requirements

- **macOS 26.0 or later** - Required for Translation API support
- **Translation Language Packs** - Downloaded via System Settings
- **Network connection** - Only for initial language pack downloads

## Feature 1: SRT Translation

### Overview

Export your podcast subtitles (SRT files) in multiple languages while preserving the original timing information. Perfect for:
- Multilingual YouTube videos
- Accessibility across language barriers
- International podcast distribution
- Language learning content

### Supported Languages

**12+ languages supported:**
- Spanish (Español)
- French (Français)
- German (Deutsch)
- Japanese (日本語)
- Portuguese (Português)
- Italian (Italiano)
- Korean (한국어)
- Chinese Simplified (简体中文)
- Dutch (Nederlands)
- Russian (Русский)
- Arabic (العربية)
- Hindi (हिन्दी)

**Note:** Availability depends on installed translation packs.

### How to Use

#### Step 1: Prepare Your Transcript

1. Select an episode from the episode list
2. Click the **"Transcript"** tab
3. Import or paste your transcript content
4. Click **"Convert to SRT"** to generate English SRT
5. Verify the SRT output looks correct

#### Step 2: Translate the SRT

1. Click the **"Translate"** (globe 🌐) button in the toolbar
2. A sheet appears with language selection
3. Choose your target language from the dropdown
4. Languages are sorted:
   - **Installed languages** (✅) appear first
   - **Available but not installed** (⚠️) appear below
5. Click **"Translate"**

#### Step 3: Monitor Progress

During translation:
- Progress bar shows completion percentage
- Current subtitle entry number displayed
- Preview of text being translated
- Estimated time remaining

**Translation times:**
- Short video (5 min): 10-30 seconds
- Medium video (30 min): 1-3 minutes
- Long video (60+ min): 3-6 minutes

#### Step 4: Export Translated SRT

1. Translation completes with success message
2. Save dialog appears automatically
3. Choose filename and location
4. Click **"Save"**

**Default filename:** `[Original Name] - [Language].srt`
Example: `Episode-1-SRT - Spanish.srt`

#### Step 5: Upload to Platform

- Upload the translated SRT to YouTube, Vimeo, etc.
- Add multiple languages by repeating the process
- Each language gets a separate SRT file

### SRT Translation Architecture

#### Components

**TranslationService**
Located: `Services/TranslationService.swift`

**Key Features:**
- Parses SRT format preserving timestamps
- Translates text line-by-line
- Maintains subtitle timing and sequence
- Progress reporting via AsyncStream
- Error handling for translation failures

**Key Methods:**
```swift
public func getAvailableLanguages() async -> [AvailableLanguage]
public func translateSRT(
    srtContent: String,
    to targetLanguage: AvailableLanguage
) async throws -> AsyncStream<TranslationProgressUpdate>
```

**Data Flow:**
```
Original SRT Text
    ↓
Parse into TranscriptEntry objects
    ↓
Extract dialog text (preserve timestamps)
    ↓
Translate text via Translation API
    ↓
Reconstruct SRT with translated text + original timestamps
    ↓
Export to file
```

### Language Availability

**Checking Language Status:**

The app shows real-time language availability:

```swift
public struct AvailableLanguage {
    public let localizedName: String  // "Spanish"
    public let code: String           // "es"
    public let status: LanguageAvailability.Status
    public var isInstalled: Bool      // true if ready to use
}
```

**Language States:**
- **✅ Installed** - Ready to use immediately
- **⚠️ Available** - Can be downloaded in System Settings
- **🚫 Unsupported** - Not available for your device

### Installing Language Packs

If a language shows as "Available" but not "Installed":

1. **Open System Settings**
   - Click Apple menu > System Settings
   
2. **Navigate to Translation Languages**
   - General > Language & Region
   - Scroll to "Translation Languages"
   
3. **Add Languages**
   - Click "+" button
   - Add both:
     - Your source language (e.g., English)
     - Your target language (e.g., Spanish)
   
4. **Wait for Download**
   - Language packs are 100-500 MB each
   - Download time varies by connection speed
   - Multiple languages can download simultaneously
   
5. **Restart Podcast Assistant**
   - Close and reopen the app
   - Languages will now show as "Installed" (✅)

**Tip:** Install language packs in advance to avoid delays during translation.

### SRT Translation Limitations

**Current Limitations:**

1. **Sequential Processing**
   - Translates one subtitle at a time
   - Cannot skip or batch process
   - Progress is linear (1%, 2%, 3%...)

2. **No Editing During Translation**
   - Cannot cancel mid-translation
   - Must wait for completion
   - Close sheet to abort (loses progress)

3. **Memory Usage**
   - Large SRT files (1000+ entries) use significant memory
   - May slow down on older Macs
   - Consider splitting very long videos

4. **Translation Quality**
   - Quality depends on macOS translation models
   - Technical terms may not translate perfectly
   - Names and brands may be incorrectly translated

### SRT Best Practices

**For Best Results:**

1. **Clean Your SRT First**
   - Remove speaker labels if not needed
   - Fix obvious transcription errors
   - Ensure proper capitalization
   - Remove duplicate entries

2. **Review Original English SRT**
   - Verify timestamps are correct
   - Check for overlapping subtitles
   - Ensure text fits reading time

3. **Test with Short Clips First**
   - Translate a 5-minute segment
   - Review quality before doing full episode
   - Adjust original if needed

4. **Post-Translation Review**
   - Open translated SRT in a text editor
   - Check for obvious errors
   - Verify timestamps weren't corrupted
   - Test on your video platform

5. **Use Platform-Specific Guidelines**
   - YouTube: Max 2 lines, 42 characters per line
   - Check subtitle guidelines for your platform
   - Adjust original SRT if needed before translating

---

## Feature 2: Episode Translation

### Overview

Translate episode titles and descriptions for creating multilingual podcast listings. Perfect for:
- International podcast distribution
- Multi-region podcast platforms
- Bilingual show notes
- Reaching global audiences

### How to Use

#### Step 1: Open Episode Details

1. Select an episode from the episode list
2. Click the **"Edit Details"** (pencil icon) button next to the episode
3. Episode detail edit sheet appears

#### Step 2: Initiate Translation

1. At the bottom of the sheet, click **"Translate"** (globe 🌐) button
2. Translation sheet slides up over the edit sheet

#### Step 3: Select Language

1. Review current episode title and description (source)
2. Choose target language from dropdown
3. Languages are sorted by installation status:
   - ✅ **Installed** (ready to use) appear first
   - ⚠️ **Not installed** appear below with instructions

**If language not installed:**
- Orange warning banner appears
- Instructions show how to download language packs
- Link to System Settings

#### Step 4: Translate

1. Click **"Translate"** button
2. Translation happens in seconds (typically 2-5 seconds)
3. Translated title and description appear in preview area

#### Step 5: Use Translated Content

1. Review translated content for quality
2. Click **"Copy Title"** or **"Copy Description"** buttons
3. Paste into your podcast platform
4. Click **"Done"** to close translation sheet

**Note:** Translation is not saved to the episode—it's a copy-to-clipboard workflow.

### Episode Translation Architecture

#### Components

**EpisodeTranslationViewModel**
Located: `ViewModels/EpisodeTranslationViewModel.swift`

**Responsibilities:**
- Language availability checking
- Episode title and description translation
- Clipboard integration
- Error handling for missing language packs

**Key Properties:**
```swift
@Published public var availableLanguages: [AvailableLanguage]
@Published public var selectedLanguage: AvailableLanguage?
@Published public var isTranslating: Bool
@Published public var translatedTitle: String
@Published public var translatedDescription: String
```

**Key Methods:**
```swift
public func loadLanguages() async
public func translateEpisode(title: String, description: String?) async
```

**EpisodeDetailEditView**
Located: `Views/EpisodeDetailEditView.swift`

**Features:**
- Episode title and description editing
- Translation button integration
- Sheet presentation for translation UI
- Save/cancel workflow

**Data Flow:**
```
Episode.title + Episode.description
    ↓
User clicks "Translate"
    ↓
EpisodeTranslationViewModel
    ↓
TranslationService.translateText()
    ↓
Translated title + description
    ↓
User copies to clipboard
    ↓
Paste into podcast platform
```

### Why Not Save Translations?

**Design Decision: Translation as a Tool, Not Storage**

Episode translations are **not saved** to Core Data because:

1. **Flexibility** - Different platforms may need different translations
2. **Space** - Saving all translations would bloat the database
3. **Workflow** - Most users translate once and paste directly into their platform
4. **Updates** - If you update the English description, all translations would be outdated
5. **Simplicity** - Copy-to-clipboard is faster than save/edit/export workflows

**Recommended Workflow:**
- Translate on-demand when publishing to a platform
- Paste directly into platform's description field
- Re-translate if you update the episode description

### Episode Translation Limitations

**Current Limitations:**

1. **Not Persisted**
   - Translations exist only in memory
   - Closing sheet discards translations
   - Must retranslate if needed again

2. **No Batch Translation**
   - One episode at a time
   - Cannot translate entire podcast at once
   - Must repeat for each episode

3. **No History**
   - Previous translations not saved
   - Cannot compare versions
   - Must keep external notes if needed

4. **Description Only**
   - Translates title and description fields
   - Does not translate transcript or SRT
   - Use SRT Translation for subtitle translation

### Episode Translation Best Practices

**For Best Results:**

1. **Write Good Source Content First**
   - Clear, concise descriptions
   - Proper grammar and spelling
   - Avoid idioms and slang
   - Use simple sentence structure

2. **Review Translations**
   - Copy to a text editor first
   - Check for obvious errors
   - Verify tone is appropriate
   - Adjust as needed before publishing

3. **Use Platform-Specific Versions**
   - Different platforms have different character limits
   - Translate your platform-optimized description
   - Don't try to use one translation everywhere

4. **Keep Source Language Accurate**
   - Translation quality depends on source quality
   - Fix typos before translating
   - Update source, then retranslate

---

## Translation Service Technical Details

### Architecture

**Core Component:** `TranslationService.swift`

Located: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/`

**Dependencies:**
- Foundation framework
- Translation framework (macOS 26+)

**Availability Check:**
```swift
@available(macOS 26.0, *)
public final class TranslationService: Sendable {
    // Implementation
}
```

### Translation API Usage

**Getting Available Languages:**

```swift
let service = TranslationService()
let languages = await service.getAvailableLanguages()

// Returns array of AvailableLanguage
for language in languages {
    print("\(language.localizedName) - Installed: \(language.isInstalled)")
}
```

**Translating Text:**

```swift
let translatedText = try await service.translateText(
    text: "Hello, world!",
    to: spanishLanguage
)
// Returns: "¡Hola, mundo!"
```

**Translating SRT (with progress):**

```swift
let progressStream = try await service.translateSRT(
    srtContent: srtString,
    to: frenchLanguage
)

for await progress in progressStream {
    print("Progress: \(progress.fractionCompleted * 100)%")
    print("Current: \(progress.currentEntry)/\(progress.totalEntries)")
    print("Preview: \(progress.preview)")
}
```

### Error Handling

**Common Errors:**

1. **Language Pack Not Installed**
```swift
errorMessage = "Download the translation packs for both your source 
language (usually English) and [target language] in System Settings > 
General > Language & Region > Translation Languages."
```

2. **Translation API Unavailable**
```swift
errorMessage = "Translation requires macOS 26 or later."
```

3. **Empty Content**
```swift
errorMessage = "Cannot translate empty content."
```

4. **Invalid SRT Format**
```swift
throw TranslationError.invalidSRTFormat
```

### Performance Considerations

**Translation Speed:**

Factors affecting translation speed:
- Content length (longer = slower)
- Language pair (some pairs faster than others)
- System load (other apps using Translation API)
- Language pack status (first use may be slower)

**Typical Performance:**
- **Single title** (10-20 words): < 1 second
- **Description** (100-200 words): 2-5 seconds
- **SRT (100 entries)**: 30-60 seconds
- **SRT (500 entries)**: 2-4 minutes
- **SRT (1000+ entries)**: 4-8 minutes

**Optimization Tips:**
- Install language packs in advance
- Close resource-intensive apps during long translations
- Use shorter subtitle durations to reduce entry count
- Consider translating video segments separately

### Memory Management

**Memory Usage:**

Translation service uses memory for:
- Source text storage
- Translation API buffers
- Result caching
- Progress tracking

**Large Content Handling:**

For very large SRT files (> 1000 entries):
- Consider splitting into multiple files
- Monitor Activity Monitor during translation
- Close other apps to free memory
- Restart app between very large translations

---

## Troubleshooting

### Common Issues

#### "Translation requires macOS 26 or later"

**Problem:** Translation features unavailable

**Solution:**
1. Check macOS version: About This Mac
2. Upgrade to macOS 26 if needed
3. Features will appear after upgrade

#### "Download the translation packs..."

**Problem:** Orange warning banner, translation fails

**Solution:**
1. Open System Settings
2. General > Language & Region
3. Translation Languages
4. Add both source and target languages
5. Wait for download
6. Restart Podcast Assistant

#### Translation Produces Poor Results

**Problem:** Translated text is incorrect or nonsensical

**Solutions:**
1. **Check source quality:**
   - Fix spelling/grammar errors
   - Simplify complex sentences
   - Remove slang and idioms

2. **Verify language packs:**
   - Ensure both languages are fully downloaded
   - Check for interrupted downloads
   - Reinstall language packs if needed

3. **Try different phrasing:**
   - Reword your original text
   - Use more common vocabulary
   - Break long sentences into shorter ones

4. **Report issues:**
   - macOS Translation quality issues should be reported to Apple
   - Podcast Assistant uses system translation—we can't fix translation quality

#### Translation Hangs or Freezes

**Problem:** Progress bar stuck, app becomes unresponsive

**Solutions:**
1. **Wait:** Large files take time (up to 10 minutes)
2. **Check system load:** Activity Monitor
3. **Close other apps:** Free up resources
4. **Force quit:** If truly frozen, relaunch app
5. **Split content:** Translate smaller chunks

#### Languages Not Showing Up

**Problem:** Expected language not in dropdown

**Solutions:**
1. Verify language is supported by macOS Translation
2. Check System Settings > Language & Region
3. Add language manually
4. Restart Podcast Assistant
5. Check macOS documentation for supported languages

---

## Best Practices Summary

### SRT Translation Workflow

**Efficient Process:**
1. ✅ Create clean English SRT first
2. ✅ Install all needed language packs in advance
3. ✅ Translate during non-critical time (takes several minutes)
4. ✅ Review translated SRT in text editor
5. ✅ Test on target platform before publishing
6. ✅ Keep original English SRT as master copy

### Episode Translation Workflow

**Quick Translation Process:**
1. ✅ Write clear, concise episode description
2. ✅ Translate one language at a time
3. ✅ Copy to clipboard immediately
4. ✅ Paste into platform and save
5. ✅ Repeat for each platform/language combination

### General Best Practices

**For All Translation Features:**

✅ **Do:**
- Install language packs before you need them
- Review all translations before publishing
- Keep source content clean and well-written
- Test translations on a small sample first
- Save translated files/text externally
- Use appropriate length for target platform

❌ **Don't:**
- Translate without reviewing output
- Assume translation is perfect
- Forget to install language packs
- Try to translate very large files at once
- Rely on translation for critical accuracy (medical, legal, etc.)
- Publish without testing on target platform

---

## Future Enhancements

### Planned Features

1. **Batch Episode Translation**
   - Translate all episodes in a podcast
   - Queue management for long operations
   - Export translations as CSV

2. **Translation Memory**
   - Save previous translations
   - Reuse common phrases
   - Consistency across episodes

3. **Custom Terminology**
   - User-defined translation rules
   - Brand name handling
   - Technical term preservation

4. **Quality Metrics**
   - Translation confidence scores
   - Flag uncertain translations
   - Suggest alternatives

5. **Platform Integration**
   - Direct export to podcast platforms
   - API integration for automated upload
   - Multi-language publishing workflows

6. **Offline Translation**
   - Download models for offline use
   - Airplane-safe translation
   - No network dependency

---

## Resources

### Learn More

- [Translation Framework Documentation](https://developer.apple.com/documentation/Translation)
- [LanguageAvailability Reference](https://developer.apple.com/documentation/Translation/LanguageAvailability)
- [macOS 26 Release Notes](https://developer.apple.com/documentation/macos-release-notes)

### Related Documentation

- [AI_IDEAS.md](AI_IDEAS.md) - AI content generation features
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [SETTINGS.md](SETTINGS.md) - App settings and customization

### YouTube Subtitle Guidelines

- [YouTube Subtitle Specs](https://support.google.com/youtube/answer/2734796)
- [Best Practices for Subtitles](https://support.google.com/youtube/answer/6373554)
- [Multi-language Video Setup](https://support.google.com/youtube/answer/2734698)

### Getting Help

If you encounter translation issues:

1. Check this documentation first
2. Verify macOS version and language pack installation
3. Review error messages in the app
4. Check Console app for detailed logs
5. File an issue on GitHub with:
   - macOS version
   - Languages involved
   - Error messages
   - Sample content (if not private)
