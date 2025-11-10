# UI Design Patterns - Consistent Visual Language

## Overview

Podcast Assistant uses a consistent, polished design system across all views, forms, and sheets. This document outlines the visual patterns, components, and styling conventions that create a cohesive user experience.

## Core Design Principles

### 1. Visual Hierarchy
- **Bold headers** (.title2, .fontWeight(.bold)) for section titles
- **Secondary text** for descriptions and hints
- **Dividers** to separate logical sections
- **Spacing: 0** at root to control layout precisely

### 2. Consistent Spacing
- **24px padding** for form content areas
- **16px padding** for button bars
- **12px spacing** between related elements
- **20px top padding** for modal headers

### 3. Professional Polish
- **Rounded corners** (12px) on images and previews
- **Shadows** for depth and elevation
- **Hover states** for interactive elements
- **Animations** for state changes

### 4. Error Handling
- **Colored backgrounds** (red/green) for status messages
- **Tinted text** for error states
- **Auto-dismiss** for success messages (3 seconds)
- **Manual dismiss** for errors

## Standard Patterns

### Pattern 1: Modal Sheet Structure

**Used in:** SettingsView, PodcastFormView, EpisodeFormView, Translation Sheets

```swift
VStack(spacing: 0) {
    // Header Section
    VStack(spacing: 8) {
        Text("Sheet Title")
            .font(.title2)
            .fontWeight(.bold)
        Text("Descriptive subtitle explaining purpose")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 20)
    .padding(.bottom, 12)
    
    Divider()
    
    // Content Area
    ScrollView {
        Form {
            // Form content...
        }
        .formStyle(.grouped)
        .padding(24)
    }
    
    // Bottom Button Bar
    Divider()
    
    HStack {
        Button("Cancel") { dismiss() }
            .buttonStyle(.bordered)
        
        Spacer()
        
        Button("Save") { saveAction() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
    .padding(16)
    .background(Color(NSColor.windowBackgroundColor))
}
.frame(minWidth: 500, minHeight: 400)
```

**Key Elements:**
- `VStack(spacing: 0)` - Root container with no spacing
- Header with bold title + secondary subtitle
- Dividers separating sections
- ScrollView for content area
- Bottom button bar with gray background
- `.borderedProminent` for primary actions
- `.bordered` for secondary actions
- `.controlSize(.large)` for important buttons

### Pattern 2: Form Sections

**Used in:** SettingsView, PodcastFormView, EpisodeFormView

```swift
Form {
    Section {
        Text("Section description or instructions")
            .foregroundStyle(.secondary)
    }
    
    Section {
        // Form fields...
        TextField("Field Name", text: $value, prompt: Text("Placeholder text"), axis: .vertical)
            .textFieldStyle(.roundedBorder)
        
        Picker("Selection", selection: $selectedValue) {
            ForEach(options) { option in
                Text(option.name).tag(option)
            }
        }
        
    } header: {
        Text("Section Header")
    } footer: {
        Text("Helpful explanation of what this section does")
            .font(.caption)
    }
}
.formStyle(.grouped)
.padding(24)
```

**Key Elements:**
- `.formStyle(.grouped)` - macOS native grouped form style
- Header and footer text for context
- Secondary text for descriptions
- Placeholder text on TextFields
- 24px padding around entire form

### Pattern 3: Error/Success Messages

**Used in:** All forms and sheets

```swift
// Error Message
if let errorMessage = viewModel.errorMessage {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        Text(errorMessage)
            .font(.callout)
        Spacer()
        Button("Dismiss") {
            viewModel.errorMessage = nil
        }
        .buttonStyle(.plain)
    }
    .padding(12)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
}

// Success Message
if let successMessage = viewModel.successMessage {
    HStack {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        Text(successMessage)
            .font(.callout)
    }
    .padding(12)
    .background(Color.green.opacity(0.1))
    .cornerRadius(8)
    .onAppear {
        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            viewModel.successMessage = nil
        }
    }
}
```

