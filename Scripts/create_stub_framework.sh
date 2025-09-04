#!/bin/bash

# Create a stub static library for the ChromiumEngine framework
# This allows the project to build while the real engine is being developed

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENGINE_DIR="$PROJECT_ROOT/Engine"
FRAMEWORK_DIR="$ENGINE_DIR/ChromiumEngine.framework"

echo "Creating stub ChromiumEngine framework..."

# Create a simple C file that exports the required symbols
cat > /tmp/chromium_stub.c << 'EOF'
#include <stddef.h>
#include <stdbool.h>

// Stub implementations of all exported functions
void* chromium_engine_create(void) { return NULL; }
void chromium_engine_destroy(void* handle) { }
void chromium_engine_load_url(void* handle, const char* url) { }
void chromium_engine_go_back(void* handle) { }
void chromium_engine_go_forward(void* handle) { }
void chromium_engine_reload(void* handle) { }
void chromium_engine_stop_loading(void* handle) { }
void chromium_engine_execute_javascript(void* handle, const char* script, void* callback) { }
void chromium_engine_send_touch_event(void* handle, int type, float x, float y) { }
void chromium_engine_send_key_event(void* handle, int keyCode, bool isDown) { }
void chromium_engine_set_viewport_size(void* handle, int width, int height) { }
void chromium_engine_set_loading_callback(void* handle, void* callback) { }
void chromium_engine_set_progress_callback(void* handle, void* callback) { }
void chromium_engine_set_url_callback(void* handle, void* callback) { }
void chromium_engine_set_title_callback(void* handle, void* callback) { }
void chromium_engine_set_navigation_callback(void* handle, void* callback) { }
void chromium_engine_set_render_callback(void* handle, void* callback) { }
void chromium_engine_set_cookie(void* handle, const char* domain, const char* name, const char* value) { }
void chromium_engine_get_cookies(void* handle, const char* domain, char* buffer, int bufferSize) { }
void chromium_engine_clear_cookies(void* handle) { }
void chromium_engine_set_user_agent(void* handle, const char* userAgent) { }
void chromium_engine_enable_javascript(void* handle, bool enable) { }
void chromium_engine_enable_images(void* handle, bool enable) { }
EOF

# Compile for iOS (requires Xcode)
if command -v xcrun &> /dev/null; then
    echo "Compiling stub library for iOS..."
    
    # Compile for arm64 (device)
    xcrun -sdk iphoneos clang -arch arm64 -c /tmp/chromium_stub.c -o /tmp/chromium_stub_arm64.o -fembed-bitcode
    
    # Compile for x86_64 (simulator on Intel Mac)
    xcrun -sdk iphonesimulator clang -arch x86_64 -c /tmp/chromium_stub.c -o /tmp/chromium_stub_x86_64.o
    
    # Compile for arm64 (simulator on Apple Silicon)
    xcrun -sdk iphonesimulator clang -arch arm64 -c /tmp/chromium_stub.c -o /tmp/chromium_stub_sim_arm64.o
    
    # Create static libraries
    ar rcs /tmp/libchromium_arm64.a /tmp/chromium_stub_arm64.o
    ar rcs /tmp/libchromium_x86_64.a /tmp/chromium_stub_x86_64.o
    ar rcs /tmp/libchromium_sim_arm64.a /tmp/chromium_stub_sim_arm64.o
    
    # Create universal binary
    lipo -create /tmp/libchromium_arm64.a /tmp/libchromium_x86_64.a /tmp/libchromium_sim_arm64.a -output "$FRAMEWORK_DIR/ChromiumEngine"
    
    echo "Stub framework created at: $FRAMEWORK_DIR/ChromiumEngine"
    
    # Clean up temporary files
    rm /tmp/chromium_stub.c /tmp/chromium_stub_*.o /tmp/libchromium_*.a
else
    echo "Warning: Xcode not found. Creating empty binary stub."
    # Create an empty file as placeholder
    touch "$FRAMEWORK_DIR/ChromiumEngine"
fi

echo "Done!"