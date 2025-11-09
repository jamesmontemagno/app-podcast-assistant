# AI Ideas - Content Generation with Apple Intelligence

## Overview

The AI Ideas feature uses **Apple Intelligence** to generate high-quality podcast content directly from your episode transcripts. All processing happens **on-device** using macOS's built-in SystemLanguageModel—no cloud services, API keys, or subscriptions required.

## Requirements

- **macOS 26.0 or later** with Apple Intelligence enabled
- Episode must have a transcript (either imported or pasted)
- Sufficient system resources for on-device AI processing

## Supported Content Types

### 1. Episode Titles
Generate 3 catchy, attention-grabbing title variations:
- Optimized for podcast platforms (Apple Podcasts, Spotify, etc.)
- Concise and descriptive
- Captures the essence of the episode
- Can regenerate unlimited times for different variations

**Example Output:**
```
1. "Building SwiftUI Apps: From Prototype to Production"
2. "SwiftUI Deep Dive: Real-World App Architecture"
3. "Master SwiftUI: Pro Tips for iOS Development"
```

### 2. Episode Descriptions
Generate descriptions in three lengths:

#### Short (1-2 sentences)
- Quick summary for social media
- ~50-100 words
- Perfect for YouTube descriptions, show notes teasers

#### Medium (2-3 paragraphs)
- Standard podcast description
- ~150-250 words
- Good for podcast platforms, blog posts

#### Long (4-5 paragraphs)
- Comprehensive episode summary
- ~300-500 words
- Ideal for detailed show notes, blog posts, newsletters

**Example Output (Medium):**
```
In this episode, we dive deep into SwiftUI app architecture and 
best practices for building production-ready iOS applications. 

We discuss the MVVM pattern, state management with @State and 
@StateObject, and how to integrate Core Data for persistent storage. 
You'll learn practical techniques for organizing your code, handling 
async operations, and creating responsive user interfaces.

Whether you're new to SwiftUI or an experienced developer, this 
episode offers valuable insights and real-world examples you can 
apply to your own projects.
```

### 3. Social Media Posts
Platform-optimized posts with appropriate length and style:

#### X/Twitter
- 280 characters max
- Concise and punchy
- Includes key takeaways
- Optimized for engagement

#### LinkedIn
- Professional tone
- ~150-200 words
- Includes industry insights
- Good for networking and thought leadership

#### Threads/Bluesky
- Conversational style
- ~200-300 characters
- More casual than LinkedIn
- Emphasizes community engagement

**Example Output (X/Twitter):**
```
🎙️ New episode! We're exploring SwiftUI architecture patterns and 
sharing real-world tips for building production apps. Perfect for 
iOS devs looking to level up their SwiftUI skills. 

Key topics: MVVM, state management, Core Data integration
#SwiftUI #iOSDev
```

### 4. Chapter Markers
Auto-detect natural chapter breaks in your transcript:
- Timestamp in SRT format (HH:MM:SS)
- Chapter title (concise, descriptive)
- Brief description of chapter content
- Organized chronologically

**Example Output:**
```
00:00:00 - Introduction
Welcome and overview of today's topics on SwiftUI architecture

00:05:23 - MVVM Pattern Explained
Deep dive into the Model-View-ViewModel pattern and why it works well with SwiftUI

00:15:47 - State Management
Exploring @State, @Binding, @StateObject, and when to use each

00:28:12 - Core Data Integration
Step-by-step guide to adding persistent storage to your SwiftUI app

00:42:55 - Wrap-up and Resources
Final thoughts and links to code examples and documentation
```

## How to Use

### Accessing AI Ideas

1. **Select an episode** that has a transcript
2. Click the **"AI Ideas"** tab in the episode detail pane
3. If Apple Intelligence is unavailable, you'll see an error message with instructions

### Generating Content

#### Generate Individual Content Types

1. Navigate to the section you want (Titles, Description, Social Posts, or Chapters)
2. For descriptions, select your desired length first (Short/Medium/Long)
3. Click the **"Generate"** button for that section
4. Wait for AI processing (usually 5-30 seconds depending on transcript length)
5. Review the generated content
6. Click **"Copy"** to copy to clipboard
7. Click **"Regenerate"** (↻) to generate different variations

