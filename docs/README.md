# Podcast Assistant Documentation

## Overview

This folder contains comprehensive documentation for the Podcast Assistant macOS app. The documentation is organized by topic for easy navigation.

## Core Architecture (Start Here)

### 📐 ARCHITECTURE.md
**Main architectural overview** - Start here for a high-level understanding of how the app is built.
- System architecture and key principles
- Application flow and navigation
- Core components overview
- Build configuration
- Testing strategy

### 🚀 SWIFTDATA_QUERY_ARCHITECTURE.md
**Pure SwiftData with @Query pattern** - Critical for understanding the current data layer.
- Why pure SwiftData instead of intermediate layers
- @Query reactive binding explained
- External storage for performance
- Dynamic predicates and filtering
- List selection patterns (.tag() + Hashable)
- Best practices and lessons learned

### ⚡ SWIFTDATA_BEST_PRACTICES.md
**Essential SwiftData tips and patterns** - Must-read for working with SwiftData.
- The 5 SwiftData rules (critical for success)
- "When in doubt, create a new view" pattern
- External storage for performance optimization
- Common pitfalls and how to avoid them
- Migration guide from POCO/intermediate layers
- Testing patterns and examples

### 📁 FOLDER_STRUCTURE.md
**Code organization** - Where to find and add code.
- Complete folder hierarchy
- Models/ (SwiftData, Supporting)
- Services/ (Data, UI, Utilities)
- ViewModels/
- Views/ (Forms, Sections, Sheets)
- File naming conventions
- Adding new features guide

### 🎨 UI_DESIGN_PATTERNS.md
**Consistent design system** - How to build UI that matches the app's polish.
- Core design principles
- Standard patterns (modals, forms, errors, images, etc.)
- Component library (buttons, text fields, pickers, toggles)
- Color palette and typography
- Layout guidelines and spacing
- Animation patterns
- Testing checklist

## Feature Documentation

### 🤖 AI_IDEAS.md
**AI content generation** (macOS 26+ only)
- Apple Intelligence integration
- Title, description, social post, and chapter generation
- System requirements and setup
- Usage workflows
- Troubleshooting

### 🌐 TRANSLATION.md
**SRT and episode translation** (macOS 26+ only)
- SRT subtitle translation
- Episode title/description translation
- Supported languages (12+)
- Language pack installation
- Usage workflows
- Best practices and troubleshooting

### 🔬 TRANSCRIPT_SHRINKER.md
**Transcript summarization** (macOS 26+ only)
- AI-powered transcript condensation
- Input format requirements (timestamp/speaker/text)
- Windowing and summarization algorithm
- Usage examples and best practices
- Based on TranscriptSummarizer reference implementation

### ⚙️ SETTINGS.md
**Settings and customization**
- About section
- Appearance (theme selection)
- Font management
- Architecture details
- Integration points
- Technical notes

### 📱 SETTINGS_UI.md
**Settings UI mockups**
- Visual layouts
- Empty states
- Error/success states
- Theme variations
- Color legend

### 📋 SETTINGS_QUICKREF.md
**Quick reference** for settings feature
- What was added
- How to use
- Files changed
- Code stats
- Technical notes

## Documentation Navigation

### I want to...

**Understand the overall architecture**
→ Read `ARCHITECTURE.md` first

**Learn about the pure SwiftData @Query pattern**
→ Read `SWIFTDATA_QUERY_ARCHITECTURE.md` then `SWIFTDATA_BEST_PRACTICES.md`

**Find where to add new code**
→ Read `FOLDER_STRUCTURE.md`

**Make UI that matches the app's style**
→ Read `UI_DESIGN_PATTERNS.md`

**Understand AI content generation**
→ Read `AI_IDEAS.md`

**Learn about translation features**
→ Read `TRANSLATION.md`

**Use transcript summarization**
→ Read `TRANSCRIPT_SHRINKER.md`

**Customize app settings**
→ Read `SETTINGS.md`

**See settings UI mockups**
→ Read `SETTINGS_UI.md`

**Quick settings reference**
→ Read `SETTINGS_QUICKREF.md`

## Documentation Standards

All documentation follows these principles:

1. **Comprehensive** - Cover all aspects of the feature/pattern
2. **Code examples** - Show real implementation patterns
3. **Visual aids** - Use ASCII diagrams where helpful
4. **Practical** - Focus on how-to and best practices
5. **Up-to-date** - Reflects current implementation (as of Nov 2025)

## Updating Documentation

When making significant changes to the app:

1. **Update relevant docs** - Don't let docs become stale
2. **Add examples** - Show the new pattern/feature
3. **Update diagrams** - If architecture changes
4. **Cross-reference** - Link related docs together
5. **Test code examples** - Ensure they compile and work

## File History

### Created
- `SWIFTDATA_QUERY_ARCHITECTURE.md` - Nov 10, 2025 (Pure SwiftData approach)
- `SWIFTDATA_BEST_PRACTICES.md` - Nov 10, 2025 (Essential SwiftData patterns)
- `FOLDER_STRUCTURE.md` - Nov 10, 2025
- `UI_DESIGN_PATTERNS.md` - Nov 10, 2025

### Updated
- `ARCHITECTURE.md` - Nov 10, 2025
- `FOLDER_STRUCTURE.md` - Nov 10, 2025 (removed POCOs section)

### Removed (Outdated/Superseded)
- `POCO_ARCHITECTURE.md` - Nov 10, 2025 (superseded by pure SwiftData approach)
- `CORE_DATA.md` - Nov 10, 2025 (obsolete, never used Core Data)
- `IMPLEMENTATION_SUMMARY.md` - Nov 10, 2025 (obsolete)
- `LAZY_LOADING_FLOW.md` - Nov 10, 2025 (implementation detail, not needed)
- `NAVIGATION_ANALYSIS.md` - Nov 10, 2025 (old performance analysis)
- `NAVIGATION_CRASH_FIX.md` - Nov 10, 2025 (bug fix doc, resolved)
- `TESTING_LAZY_LOADING.md` - Nov 10, 2025 (testing doc for old feature)

### Kept (Still Relevant)
- `AI_IDEAS.md` - Nov 9, 2025 (accurate)
- `TRANSLATION.md` - Nov 9, 2025 (accurate)
- `SETTINGS.md` - Nov 9, 2025 (accurate)
- `SETTINGS_UI.md` - Nov 9, 2025 (accurate)
- `SETTINGS_QUICKREF.md` - Nov 9, 2025 (accurate)

## Documentation TODOs

Future documentation to consider:

- [ ] TESTING.md - Comprehensive testing guide
- [ ] PERFORMANCE.md - Performance optimization patterns
- [ ] DEPLOYMENT.md - Build, notarization, distribution
- [ ] CONTRIBUTING.md - How to contribute to the project
- [ ] TROUBLESHOOTING.md - Common issues and solutions

---

**Last Updated:** November 10, 2025  
**Documentation Version:** 3.0 (Pure SwiftData with @Query)
