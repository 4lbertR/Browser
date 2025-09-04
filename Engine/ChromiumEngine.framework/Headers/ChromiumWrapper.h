#ifndef CHROMIUM_WRAPPER_H
#define CHROMIUM_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

// Opaque handle to the engine
typedef void* ChromiumEngineHandle;

// Callback function types
typedef void (*LoadingCallback)(bool isLoading);
typedef void (*ProgressCallback)(float progress);
typedef void (*URLCallback)(const char* url);
typedef void (*TitleCallback)(const char* title);
typedef void (*NavigationCallback)(bool canGoBack, bool canGoForward);
typedef void (*RenderCallback)(const void* pixelData, int width, int height);
typedef void (*JSResultCallback)(const char* result);

// Engine lifecycle
ChromiumEngineHandle chromium_engine_create(void);
void chromium_engine_destroy(ChromiumEngineHandle handle);

// Navigation
void chromium_engine_load_url(ChromiumEngineHandle handle, const char* url);
void chromium_engine_go_back(ChromiumEngineHandle handle);
void chromium_engine_go_forward(ChromiumEngineHandle handle);
void chromium_engine_reload(ChromiumEngineHandle handle);
void chromium_engine_stop_loading(ChromiumEngineHandle handle);

// JavaScript execution
void chromium_engine_execute_javascript(ChromiumEngineHandle handle, const char* script, JSResultCallback callback);

// Input handling
void chromium_engine_send_touch_event(ChromiumEngineHandle handle, int type, float x, float y);
void chromium_engine_send_key_event(ChromiumEngineHandle handle, int keyCode, bool isDown);

// Viewport
void chromium_engine_set_viewport_size(ChromiumEngineHandle handle, int width, int height);

// Callbacks
void chromium_engine_set_loading_callback(ChromiumEngineHandle handle, LoadingCallback callback);
void chromium_engine_set_progress_callback(ChromiumEngineHandle handle, ProgressCallback callback);
void chromium_engine_set_url_callback(ChromiumEngineHandle handle, URLCallback callback);
void chromium_engine_set_title_callback(ChromiumEngineHandle handle, TitleCallback callback);
void chromium_engine_set_navigation_callback(ChromiumEngineHandle handle, NavigationCallback callback);
void chromium_engine_set_render_callback(ChromiumEngineHandle handle, RenderCallback callback);

// Cookie management
void chromium_engine_set_cookie(ChromiumEngineHandle handle, const char* domain, const char* name, const char* value);
void chromium_engine_get_cookies(ChromiumEngineHandle handle, const char* domain, char* buffer, int bufferSize);
void chromium_engine_clear_cookies(ChromiumEngineHandle handle);

// Settings
void chromium_engine_set_user_agent(ChromiumEngineHandle handle, const char* userAgent);
void chromium_engine_enable_javascript(ChromiumEngineHandle handle, bool enable);
void chromium_engine_enable_images(ChromiumEngineHandle handle, bool enable);

#ifdef __cplusplus
}
#endif

#endif // CHROMIUM_WRAPPER_H