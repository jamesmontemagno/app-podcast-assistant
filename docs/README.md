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

### 🏗️ POCO_ARCHITECTURE.md
**Hybrid POCO/SwiftData pattern** - Critical for understanding the data layer.
- Why POCOs instead of pure SwiftData
- PodcastPOCO and EpisodePOCO explained
- PodcastLibraryStore (the bridge between UI and persistence)
- Data flow and conversion methods
- ViewModel patterns with POCOs
- Memory management and best practices

### 📁 FOLDER_STRUCTURE.md
**Code organization** - Where to find and add code.
- Complete folder hierarchy
- Models/ (POCOs, SwiftData, Supporting)
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

**Learn about the POCO pattern**
→ Read `POCO_ARCHITECTURE.md`

**Find where to add new code**
→ Read `FOLDER_STRUCTURE.md`

**Make UI that matches the app's style**
→ Read `UI_DESIGN_PATTERNS.md`

**Understand AI content generation**
→ Read `AI_IDEAS.md`

**Learn about translation features**
→ Read `TRANSLATION.md`

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
- `POCO_ARCHITECTURE.md` - Nov 10, 2025
- `FOLDER_STRUCTURE.md` - Nov 10, 2025
- `UI_DESIGN_PATTERNS.md` - Nov 10, 2025

### Updated
- `ARCHITECTURE.md` - Nov 10, 2025 (POCO architecture rewrite)

### Removed (Outdated)
- `CORE_DATA.md` - Nov 10, 2025 (obsolete, we use POCOs now)
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
**Documentation Version:** 2.0 (POCO Architecture)
