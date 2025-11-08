---
agent: agent
model: GPT-4.1 (copilot)
name: build-and-run
description: Build and run code based on user requirements.
---
## Build and Run PodcastAssistant (macOS)

### Prerequisites
1. Ensure Xcode is installed and the developer directory is set:
   ```zsh
   mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1
   sudo xcode-select --switch /Applications/Xcode-26.0.1.app/Contents/Developer
   ```

### Build & Run (Recommended)
Use the MCP tool for a one-step build and launch:
```zsh
mcp_xcodebuildmcp_build_run_macos({ 
	scheme: "PodcastAssistant", 
	workspacePath: "/Volumes/ExData/GitHub/app-podcast-assistant/PodcastAssistant.xcworkspace" 
})
```

### Build & Run (Terminal Fallback)
If MCP tools are unavailable, use:
```zsh
cd /Volumes/ExData/GitHub/app-podcast-assistant
xcodebuild -workspace PodcastAssistant.xcworkspace -scheme PodcastAssistant -configuration Debug clean build
open ~/Library/Developer/Xcode/DerivedData/PodcastAssistant-*/Build/Products/Debug/PodcastAssistant.app
```

### Success Criteria
- App builds without errors
- App launches and displays main UI
- Features (Transcript Converter, Thumbnail Generator) are accessible