**Key Elements:**
- Icon with matching color (red/green)
- Tinted background (.opacity(0.1))
- Rounded corners (8px)
- Dismiss button for errors
- Auto-dismiss for success (3 seconds)

### Pattern 4: Image Previews

**Used in:** PodcastFormView, ThumbnailView

```swift
if let image = artworkImage {
    Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: 200, maxHeight: 200)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
} else {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color.secondary.opacity(0.1))
        .frame(width: 200, height: 200)
        .overlay {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No image selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
}
```

**Key Elements:**
- 12px rounded corners
- Subtle shadow for depth
- Placeholder with icon when empty
- Aspect ratio maintained
- Max dimensions for consistency

### Pattern 5: Toolbar Buttons

**Used in:** EpisodeDetailView, TranscriptView, ThumbnailView

```swift
.toolbar {
    ToolbarItemGroup(placement: .automatic) {
        if selectedSection == .thumbnail {
            Button {
                viewModel.generateThumbnail()
            } label: {
                Label("Generate", systemImage: "wand.and.stars")
            }
            .keyboardShortcut("g", modifiers: [.command])
            
            Button {
                viewModel.exportThumbnail()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.generatedThumbnail == nil)
            
            Button(role: .destructive) {
                viewModel.resetAll()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
        }
    }
}
```

**Key Elements:**
- Grouped by context (if selectedSection == ...)
- Icons with labels for clarity
- Keyboard shortcuts for common actions
- Disabled state for unavailable actions
- Destructive role for reset/delete actions

### Pattern 6: Tabbed Content

**Used in:** SettingsView, PodcastFormView

```swift
TabView(selection: $selectedTab) {
    GeneralSettingsTab()
        .tabItem {
            Label("General", systemImage: "gear")
        }
        .tag(SettingsTab.general)
    
    AppearanceSettingsTab()
        .tabItem {
            Label("Appearance", systemImage: "paintbrush")
        }
        .tag(SettingsTab.appearance)
}
.padding(.top, 20)
```

**Alternative: Segmented Picker**
```swift
Picker("", selection: $selectedTab) {
    Text("Basic Info").tag(FormTab.basic)
    Text("Artwork").tag(FormTab.artwork)
    Text("Thumbnail Defaults").tag(FormTab.thumbnailDefaults)
}
.pickerStyle(.segmented)
.labelsHidden()
.padding()
```

**Key Elements:**
- Icons in tab items for visual clarity
- Tags for selection binding
- 20px top padding for TabView
- Segmented picker for horizontal tabs

### Pattern 7: Progress Indicators

**Used in:** Translation sheets, ThumbnailView

```swift
if viewModel.isLoading {
    VStack(spacing: 16) {
        ProgressView()
            .scaleEffect(1.5)
            .controlSize(.large)
        Text("Generating thumbnail...")
            .font(.headline)
            .foregroundStyle(.secondary)
        
        // Optional: Progress bar
        if let progress = viewModel.progress {
            ProgressView(value: progress) {
                Text("\(Int(progress * 100))% complete")
                    .font(.caption)
            }
            .progressViewStyle(.linear)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
}
```

**Key Elements:**
- Centered in available space
- 1.5x scale for visibility
- Descriptive text below spinner
- Optional progress bar with percentage
- Large padding for breathing room

### Pattern 8: Side-by-Side Layouts

**Used in:** TranscriptView, ThumbnailView

```swift
HSplitView {
    // Left pane
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Controls and inputs...
        }
        .padding()
    }
    .frame(minWidth: 300, idealWidth: 400)
    
    // Right pane
    ScrollView {
        VStack(spacing: 16) {
            // Preview or output...
        }
        .padding()
    }
    .frame(minWidth: 300)
}
```

**Key Elements:**
- `HSplitView` for resizable split
- Independent `ScrollView` for each pane
- Minimum widths to prevent collapse
- Padding inside ScrollView (not on HSplitView)

