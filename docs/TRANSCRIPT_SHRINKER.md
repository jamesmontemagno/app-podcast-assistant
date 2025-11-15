# Transcript Shrinker

The Transcript Shrinker feature condenses large podcast transcripts into concise summaries while preserving key information and maintaining temporal context.

## Overview

Based on the [TranscriptSummarizer](https://github.com/praeclarum/TranscriptSummarizer) implementation by Frank A. Krueger, this feature uses Apple Intelligence (macOS 26+) to intelligently summarize transcript segments.

## How It Works

### 1. Input Format

The transcript must be in the following format:

```
<timestamp>
<speaker>
<text>

<timestamp>
<speaker>
<text>

...
```

**Example:**
```
00:00:15
Alice
Welcome to the show! Today we're discussing AI and the future of technology.

00:00:30
Bob
Thanks for having me, Alice. I'm excited to dive into this topic.

00:01:05
Alice
Let's start with the basics. What exactly is artificial intelligence?

00:01:15
Bob
Great question. AI is essentially the simulation of human intelligence by machines. This includes learning, reasoning, and self-correction.
```

**Key Format Rules:**
- Each segment is separated by a **double newline** (`\n\n`)
- Each segment has exactly 3 lines:
  1. Timestamp (format: `MM:SS` or `HH:MM:SS`)
  2. Speaker name
  3. Dialog text (can be multiple sentences)

### 2. Processing Pipeline

#### Step 1: Parsing
The transcript is parsed into structured segments containing:
- Timestamp
- Speaker name
- Dialog text

#### Step 2: Windowing
Segments are grouped into "windows" based on character count:
- **Max window size**: Configurable (default: 5000 characters)
- **Overlap**: Configurable percentage (default: 20%)
- Windows ensure context is maintained across summarization

#### Step 3: Summarization
Each window is sent to Apple Intelligence with instructions to:
- Focus on key points and main ideas
- Elide trivial exchanges (greetings, acknowledgments)
- Merge related discussions
- Preserve timestamps for reference

#### Step 4: Output
Summarized segments are displayed with:
- Original timestamp reference
- Concise summary text
- Reduction percentage

## UI Components

### Two-Column Layout

1. **Left Column: Original Transcript**
   - Editable text area for input
   - List of parsed segments
   - List of windows with metadata

2. **Right Column: Summarized Transcript**
   - List of summarized segments
   - Reduction percentage
   - Processing progress indicator

### Configuration Options

- **Max Window Characters**: Controls how many characters are processed together (affects context window)
- **Overlap Percentage**: Controls how much overlap between windows (ensures continuity)

## Usage Example

### Input Transcript
```
00:00:00
Host
Welcome everyone to episode 42 of Tech Talk!

00:00:05
Guest
Thanks for having me!

00:00:10
Host
Today we're diving deep into quantum computing.

00:01:00
Guest
Quantum computing is fascinating because it uses qubits instead of classical bits. This allows for superposition and entanglement, which enable exponentially faster computations for certain problems.

00:02:30
Host
Can you give us a practical example?

00:02:35
Guest
Sure! One major application is in cryptography. Quantum computers could potentially break current encryption methods, but they could also create unbreakable quantum encryption.
```

### Expected Output
```
From 00:00:00:
Introduction to Tech Talk episode 42, focusing on quantum computing.

From 00:01:00:
Discussion of quantum computing fundamentals: qubits, superposition, and entanglement enabling faster computations.

From 00:02:30:
Practical applications in cryptography, including both threats to current encryption and potential for quantum-safe encryption.
```

## Benefits

- **Massive Reduction**: Typically 85-90% reduction in segment count
- **Preserved Context**: Timestamps maintained for reference
- **Smart Elision**: Trivial exchanges automatically removed
- **Coherent Summaries**: Related topics merged intelligently

## Technical Details

### Architecture

- **Service**: `TranscriptionShrinkerService`
  - Parsing logic
  - Windowing algorithm
  - LLM integration
  
- **ViewModel**: `TranscriptShrinkerViewModel`
  - State management
  - UI bindings
  - Progress tracking

- **View**: `TranscriptShrinkerView`
  - Two-column layout
  - Real-time updates
  - Interactive controls

### Data Models

```swift
@Generable
struct TranscriptSegmentWithSpeaker {
    let timestamp: String
    let speaker: String
    let text: String
}

@Generable
struct TranscriptWindow {
    var segments: [TranscriptSegmentWithSpeaker]
}

@Generable
struct SummarizedSegment {
    let firstSegmentTimestamp: String
    let summary: String
}
```

## Requirements

- macOS 26.0 or later
- Apple Intelligence enabled
- Properly formatted transcript input

## Best Practices

1. **Clean Input**: Ensure transcript follows the exact format (timestamp, speaker, text with double newlines)
2. **Reasonable Window Size**: Default 5000 chars works well for most podcasts
3. **Monitor Output**: Review summaries to ensure quality
4. **Adjust Overlap**: Increase overlap if context is lost between windows

## Troubleshooting

### "No timestamped segments found"
- Check that transcript uses double newlines (`\n\n`) to separate segments
- Verify each segment has exactly 3 lines (timestamp, speaker, text)

### Poor Summary Quality
- Try adjusting window size (smaller for focused summaries, larger for context)
- Ensure input transcript has meaningful content (not just greetings)

### Processing Takes Too Long
- Reduce window size for faster processing
- Reduce overlap percentage

## Future Enhancements

- [ ] Auto-detect transcript format
- [ ] Support for additional transcript formats
- [ ] Export summaries to various formats
- [ ] Integration with chapter generation
- [ ] Customizable summarization instructions
