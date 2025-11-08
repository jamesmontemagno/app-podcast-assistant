#!/bin/bash
# Quick Start Script for Podcast Assistant
# This script opens the project correctly in Xcode

echo "🚀 Podcast Assistant - Quick Start"
echo "=================================="
echo ""
echo "Opening PodcastAssistant.xcworkspace in Xcode..."
echo ""
echo "⚠️  Important: Always open the .xcworkspace file, NOT the .xcodeproj file"
echo ""

# Check if the workspace file exists
if [ ! -f "PodcastAssistant.xcworkspace/contents.xcworkspacedata" ]; then
    echo "❌ Error: PodcastAssistant.xcworkspace not found!"
    echo "   Please run this script from the project root directory."
    exit 1
fi

# Open the workspace in Xcode
open PodcastAssistant.xcworkspace

echo "✅ Workspace opened in Xcode"
echo ""
echo "Next steps:"
echo "1. Wait for package resolution to complete"
echo "2. Select the 'PodcastAssistant' scheme"
echo "3. Build and run (⌘R)"
echo ""
echo "See README.md for full documentation."