## Component Library

### Buttons

#### Primary Action Button
```swift
Button("Save") { action() }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .keyboardShortcut(.defaultAction)
```

#### Secondary Action Button
```swift
Button("Cancel") { action() }
    .buttonStyle(.bordered)
    .controlSize(.regular)
```

#### Destructive Button
```swift
Button("Delete", role: .destructive) { action() }
    .buttonStyle(.bordered)
```

#### Icon Button (Toolbar)
```swift
Button {
    action()
} label: {
    Label("Action Name", systemImage: "icon.name")
}
.help("Tooltip text")
```

### Text Fields

#### Single Line
```swift
TextField("Label", text: $value, prompt: Text("Placeholder"))
    .textFieldStyle(.roundedBorder)
```

#### Multi-line
```swift
TextField("Label", text: $value, prompt: Text("Placeholder"), axis: .vertical)
    .textFieldStyle(.roundedBorder)
    .lineLimit(3...6)
```

#### With Footer
```swift
VStack(alignment: .leading, spacing: 4) {
    TextField("Label", text: $value)
    Text("Helper text explaining the field")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### Pickers

#### Dropdown
```swift
Picker("Label", selection: $selectedValue) {
    ForEach(options) { option in
        Text(option.name).tag(option)
    }
}
.pickerStyle(.menu)
```

#### Segmented
```swift
Picker("", selection: $selectedValue) {
    Text("Option 1").tag(Value.option1)
    Text("Option 2").tag(Value.option2)
}
.pickerStyle(.segmented)
.labelsHidden()
```

### Toggles

#### Standard
```swift
Toggle("Enable feature", isOn: $enabled)
    .toggleStyle(.switch)
```

#### With Description
```swift
Toggle(isOn: $enabled) {
    VStack(alignment: .leading, spacing: 4) {
        Text("Feature Name")
            .font(.body)
        Text("Description of what this does")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
.toggleStyle(.switch)
```

## Color Palette

### Semantic Colors

```swift
// Backgrounds
Color(NSColor.windowBackgroundColor)      // Main background
Color(NSColor.controlBackgroundColor)     // Control background
Color.secondary.opacity(0.1)              // Subtle background

// Text
.foregroundStyle(.primary)                // Primary text (default)
.foregroundStyle(.secondary)              // Secondary text (hints, captions)

// Status
Color.red.opacity(0.1)                    // Error background
Color.green.opacity(0.1)                  // Success background
Color.orange.opacity(0.1)                 // Warning background
Color.blue                                // Accent/links

// Text Colors
.foregroundStyle(.red)                    // Error text
.foregroundStyle(.green)                  // Success text
.foregroundStyle(.orange)                 // Warning text
```

### Usage Guidelines

- **Primary text**: Default for main content
- **Secondary text**: Descriptions, hints, placeholders
- **Tinted backgrounds**: Status messages (10% opacity)
- **Solid colors**: Icons, emphasis
- **System colors**: Respect user's appearance settings

## Typography Scale

### Headers
```swift
.font(.largeTitle)        // Very large headers (rare)
.font(.title)             // Large headers
.font(.title2)            // Standard headers (most modals)
.font(.title3)            // Subsection headers
.fontWeight(.bold)        // Bold for headers
```

### Body
```swift
.font(.body)              // Default body text
.font(.callout)           // Slightly larger emphasis
.font(.subheadline)       // Slightly smaller, subtle
.font(.caption)           // Small text (helpers, footnotes)
.font(.caption2)          // Very small (rarely used)
```

### Special
```swift
.font(.headline)          // Bold body text
.font(.footnote)          // Fine print
.fontWeight(.semibold)    // Medium emphasis
.fontWeight(.regular)     // Default weight
```

## Layout Guidelines

### Spacing Scale

```swift
0px   - Root VStack (spacing: 0) for precise control
4px   - Very tight spacing (within a component)
8px   - Tight spacing (related elements)
12px  - Standard spacing (form fields)
16px  - Comfortable spacing (sections)
20px  - Generous spacing (modal headers)
24px  - Large spacing (form padding)
40px  - Extra large (loading states)
```

### Padding Scale

```swift
.padding(4)   - Minimal padding
.padding(8)   - Tight padding (badges)
.padding(12)  - Standard padding (status messages)
.padding(16)  - Comfortable padding (button bars)
.padding(24)  - Large padding (form content)
.padding(40)  - Extra large (loading states)
```

### Corner Radius Scale

```swift
4px   - Small corners (tags, badges)
8px   - Standard corners (status messages, cards)
12px  - Large corners (images, previews)
16px  - Extra large corners (modals - rarely used)
```

## Animation Guidelines

### Standard Animations

```swift
// Smooth state changes
.animation(.easeInOut(duration: 0.2), value: someState)

// Auto-dismiss with delay
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        // Dismiss action
    }
}

