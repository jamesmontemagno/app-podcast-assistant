# Transcript Shrinking Implementation History

## Current Implementation (November 2025)

The transcript shrinker has been **completely replaced** with a simpler implementation based on [praeclarum/TranscriptSummarizer](https://github.com/praeclarum/TranscriptSummarizer).

**See [`TRANSCRIPT_SHRINKER.md`](TRANSCRIPT_SHRINKER.md) for current documentation.**

## Changes from Previous Implementation

### What Was Removed (~600 lines)

1. **Multi-pass deduplication and merging** - Complex similarity-based deduplication
2. **Target segment count enforcement** - Iterative merging to hit specific count
3. **Time-proximity based merging** - Complex algorithm for merging by time gaps
4. **Refined segment conversion** - Extra layer converting condensed to refined segments
5. **Complex configuration** - Multiple tuning parameters (similarity threshold, min seconds, etc.)
6. **Overlap skipping logic** - Complex character-based skip calculation

### What Was Added/Simplified

1. **Direct parsing** - Parse `timestamp\nspeaker\ntext\n\n` format directly
2. **Simple windowing** - Character-based with percentage overlap
3. **Direct summarization** - Windows → Summaries (one LLM call per window)
4. **Cleaner prompts** - Based on proven examples from reference implementation
5. **Simpler configuration** - Just `maxWindowCharacters` and `overlap` percentage

### Key Architectural Changes

**Before:**
```
Raw Transcript 
  → Parse (complex regex) 
  → Window (fixed segment count)
  → Condense (LLM)
  → Merge Windows (complex overlap skip)
  → Deduplicate (similarity scoring)
  → Merge Adjacent (iterative, threshold-based)
  → Merge by Time (if still over target)
  → Convert to Refined
  → Output
```

**After:**
```
Raw Transcript
  → Parse (simple split on \n\n)
  → Window (character-based with overlap)
  → Summarize (LLM)
  → Output
```

### Benefits of New Implementation

✅ **Simpler code**: ~600 lines removed  
✅ **More predictable**: Follows proven pattern  
✅ **Easier to maintain**: Clear, straightforward logic  
✅ **Better aligned**: Matches reference implementation  
✅ **Cleaner UI**: Direct display of segments and windows  

### Migration Guide

If you were using the old implementation:

**Old Configuration:**
```swift
let config = ShrinkConfig(
    maxWindowCharacters: 6000,
    overlapCharacters: 1000,
    targetSegmentCount: 25,
    minSecondsBetweenSegments: 20,
    similarityThreshold: 0.6
)
```

**New Configuration:**
```swift
let config = ShrinkConfig(
    maxWindowCharacters: 5000,
    overlap: 0.2  // 20% overlap
)
```

**Input Format Changed:**

Old: Flexible timestamp formats on single lines  
New: Strict `timestamp\nspeaker\ntext\n\n` format

See [`TRANSCRIPT_SHRINKER.md`](TRANSCRIPT_SHRINKER.md) for format specification.

---

## Historical Implementation Details (Pre-November 2025)

<details>
<summary>Click to view previous implementation notes</summary>

## Summary

Previous implementation incorporated best practices from [praeclarum/TranscriptSummarizer](https://github.com/praeclarum/TranscriptSummarizer) but added complex multi-pass processing.

## Key Features (Now Removed)

### 1. **Character-Based Window Sizing**

### 1. **Character-Based Window Sizing**

Used character-based window sizing with fixed character overlap.

### 2. **Multi-Pass Processing**

Used multiple passes:
- Pass 1: Parse segments
- Pass 2: Condense with sliding windows
- Pass 3: Deduplicate and merge to target count

### 3. **Complex Deduplication**

Used similarity scoring and iterative merging to reduce segment count.

</details>

---

**For current implementation details, see [`TRANSCRIPT_SHRINKER.md`](TRANSCRIPT_SHRINKER.md)**