#### Generate All Content at Once

1. Click **"Generate All"** button at the top of the view
2. All four content types will generate sequentially
3. Progress indicators show which section is currently processing
4. Generated content appears as it completes

### Working with Generated Content

**Copying:**
- Each section has a "Copy" button to copy content to clipboard
- Paste into your podcast platform, social media, or notes app

**Regenerating:**
- Click the refresh icon (↻) to generate new variations
- Useful if the first result isn't quite right
- Each regeneration uses the same transcript but creates different output

**Editing:**
- Generated content is read-only in the app (not saved to Core Data)
- Copy to clipboard and edit in your preferred text editor
- Consider this AI-generated content as a starting point for refinement

## Architecture

### Components

#### AIIdeasViewModel
Located: `ViewModels/AIIdeasViewModel.swift`

**Responsibilities:**
- Manages all AI content generation state
- Interfaces with Apple's SystemLanguageModel
- Handles transcript preprocessing
- Manages loading states and errors

**Key Properties:**
```swift
@Published public var titleSuggestions: [String]
@Published public var generatedDescription: String
@Published public var socialPosts: [SocialPost]
@Published public var chapterMarkers: [ChapterMarker]

@Published public var isGeneratingTitles: Bool
@Published public var modelAvailable: Bool
@Published public var errorMessage: String?
```

**Key Methods:**
```swift
public func generateTitles() async
public func generateDescription(length: DescriptionLength) async
public func generateSocialPosts() async
public func generateChapters() async
public func generateAllContent() async
```

#### AIIdeasView
Located: `Views/AIIdeasView.swift`

**Structure:**
- Four-section scrollable layout
- Empty state when no transcript available
- Error state when Apple Intelligence unavailable
- Progress indicators during generation
- Copy buttons for each generated content type

#### TranscriptCleaner
Located: `Services/TranscriptCleaner.swift`

**Purpose:**
- Prepares transcript text for AI processing
- Removes timestamps and speaker labels
- Cleans up formatting artifacts
- Preserves paragraph structure

### Data Flow

```
Episode Transcript
    ↓
TranscriptCleaner (remove timestamps/speakers)
    ↓
AIIdeasViewModel (prepare prompts)
    ↓
SystemLanguageModel.generate() [on-device AI]
    ↓
Parsed & Formatted Results
    ↓
Published to View
    ↓
User copies to clipboard
```

### Privacy & Security

**All processing is on-device:**
- No data sent to external servers
- No API keys or accounts needed
- No internet connection required (after initial model download)
- Your podcast content stays on your Mac

**Data Storage:**
- Generated content is **NOT saved** to Core Data
- Content exists only in memory during the session
- Regenerating content creates new results
- Closing the view discards all generated content

**Why not save AI content?**
- Keeps the app lightweight and focused on production tools
- Prevents database bloat with experimental content
- Encourages users to review and edit before publishing
- Users can copy content to their preferred editing tools

## System Requirements

### Checking Apple Intelligence Availability

The app automatically checks if Apple Intelligence is available:

```swift
let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // AI features enabled
case .unavailable(let reason):
    // Show error message with reason
}
```

### Common Availability Issues

**"Apple Intelligence unavailable: unsupported"**
- Your Mac doesn't support Apple Intelligence
- Requires Apple Silicon (M1 or later) with sufficient RAM
- macOS 26.0 or later

**Solution:** Upgrade to a supported Mac or use a different feature

**"Model not downloaded"**
- Apple Intelligence is supported but models aren't installed
- May require enabling Apple Intelligence in System Settings

**Solution:**
1. Open System Settings > Apple Intelligence
2. Enable Apple Intelligence
3. Wait for models to download (can be several GB)
4. Restart Podcast Assistant

### Performance Expectations

**Generation Times:**
- Titles: 5-15 seconds
- Description: 10-20 seconds
- Social Posts: 15-25 seconds
- Chapters: 20-40 seconds (depends on transcript length)
- Generate All: 60-120 seconds total

**Factors affecting speed:**
- Transcript length (longer = slower)
- System load (other apps using resources)
- First generation after model download (may be slower)
- Mac model (M2/M3 faster than M1)