// Hover effects
.onHover { isHovered in
    withAnimation(.easeInOut(duration: 0.15)) {
        self.isHovered = isHovered
    }
}
```

### Loading States

```swift
// Spinner with scale
ProgressView()
    .scaleEffect(1.5)
    .controlSize(.large)

// Progress bar
ProgressView(value: progress)
    .progressViewStyle(.linear)
```

## Accessibility

### Best Practices

1. **Labels for all controls**
```swift
Button { action() } label: {
    Label("Descriptive Name", systemImage: "icon")
}
```

2. **Help text for icons**
```swift
Button { action() } label: {
    Image(systemName: "icon")
}
.help("Tooltip explaining what this does")
```

3. **Semantic roles**
```swift
Button("Delete", role: .destructive) { action() }
```

4. **Keyboard shortcuts**
```swift
.keyboardShortcut("g", modifiers: [.command])
.keyboardShortcut(.defaultAction)  // Return key
.keyboardShortcut(.cancelAction)   // Escape key
```

## Responsive Design

### Window Sizing

```swift
.frame(minWidth: 500, idealWidth: 600, maxWidth: 800)
.frame(minHeight: 400, idealHeight: 500, maxHeight: 700)
```

### Adaptive Layouts

```swift
// Use HSplitView for resizable panes
HSplitView {
    LeftPane()
        .frame(minWidth: 300, idealWidth: 400)
    RightPane()
        .frame(minWidth: 300)
}

// Use ScrollView for overflow
ScrollView {
    VStack { ... }
}
```

## Testing Checklist

When creating new UI:

- [ ] Follows VStack(spacing: 0) pattern for modals
- [ ] Uses .borderedProminent for primary actions
- [ ] Includes dividers between sections
- [ ] Has proper error/success message handling
- [ ] Uses 24px padding for form content
- [ ] Includes keyboard shortcuts for main actions
- [ ] Shows loading states during async operations
- [ ] Has placeholder states for empty content
- [ ] Uses secondary text for descriptions
- [ ] Includes help text/tooltips where needed
- [ ] Properly handles light/dark mode
- [ ] Respects system appearance settings

## Summary

### Quick Reference

**Modal Structure:**
```
VStack(spacing: 0)
  ├─ Header (bold + subtitle)
  ├─ Divider
  ├─ Content (ScrollView + Form)
  ├─ Divider
  └─ Button Bar (gray background)
```

**Form Style:**
```
Form.formStyle(.grouped)
  ├─ Section (description)
  ├─ Section (content + header + footer)
  └─ .padding(24)
```

**Button Hierarchy:**
- **Primary**: .borderedProminent + .controlSize(.large)
- **Secondary**: .bordered
- **Destructive**: role: .destructive + .bordered

**Status Messages:**
- **Error**: Red tint + dismiss button
- **Success**: Green tint + auto-dismiss

This design system ensures a consistent, polished, and professional user experience across the entire app.
