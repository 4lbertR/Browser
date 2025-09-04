import Foundation
import UIKit

enum TouchEventType {
    case touchStart
    case touchMove
    case touchEnd
    case touchCancel
}

class ChromiumEngineBridge {
    static let shared = ChromiumEngineBridge()
    
    // Callbacks for UI updates
    var onLoadingStateChanged: ((Bool) -> Void)?
    var onProgressChanged: ((Double) -> Void)?
    var onURLChanged: ((String) -> Void)?
    var onTitleChanged: ((String) -> Void)?
    var onNavigationStateChanged: ((Bool, Bool) -> Void)?
    var onRenderFrame: ((UnsafeRawPointer, Int, Int) -> Void)?
    
    private var engineHandle: OpaquePointer?
    
    init() {
        initializeEngine()
    }
    
    deinit {
        shutdownEngine()
    }
    
    private func initializeEngine() {
        // Initialize Chromium engine
        // This would call into the C++ Chromium wrapper
        engineHandle = chromium_engine_create()
        
        // Set up callbacks from engine to Swift
        chromium_engine_set_loading_callback(engineHandle) { [weak self] isLoading in
            self?.onLoadingStateChanged?(isLoading)
        }
        
        chromium_engine_set_progress_callback(engineHandle) { [weak self] progress in
            self?.onProgressChanged?(Double(progress))
        }
        
        chromium_engine_set_url_callback(engineHandle) { [weak self] urlPtr in
            guard let urlPtr = urlPtr else { return }
            let url = String(cString: urlPtr)
            self?.onURLChanged?(url)
        }
        
        chromium_engine_set_title_callback(engineHandle) { [weak self] titlePtr in
            guard let titlePtr = titlePtr else { return }
            let title = String(cString: titlePtr)
            self?.onTitleChanged?(title)
        }
        
        chromium_engine_set_navigation_callback(engineHandle) { [weak self] canGoBack, canGoForward in
            self?.onNavigationStateChanged?(canGoBack, canGoForward)
        }
        
        chromium_engine_set_render_callback(engineHandle) { [weak self] pixelData, width, height in
            guard let pixelData = pixelData else { return }
            self?.onRenderFrame?(pixelData, Int(width), Int(height))
        }
    }
    
    private func shutdownEngine() {
        if let handle = engineHandle {
            chromium_engine_destroy(handle)
            engineHandle = nil
        }
    }
    
    func loadURL(_ urlString: String) {
        guard let handle = engineHandle else { return }
        urlString.withCString { urlPtr in
            chromium_engine_load_url(handle, urlPtr)
        }
    }
    
    func goBack() {
        guard let handle = engineHandle else { return }
        chromium_engine_go_back(handle)
    }
    
    func goForward() {
        guard let handle = engineHandle else { return }
        chromium_engine_go_forward(handle)
    }
    
    func reload() {
        guard let handle = engineHandle else { return }
        chromium_engine_reload(handle)
    }
    
    func stopLoading() {
        guard let handle = engineHandle else { return }
        chromium_engine_stop_loading(handle)
    }
    
    func executeJavaScript(_ script: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let handle = engineHandle else {
            completion(.failure(NSError(domain: "ChromiumEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine not initialized"])))
            return
        }
        
        script.withCString { scriptPtr in
            chromium_engine_execute_javascript(handle, scriptPtr) { resultPtr in
                if let resultPtr = resultPtr {
                    let result = String(cString: resultPtr)
                    completion(.success(result))
                } else {
                    completion(.failure(NSError(domain: "ChromiumEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "JavaScript execution failed"])))
                }
            }
        }
    }
    
    func sendTouchEvent(type: TouchEventType, x: Float, y: Float) {
        guard let handle = engineHandle else { return }
        
        let eventType: Int32
        switch type {
        case .touchStart:
            eventType = 0
        case .touchMove:
            eventType = 1
        case .touchEnd:
            eventType = 2
        case .touchCancel:
            eventType = 3
        }
        
        chromium_engine_send_touch_event(handle, eventType, x, y)
    }
    
    func setViewportSize(width: Int, height: Int) {
        guard let handle = engineHandle else { return }
        chromium_engine_set_viewport_size(handle, Int32(width), Int32(height))
    }
}

// MARK: - C++ Bridge Functions
// These would be implemented in ChromiumWrapper.mm (Objective-C++)

@_silgen_name("chromium_engine_create")
func chromium_engine_create() -> OpaquePointer?

@_silgen_name("chromium_engine_destroy")
func chromium_engine_destroy(_ handle: OpaquePointer)

@_silgen_name("chromium_engine_load_url")
func chromium_engine_load_url(_ handle: OpaquePointer, _ url: UnsafePointer<CChar>)

@_silgen_name("chromium_engine_go_back")
func chromium_engine_go_back(_ handle: OpaquePointer)

@_silgen_name("chromium_engine_go_forward")
func chromium_engine_go_forward(_ handle: OpaquePointer)

@_silgen_name("chromium_engine_reload")
func chromium_engine_reload(_ handle: OpaquePointer)

@_silgen_name("chromium_engine_stop_loading")
func chromium_engine_stop_loading(_ handle: OpaquePointer)

@_silgen_name("chromium_engine_execute_javascript")
func chromium_engine_execute_javascript(_ handle: OpaquePointer, _ script: UnsafePointer<CChar>, _ callback: @escaping (UnsafePointer<CChar>?) -> Void)

@_silgen_name("chromium_engine_send_touch_event")
func chromium_engine_send_touch_event(_ handle: OpaquePointer, _ type: Int32, _ x: Float, _ y: Float)

@_silgen_name("chromium_engine_set_viewport_size")
func chromium_engine_set_viewport_size(_ handle: OpaquePointer, _ width: Int32, _ height: Int32)

@_silgen_name("chromium_engine_set_loading_callback")
func chromium_engine_set_loading_callback(_ handle: OpaquePointer, _ callback: @escaping (Bool) -> Void)

@_silgen_name("chromium_engine_set_progress_callback")
func chromium_engine_set_progress_callback(_ handle: OpaquePointer, _ callback: @escaping (Float) -> Void)

@_silgen_name("chromium_engine_set_url_callback")
func chromium_engine_set_url_callback(_ handle: OpaquePointer, _ callback: @escaping (UnsafePointer<CChar>?) -> Void)

@_silgen_name("chromium_engine_set_title_callback")
func chromium_engine_set_title_callback(_ handle: OpaquePointer, _ callback: @escaping (UnsafePointer<CChar>?) -> Void)

@_silgen_name("chromium_engine_set_navigation_callback")
func chromium_engine_set_navigation_callback(_ handle: OpaquePointer, _ callback: @escaping (Bool, Bool) -> Void)

@_silgen_name("chromium_engine_set_render_callback")
func chromium_engine_set_render_callback(_ handle: OpaquePointer, _ callback: @escaping (UnsafeRawPointer?, Int32, Int32) -> Void)