## Prompts & Customization

### Current Prompt Engineering

The app uses carefully crafted prompts optimized for podcast content:

**Title Generation Prompt:**
```
Create 3 catchy, concise podcast episode titles based on this transcript.
Requirements:
- Each title should be under 80 characters
- Make them engaging and descriptive
- Capture the main topic and value proposition
- Vary the style and approach
```

**Description Generation Prompt (varies by length):**
```
Write a [short/medium/long] podcast episode description based on this transcript.
Requirements:
- [Length-specific requirements]
- Write in second person ("you'll learn...")
- Focus on listener value and takeaways
- Professional yet conversational tone
```

### Future Customization Options

Potential enhancements for future versions:
- Custom prompt templates
- Tone adjustment (casual, professional, technical)
- Audience targeting (beginners, advanced, mixed)
- Keyword inclusion requirements
- Brand voice guidelines
- Custom output formats

## Limitations

### Current Limitations

1. **In-Memory Only**
   - Generated content not persisted
   - Lost when closing view
   - Must copy to clipboard to save

2. **No Editing UI**
   - Can't edit generated content directly
   - Must copy and edit externally
   - Regeneration creates entirely new content

3. **Single Language**
   - Currently generates content in transcript's language
   - No automatic translation of AI-generated content
   - (Use Episode Translation feature separately for multilingual content)

4. **Transcript Required**
   - Can't generate content without a transcript
   - Quality depends on transcript quality
   - Garbage in, garbage out

5. **Model Availability**
   - Requires Apple Silicon Mac
   - Requires macOS 26+
   - May not work in some regions or configurations

### Workarounds

**Saving Generated Content:**
- Copy to Notes app for persistence
- Paste into a text file
- Use a clipboard manager
- Screenshot for reference

**Editing AI Content:**
- Copy to your favorite text editor
- Use macOS TextEdit for quick edits
- Paste into podcast platform for final editing

**Multiple Generations:**
- Regenerate multiple times
- Copy each variation to compare
- Mix and match the best parts

## Troubleshooting

### "No Transcript Available"

**Problem:** AI Ideas view shows empty state

**Solutions:**
1. Add a transcript to the episode:
   - Go to "Transcript" tab
   - Import a text file, or
   - Paste transcript content directly
2. Ensure transcript has actual content (not just whitespace)
3. Save the episode (happens automatically)

### "Apple Intelligence unavailable"

**Problem:** Red error banner at top of view

**Solutions:**
1. Check macOS version: Must be 26.0 or later
2. Verify Mac hardware: Apple Silicon (M1+) required
3. Enable Apple Intelligence:
   - System Settings > Apple Intelligence
   - Toggle on and download models
4. Restart Podcast Assistant after enabling

### Generation Fails or Hangs

**Problem:** Click "Generate" but nothing happens or spinner runs indefinitely

**Solutions:**
1. Check system resources in Activity Monitor
2. Close other resource-intensive apps
3. Try generating a single section instead of "Generate All"
4. Restart Podcast Assistant
5. Check Console app for error messages

### Generated Content is Poor Quality

**Problem:** AI generates irrelevant or low-quality content

**Solutions:**
1. **Improve transcript quality:**
   - Ensure transcript is clean and properly formatted
   - Remove excessive timestamps or technical artifacts
   - Fix obvious transcription errors
2. **Try regenerating:**
   - Click refresh icon (↻) multiple times
   - AI may produce better results on subsequent attempts
3. **Check transcript length:**
   - Very short transcripts (< 500 words) may not provide enough context
   - Very long transcripts (> 10,000 words) may be too complex
4. **Use as a starting point:**
   - AI content is meant to be edited and refined
   - Treat it as a first draft, not final copy

## Best Practices

### Getting the Best Results

1. **Use Clean Transcripts:**
   - Remove unnecessary timestamps
   - Fix obvious transcription errors
   - Ensure proper paragraph breaks
   - Use the TranscriptCleaner service (automatic)

2. **Generate Multiple Variations:**
   - Click regenerate 2-3 times
   - Compare results and pick the best
   - Mix and match parts from different generations

