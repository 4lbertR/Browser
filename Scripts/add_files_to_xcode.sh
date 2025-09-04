#!/bin/bash

# Script to add new Swift files to the Xcode project
# Run this on macOS after pulling the latest changes

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PBXPROJ="$PROJECT_ROOT/PrivateBrowser.xcodeproj/project.pbxproj"

echo "Adding new files to Xcode project..."

# Function to add a file to the project
add_file_to_project() {
    local file_path=$1
    local file_name=$(basename "$file_path")
    local group_name=$2
    
    echo "Adding $file_name to $group_name group..."
    
    # This is a simplified version - in practice you'd use a tool like xcodeproj or PBXProj
    # For now, we'll just list what needs to be added manually
    echo "  - Add $file_path to $group_name group in Xcode"
}

# Add Engine files
add_file_to_project "Engine/src/HTMLParser.swift" "Engine"
add_file_to_project "Engine/src/CSSParser.swift" "Engine"
add_file_to_project "Engine/src/RenderingEngine.swift" "Engine"

# Add App files
add_file_to_project "App/Sources/CustomWebView.swift" "Sources"

echo ""
echo "Manual steps required in Xcode:"
echo "1. Open PrivateBrowser.xcodeproj"
echo "2. Right-click on 'Engine' group"
echo "3. Select 'Add Files to PrivateBrowser...'"
echo "4. Navigate to Engine/src/ and select:"
echo "   - HTMLParser.swift"
echo "   - CSSParser.swift"
echo "   - RenderingEngine.swift"
echo "5. Ensure 'Add to targets: PrivateBrowser' is checked"
echo "6. Click 'Add'"
echo ""
echo "7. Right-click on 'Sources' group under 'App'"
echo "8. Select 'Add Files to PrivateBrowser...'"
echo "9. Select App/Sources/CustomWebView.swift"
echo "10. Ensure 'Add to targets: PrivateBrowser' is checked"
echo "11. Click 'Add'"
echo ""
echo "12. Update ContentView.swift line 151:"
echo "    Change: BasicHTMLView(viewModel: browserViewModel)"
echo "    To: CustomWebView(viewModel: browserViewModel)"
echo ""
echo "13. Clean and build (⌘⇧K then ⌘B)"