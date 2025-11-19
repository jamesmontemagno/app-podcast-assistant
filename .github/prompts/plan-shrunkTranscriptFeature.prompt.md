# Plan: Add Shrunk Transcript Feature to AI Ideas

Add shrunk transcript generation that automatically condenses transcripts before all AI content generation (titles, descriptions, social posts). The shrunk version strips timestamps/speakers after generation, feeding cleaner content to AI services. Settings will be in a new AI Features tab.

## Steps

### 1. Update SwiftData models

Add `@Attribute(.externalStorage) public var shrunkTranscript: String?` to `EpisodeContent.swift`, plus convenience accessor on `Episode.swift` following the existing `transcriptInputText` pattern.

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Models/SwiftData/EpisodeContent.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Models/SwiftData/Episode.swift`

**Changes:**
- Add property to `EpisodeContent`: `@Attribute(.externalStorage) public var shrunkTranscript: String?`
- Update `EpisodeContent.init()` to include optional parameter
- Add convenience accessor on `Episode` model following pattern of `transcriptInputText`

### 2. Extend AIIdeasViewModel

Add `@Published` properties (`shrunkTranscript`, `isGeneratingShrunkTranscript`), settings via `@AppStorage` (`transcriptShrinkerMaxWindowCharacters: Int = 5000`, `transcriptShrinkerOverlap: Double = 0.2`, `transcriptShrinkerFallbackOnError: Bool = true`), and `private let shrinkerService = TranscriptionShrinkerService()`. Implement `generateShrunkTranscript()` with progress via `shrinkerService.logHandler` updating both `progressDetails` and `statusMessage`, automatically calling `applyShrunkTranscript()` on success to persist immediately. Add `stripTimestampsAndSpeakers()` helper using regex to remove `[HH:MM:SS]`/`[MM:SS]` patterns and return clean text.

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ViewModels/AIIdeasViewModel.swift`

**Changes:**
- Add `@Published` properties:
  - `public var shrunkTranscript: String = ""`
  - `public var isGeneratingShrunkTranscript: Bool = false`
  - `public var originalSegmentCount: Int = 0`
  - `public var shrunkSegmentCount: Int = 0`
- Add `@AppStorage` properties:
  - `@AppStorage("transcriptShrinkerMaxWindowCharacters") private var maxWindowChars: Int = 5000`
  - `@AppStorage("transcriptShrinkerOverlap") private var overlap: Double = 0.2`
  - `@AppStorage("transcriptShrinkerFallbackOnError") private var fallbackOnError: Bool = true`
- Add service dependency: `private let shrinkerService = TranscriptionShrinkerService()`
- Implement `generateShrunkTranscript()` async method:
  - Check model availability and transcript existence
  - Set loading state (`isGeneratingShrunkTranscript = true`)
  - Update both `statusMessage` and `progressDetails`
  - Hook up `shrinkerService.logHandler` to update `progressDetails` in real-time
  - Create config from settings: `TranscriptionShrinkerService.ShrinkConfig(maxWindowCharacters: maxWindowChars, overlap: overlap)`
  - Call `shrinkerService.shrinkTranscript(transcript, config: config)`
  - Format segments as readable text with timestamps: `"[\(segment.firstSegmentTimestamp)]\n\(segment.summary)"`
  - Store segment counts for reduction stats
  - Automatically call `applyShrunkTranscript()` on success
  - Handle errors with fallback logic based on `fallbackOnError` setting
  - Clear loading state
- Implement `applyShrunkTranscript()`:
  - Save to `episode.shrunkTranscript`
  - Call `saveEpisode()`
- Implement `stripTimestampsAndSpeakers(_ text: String) -> String`:
  - Use regex to match and remove `[HH:MM:SS]` or `[MM:SS]` patterns
  - Clean up extra whitespace
  - Return plain summary text
- Add computed property for reduction percentage:
  - `public var reductionPercentage: Int { ... }`

### 3. Update AI generation workflow

Modify `generateTitles()`, `generateDescription()`, `generateSocialPosts()` in `AIIdeasViewModel.swift` to: check if `episode.shrunkTranscript` exists, if not call `await generateShrunkTranscript()` (catching errors and falling back to original if `transcriptShrinkerFallbackOnError` is true), then use `stripTimestampsAndSpeakers(shrunkTranscript)` for AI calls. Update `generateAll()` to generate shrunk transcript once at start, then reuse for all subsequent generations.

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ViewModels/AIIdeasViewModel.swift`

**Changes:**
- Add helper method `prepareTranscriptForAI() async -> String`:
  - Check if `episode.shrunkTranscript` exists and is not empty
  - If not, try to generate shrunk transcript
  - On error, use fallback logic based on `fallbackOnError` setting
  - Return either stripped shrunk transcript or original transcript
- Update `generateTitles()`:
  - Replace `transcript` variable with `await prepareTranscriptForAI()`
  - Pass `isShrunkTranscript: true` flag to service when using shrunk version
- Update `generateDescription()`:
  - Replace `transcript` variable with `await prepareTranscriptForAI()`
  - Pass `isShrunkTranscript: true` flag to service when using shrunk version
- Update `generateSocialPosts()`:
  - Replace `transcript` variable with `await prepareTranscriptForAI()`
  - Pass `isShrunkTranscript: true` flag to service when using shrunk version
- Update `generateAll()`:
  - Generate shrunk transcript first if not exists
  - Then call all other generation methods (which will reuse it)

### 4. Update AI generation services

Modify `TitleGenerationService.swift`, `DescriptionGenerationService.swift`, `SocialPostGenerationService.swift` to accept optional `isShrunkTranscript: Bool = false` parameter. When true, skip `transcriptCleaner.cleanForAI()` and truncation, and prepend prompt with "Note: This is a condensed AI-generated summary of the full episode transcript."

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/AI/TitleGenerationService.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/AI/DescriptionGenerationService.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Services/AI/SocialPostGenerationService.swift`

