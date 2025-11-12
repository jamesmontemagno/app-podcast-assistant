# Transcript Shrinking Improvements

## Summary

Incorporated best practices from [praeclarum/TranscriptSummarizer](https://github.com/praeclarum/TranscriptSummarizer) to improve `TranscriptionShrinkerService` window creation and overlap handling.

## Key Improvements

### 1. **Character-Based Window Sizing** (vs Fixed Segment Count)

**Previous Approach:**
- Fixed segment count per window (e.g., 30 segments)
- Didn't account for variable segment lengths
- Could create windows with wildly different total content sizes

**New Approach:**
```swift
public struct ShrinkConfig {
    /// Maximum characters per window (estimated JSON size)
    public var maxWindowCharacters: Int = 6000
    
    /// Overlap size in characters for context preservation
    public var overlapCharacters: Int = 1000
}
```

**Benefits:**
- ✅ **Adaptive sizing**: Handles variable-length segments naturally
- ✅ **Consistent LLM context**: Each window has similar total content size
- ✅ **Better performance**: Avoids overloading LLM with too much text or under-utilizing with too little

### 2. **Backfill Overlap Strategy** (vs Skip-Forward)

**Previous Approach:**
- Skip forward segments by percentage when merging windows
- Example: Skip 50% of next window's segments

**New Approach:**
```swift
// Create overlap by backfilling segments from previous window
var newWindow: [TranscriptSegment] = []
var overlapCount = 0
var backIndex = nextSegmentIndex - 1

while overlapCount < overlapCharacters && backIndex >= 0 {
    let overlapSegment = currentWindow[...]
    newWindow.insert(overlapSegment, at: 0)
    overlapCount += overlapCharCount
    backIndex -= 1
}
```

**Benefits:**
- ✅ **Better context preservation**: Guarantees specific amount of overlap
- ✅ **Smooth transitions**: LLM sees same content in consecutive windows
- ✅ **More predictable**: Character-based overlap is consistent regardless of segment distribution

### 3. **Character Count Estimation**

Added `estimateCharCount()` helper:
```swift
private func estimateCharCount(_ segments: [TranscriptSegment]) -> Int {
    segments.reduce(0) { sum, segment in
        // Estimate: timestamp (10) + text + JSON overhead (50)
        sum + segment.timestamp.count + segment.text.count + 60
    } + 20 // Window overhead
}
```

**Benefits:**
- ✅ **Accurate sizing**: Accounts for JSON serialization overhead
- ✅ **Better logging**: Shows estimated character count per window
- ✅ **Tunable limits**: Easy to adjust based on LLM context window size

## Configuration Changes

### Before:
```swift
let config = ShrinkConfig(
    windowSize: 50,              // Fixed segment count
    overlapPercentage: 0.4,      // 40% overlap by segment count
    targetSegmentCount: 25
)
```

### After:
```swift
let config = ShrinkConfig(
    maxWindowCharacters: 6000,   // ~6KB per window
    overlapCharacters: 1000,     // ~1KB overlap
    targetSegmentCount: 25
)
```

### Presets by Use Case:

**Chapter Generation** (ChapterGenerationService):
```swift
maxWindowCharacters: 8000,    // Larger windows for more context
overlapCharacters: 1500,      // More overlap for topic continuity
```

**General Shrinking** (TranscriptShrinkerViewModel):
```swift
maxWindowCharacters: 6000,    // Balanced
overlapCharacters: 1000       // 15-20% overlap
```

## Implementation Details

### Window Creation Algorithm

1. **Build windows dynamically**:
   - Start with empty window
   - Add segments until character limit reached
   - Create new window with overlap from previous

2. **Overlap handling**:
   - Backfill segments from end of previous window
   - Continue until overlap character target reached
   - Ensures smooth context transition

3. **Merge windows**:
   - First window: Take all segments
   - Subsequent windows: Skip overlap portion based on character estimation
   - Deduplicate similar segments in Pass 3

### Backward Compatibility

UI sliders in `TranscriptShrinkerViewModel` convert to character-based config:
```swift
// windowSize slider (10-100) → maxWindowCharacters (2000-12000)
let maxChars = Int(windowSize) * 120  // ~120 chars per "segment unit"

// overlapPercent slider (20-80) → overlapCharacters
let overlapChars = Int((overlapPercent / 100.0) * Double(maxChars))
```

This maintains existing UI behavior while using improved algorithm under the hood.

## Performance Impact

**Expected improvements:**
- 🚀 **More consistent window sizes**: Reduces variance in processing time
- 🎯 **Better quality**: Character-based overlap preserves more context
- 📊 **Predictable behavior**: Easier to tune for different transcript types

**Trade-offs:**
- Slightly more complex window creation logic
- Minor overhead from character counting (negligible)

## Testing Recommendations

1. **Test with variable-length segments**:
   - Short exchanges (1-2 sentences each)
   - Long monologues (multiple paragraphs)
   - Mixed content

2. **Verify overlap quality**:
   - Check that consecutive windows share meaningful context
   - Ensure no duplicate content in final output (Pass 3 deduplication)

3. **Compare configurations**:
   - Try different maxWindowCharacters (4000-10000)
   - Adjust overlapCharacters (500-2000)
   - Measure quality of resulting segments

## References

- **Source**: [TranscriptSummarizer/TranscriptView.swift](https://github.com/praeclarum/TranscriptSummarizer/blob/main/TranscriptSummarizer/TranscriptView.swift)
- **Pattern**: Character-based windowing with backfill overlap
- **Inspiration**: Production-tested approach for WWDC transcript summarization

## Future Enhancements

Potential improvements identified but not yet implemented:

1. **Progress Tracking**: Add per-window progress updates
   ```swift
   summaryProgress = Float(windowsProcessed) / Float(totalWindows)
   ```

2. **Dynamic Window Sizing**: Adjust window size based on content density
   - Larger windows for sparse content
   - Smaller windows for dense technical discussions

3. **Smart Overlap**: Vary overlap based on topic continuity
   - More overlap when topic shifts detected
   - Less overlap within same topic

## Migration Notes

**Breaking Changes:**
- `ShrinkConfig.windowSize` → `ShrinkConfig.maxWindowCharacters`
- `ShrinkConfig.overlapPercentage` → `ShrinkConfig.overlapCharacters`

**Updated Files:**
- `/Services/AI/TranscriptionShrinkerService.swift` - Core algorithm
- `/Services/AI/ChapterGenerationService.swift` - Chapter-specific config
- `/ViewModels/TranscriptShrinkerViewModel.swift` - UI slider mapping

**No UI Changes**: Existing UI continues to work with conversion layer.