3. **Edit Before Publishing:**
   - AI content is a starting point
   - Add your personal voice
   - Fact-check key claims
   - Adjust tone to match your brand

4. **Start with Specific Sections:**
   - Generate titles first for quick wins
   - Use chapters to understand flow
   - Generate descriptions last after reviewing titles

5. **Use Appropriate Description Length:**
   - **Short**: Social media, YouTube descriptions
   - **Medium**: Podcast platforms (default choice)
   - **Long**: Blog posts, newsletters, detailed show notes

### Workflow Recommendations

**Efficient Content Creation Flow:**

1. **Record and transcribe** your episode
2. **Import transcript** to episode
3. **Generate titles** - pick the best one
4. **Generate chapters** - review episode structure
5. **Generate description** (medium length)
6. **Generate social posts** for each platform
7. **Copy all content** to your content management tool
8. **Edit and refine** before publishing
9. **Use variations** for A/B testing or multi-platform differences

**Time Savings:**
- Manual content creation: 30-60 minutes per episode
- AI-assisted creation: 5-10 minutes per episode
- **Savings: ~80-90% reduction in time**

## Integration with Other Features

### Transcript Feature
- AI Ideas requires a transcript
- Use the Transcript tab to import or paste transcript content
- Transcript conversion (to SRT) is independent of AI Ideas

### Translation Feature
- AI-generated content can be translated using Episode Translation
- Copy AI content to episode description
- Use Episode Translation feature to translate to other languages
- **Note**: Translating the episode translates title/description, not AI-generated content stored in clipboard

### Thumbnail Feature
- Use generated titles for consistent branding
- AI chapters can help select thumbnail moments
- Independent features—use together for complete episode setup

## Technical Details

### Apple Intelligence Models

**Model Used:** `SystemLanguageModel.default`

**Capabilities:**
- Text generation and completion
- Context-aware responses
- Natural language understanding
- Multi-turn conversations
- Structured output parsing

**Limitations:**
- Fixed model (no selection/customization)
- No fine-tuning or training
- Output length limits
- Processing time varies by complexity

### Error Handling

The app handles several error scenarios:

```swift
// Model availability check
switch model.availability {
case .available:
    modelAvailable = true
case .unavailable(let reason):
    errorMessage = "Apple Intelligence unavailable: \(reason)"
}

// Generation errors
do {
    let response = try await model.generate(prompt)
    // Process response
} catch {
    errorMessage = "Generation failed: \(error.localizedDescription)"
}
```

### Memory Management

**Considerations:**
- Large transcripts can use significant memory
- AI model loads into memory on first use
- Generated content kept in memory until view closes
- No disk caching of AI responses

**Optimization:**
- TranscriptCleaner reduces text size before processing
- Lazy view initialization
- Results cleared when view dismissed

## Future Enhancements

### Planned Features

1. **Content Persistence**
   - Save generated content to Core Data
   - Version history for AI generations
   - Compare multiple generations side-by-side

2. **Custom Prompts**
   - User-defined prompt templates
   - Tone and style customization
   - Industry-specific terminology

3. **Batch Processing**
   - Generate content for multiple episodes
   - Bulk export of AI content
   - Queue management for long operations

4. **Quality Metrics**
   - Content scoring and feedback
   - Learn from user preferences
   - Suggest improvements

5. **Template Library**
   - Pre-built prompts for common scenarios
   - Community-contributed templates
   - Import/export prompt configurations

6. **Export Integration**
   - Direct export to podcast platforms
   - Social media API integration
   - Automated posting workflows

## Resources

### Learn More About Apple Intelligence

- [Apple Intelligence Overview](https://www.apple.com/apple-intelligence/)
- [FoundationModels Framework Documentation](https://developer.apple.com/documentation/FoundationModels)
- [SystemLanguageModel Reference](https://developer.apple.com/documentation/FoundationModels/SystemLanguageModel)

### Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture and data flow
- [SETTINGS.md](SETTINGS.md) - Settings and customization options
- [TRANSLATION.md](TRANSLATION.md) - Episode translation features

### Getting Help

If you encounter issues:
1. Check this documentation
2. Review error messages in the app
3. Check macOS Console app for detailed logs
4. File an issue on GitHub with details about your setup and the problem