**Changes for each service:**
- Add parameter `isShrunkTranscript: Bool = false` to generation methods
- Conditionally skip cleaning/truncation when `isShrunkTranscript` is true:
  ```swift
  let processedTranscript: String
  if isShrunkTranscript {
      processedTranscript = transcript
  } else {
      let cleanedTranscript = transcriptCleaner.cleanForAI(transcript)
      processedTranscript = String(cleanedTranscript.prefix(12000))
  }
  ```
- Update prompt to include note when using shrunk transcript:
  ```swift
  let transcriptNote = isShrunkTranscript 
      ? "Note: This is a condensed AI-generated summary of the full episode transcript.\n\n" 
      : ""
  
  let prompt = """
  \(transcriptNote)You are generating...
  """
  ```

### 5. Add shrunk transcript UI section to AIIdeasView

Insert new section after `transcriptInfoSection` with: header showing "Shrunk Transcript" with sparkles icon, generate button with `ProgressView` when `isGeneratingShrunkTranscript`, scrollable display (200px height) for raw shrunk output with timestamps, reduction stats (e.g., "Condensed 847 segments → 124 summaries (85% reduction)"), "Copy" button, real-time `progressDetails` display, and status updates to both section-local area and global `statusMessage`.

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Views/Sections/AIIdeasView.swift`

**Changes:**
- Add new computed property `shrunkTranscriptSection`:
  ```swift
  private var shrunkTranscriptSection: some View {
      VStack(alignment: .leading, spacing: 12) {
          HStack {
              Label("Shrunk Transcript", systemImage: "wand.and.stars")
                  .font(.headline)
              Spacer()
              Button {
                  Task { await viewModel.generateShrunkTranscript() }
              } label: {
                  if viewModel.isGeneratingShrunkTranscript {
                      ProgressView().controlSize(.small)
                      Text("Generating...")
                  } else if viewModel.shrunkTranscript.isEmpty {
                      Label("Generate", systemImage: "sparkles")
                  } else {
                      Label("Regenerate", systemImage: "arrow.clockwise")
                  }
              }
              .buttonStyle(.borderedProminent)
              .disabled(viewModel.isGeneratingShrunkTranscript || viewModel.isGeneratingAll)
          }
          
          // Progress details
          if !viewModel.progressDetails.isEmpty && viewModel.isGeneratingShrunkTranscript {
              Text(viewModel.progressDetails)
                  .font(.caption)
                  .foregroundStyle(.secondary)
          }
          
          // Display area
          if viewModel.shrunkTranscript.isEmpty {
              Text("Generate a condensed version of the transcript for better AI content generation")
                  .foregroundStyle(.secondary)
                  .font(.subheadline)
          } else {
              VStack(alignment: .leading, spacing: 8) {
                  // Reduction stats
                  if viewModel.shrunkSegmentCount > 0 {
                      Text("Condensed \(viewModel.originalSegmentCount) segments → \(viewModel.shrunkSegmentCount) summaries (\(viewModel.reductionPercentage)% reduction)")
                          .font(.caption)
                          .foregroundStyle(.green)
                  }
                  
                  ScrollView {
                      Text(viewModel.shrunkTranscript)
                          .font(.body)
                          .textSelection(.enabled)
                          .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .frame(height: 200)
                  .padding(12)
                  .background(Color(NSColor.textBackgroundColor))
                  .cornerRadius(8)
                  
                  HStack {
                      Button {
                          viewModel.copyToClipboard(viewModel.shrunkTranscript)
                      } label: {
                          Label("Copy", systemImage: "doc.on.doc")
                      }
                      .buttonStyle(.bordered)
                  }
              }
          }
      }
  }
  ```
- Insert `shrunkTranscriptSection` after `transcriptInfoSection` in the main VStack
- Add `Divider().padding(.vertical, 8)` between sections

### 6. Create AI Features settings tab

Add new tab to `SettingsView.swift` TabView with `Label("AI Features", systemImage: "brain")`. Create `AIFeaturesSettingsTab` with "Transcript Shrinker" section containing: Stepper for `transcriptShrinkerMaxWindowCharacters` (3000...10000, step 500), Slider for `transcriptShrinkerOverlap` (0.1...0.4 displayed as percentage), Toggle for "Fallback to original transcript on error", and footer explaining condensing benefits. Add `@AppStorage` properties to `SettingsViewModel.swift`.

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Views/SettingsView.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ViewModels/SettingsViewModel.swift`

**Changes to SettingsViewModel.swift:**
- Add `@AppStorage` properties:
  ```swift
  @AppStorage("transcriptShrinkerMaxWindowCharacters") 
  public var transcriptShrinkerMaxWindowCharacters: Int = 5000
  
  @AppStorage("transcriptShrinkerOverlap") 
  public var transcriptShrinkerOverlap: Double = 0.2
  
  @AppStorage("transcriptShrinkerFallbackOnError") 
  public var transcriptShrinkerFallbackOnError: Bool = true
  ```

**Changes to SettingsView.swift:**
- Add new tab in TabView after "Fonts" tab:
  ```swift
  AIFeaturesSettingsTab(viewModel: viewModel)
      .tabItem {
          Label("AI Features", systemImage: "brain")
      }
  ```
- Create new `AIFeaturesSettingsTab` struct:
  ```swift
  private struct AIFeaturesSettingsTab: View {
      @ObservedObject var viewModel: SettingsViewModel
      
      var body: some View {
          Form {
              Section {
                  Text("Configure AI-powered features and content generation")
                      .foregroundStyle(.secondary)
              }
              
              Section {
                  Stepper("Max Window Characters: \(viewModel.transcriptShrinkerMaxWindowCharacters)", 
                          value: $viewModel.transcriptShrinkerMaxWindowCharacters, 
                          in: 3000...10000, 
                          step: 500)
                  
                  VStack(alignment: .leading, spacing: 8) {
                      Text("Overlap: \(Int(viewModel.transcriptShrinkerOverlap * 100))%")
                      Slider(value: $viewModel.transcriptShrinkerOverlap, in: 0.1...0.4)
                  }
                  
                  Toggle(isOn: $viewModel.transcriptShrinkerFallbackOnError) {
                      VStack(alignment: .leading, spacing: 4) {
                          Text("Fallback to Original Transcript")
                              .font(.body)
                          Text("Use original transcript if shrinking fails")
                              .font(.caption)
                              .foregroundStyle(.secondary)
                      }
                  }
                  .toggleStyle(.switch)
              } header: {
                  Text("Transcript Shrinker")
              } footer: {
                  Text("The transcript shrinker condenses long transcripts into concise summaries using Apple Intelligence. This improves AI content generation quality by focusing on key topics. Larger window sizes preserve more context, while higher overlap ensures continuity between segments.")
                      .font(.caption)
              }
          }
          .formStyle(.grouped)
          .padding(24)
      }
  }
  ```

### 7. Add visual indicators

In title/description/social sections of `AIIdeasView`, add small icon badge (e.g., `Image(systemName: "wand.and.stars.inverse").foregroundStyle(.purple)`) next to section headers when content was generated using shrunk transcript, with tooltip "Generated from condensed transcript".

**Files to modify:**
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/Views/Sections/AIIdeasView.swift`
- `PodcastAssistantPackage/Sources/PodcastAssistantFeature/ViewModels/AIIdeasViewModel.swift`

**Changes to AIIdeasViewModel.swift:**
- Add `@Published` property:
  ```swift
  @Published public var usedShrunkTranscript: Bool = false
  ```
- Set `usedShrunkTranscript = true` in `prepareTranscriptForAI()` when using shrunk version
- Reset `usedShrunkTranscript = false` at start of each generation method

**Changes to AIIdeasView.swift:**
- Update section headers (titles, description, social posts) to show indicator:
  ```swift
  HStack {
      Label("Title Suggestions", systemImage: "text.badge.star")
          .font(.headline)
      
      if viewModel.usedShrunkTranscript {
          Image(systemName: "wand.and.stars.inverse")
              .foregroundStyle(.purple)
              .help("Generated from condensed transcript")
      }
      
      Spacer()
      // ... rest of header
  }
  ```

## Implementation Summary

This plan implements automatic transcript shrinking before AI generation, with:
- **Automatic persistence** – Shrunk transcripts saved immediately to SwiftData
- **Settings in AI Features tab** – Configurable window size, overlap, and error fallback
- **Progress logging** – Real-time updates to both section-local and global status areas
- **Error handling** – Optional fallback to original transcript on shrinking failures
- **Visual feedback** – Icon badges showing when AI content used shrunk transcript
- **Performance optimization** – External storage for large shrunk transcript data
- **Seamless integration** – All AI features (titles, descriptions, posts) automatically use shrunk version

The shrunk transcript dramatically improves AI content quality by removing timestamps/speaker names and condensing the content while preserving key topics and insights.
