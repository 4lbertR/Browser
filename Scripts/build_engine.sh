#!/bin/bash

# Chromium Engine Build Script for iOS
# This script builds the Chromium engine for iOS devices

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENGINE_DIR="$PROJECT_ROOT/Engine"
BUILD_DIR="$ENGINE_DIR/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Chromium Engine iOS Build Script${NC}"
echo "================================="

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}Error: Xcode is not installed${NC}"
        exit 1
    fi
    
    # Check for ninja
    if ! command -v ninja &> /dev/null; then
        echo -e "${YELLOW}Warning: Ninja build system not found. Installing...${NC}"
        brew install ninja
    fi
    
    # Check for gn
    if ! command -v gn &> /dev/null; then
        echo -e "${YELLOW}Warning: GN build system not found${NC}"
        echo "You'll need to download GN from Chromium depot_tools"
    fi
    
    echo -e "${GREEN}Requirements check complete${NC}"
}

# Download Chromium source if needed
download_chromium() {
    echo -e "${YELLOW}Checking for Chromium source...${NC}"
    
    CHROMIUM_SRC="$ENGINE_DIR/chromium_src"
    
    if [ ! -d "$CHROMIUM_SRC" ]; then
        echo -e "${YELLOW}Downloading Chromium source...${NC}"
        echo "Note: This will take a while and requires ~30GB of space"
        
        # Clone depot_tools
        if [ ! -d "$ENGINE_DIR/depot_tools" ]; then
            git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$ENGINE_DIR/depot_tools"
        fi
        
        export PATH="$ENGINE_DIR/depot_tools:$PATH"
        
        # Fetch Chromium
        mkdir -p "$CHROMIUM_SRC"
        cd "$CHROMIUM_SRC"
        fetch --nohooks chromium
        
        # Sync for iOS
        cd src
        gclient sync --nohooks --no-history
        
        echo -e "${GREEN}Chromium source downloaded${NC}"
    else
        echo -e "${GREEN}Chromium source already exists${NC}"
    fi
}

# Configure build for iOS
configure_build() {
    echo -e "${YELLOW}Configuring build for iOS...${NC}"
    
    cd "$CHROMIUM_SRC/src"
    
    # Create build configuration
    mkdir -p "$BUILD_DIR/ios_arm64"
    
    cat > "$BUILD_DIR/ios_arm64/args.gn" << EOF
target_os = "ios"
target_cpu = "arm64"
is_debug = false
is_official_build = true
is_component_build = false
enable_nacl = false
enable_remoting = false
use_xcode_clang = true
ios_deployment_target = "17.4"
ios_enable_code_signing = false

# Disable WebKit/Safari-specific features
enable_wkwebview = false

# Enable Blink rendering engine
use_blink = true

# Optimization flags
symbol_level = 0
enable_stripping = true
EOF
    
    # Generate build files
    gn gen "$BUILD_DIR/ios_arm64"
    
    echo -e "${GREEN}Build configured${NC}"
}

# Build the engine
build_engine() {
    echo -e "${YELLOW}Building Chromium engine for iOS...${NC}"
    
    cd "$CHROMIUM_SRC/src"
    
    # Build the target
    ninja -C "$BUILD_DIR/ios_arm64" chrome_ios
    
    echo -e "${GREEN}Build complete${NC}"
}

# Create iOS framework
create_framework() {
    echo -e "${YELLOW}Creating iOS framework...${NC}"
    
    FRAMEWORK_DIR="$ENGINE_DIR/ChromiumEngine.framework"
    
    # Create framework structure
    mkdir -p "$FRAMEWORK_DIR/Headers"
    mkdir -p "$FRAMEWORK_DIR/Modules"
    
    # Copy headers
    cp "$ENGINE_DIR/include/ChromiumWrapper.h" "$FRAMEWORK_DIR/Headers/"
    
    # Copy library
    cp "$BUILD_DIR/ios_arm64/libchrome.a" "$FRAMEWORK_DIR/ChromiumEngine"
    
    # Create module map
    cat > "$FRAMEWORK_DIR/Modules/module.modulemap" << EOF
framework module ChromiumEngine {
    umbrella header "ChromiumWrapper.h"
    export *
    module * { export * }
}
EOF
    
    # Create Info.plist
    cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ChromiumEngine</string>
    <key>CFBundleIdentifier</key>
    <string>com.privatebrowser.chromiumengine</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ChromiumEngine</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>17.4</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
</dict>
</plist>
EOF
    
    echo -e "${GREEN}Framework created at: $FRAMEWORK_DIR${NC}"
}

# Main build process
main() {
    check_requirements
    
    # For initial setup, you would uncomment these:
    # download_chromium
    # configure_build
    # build_engine
    
    # For now, create a stub framework for development
    echo -e "${YELLOW}Creating stub framework for development...${NC}"
    create_framework
    
    echo -e "${GREEN}Build process complete!${NC}"
    echo "Next steps:"
    echo "1. Open the Xcode project"
    echo "2. Add ChromiumEngine.framework to your project"
    echo "3. Build and run on your iOS device"
}

main "$@"