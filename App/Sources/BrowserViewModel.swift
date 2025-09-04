import Foundation
import SwiftUI
import Combine

class BrowserViewModel: ObservableObject {
    @Published var currentURL: String = ""
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isSecure: Bool = false
    @Published var isPrivateMode: Bool = false
    @Published var tabCount: Int = 1
    @Published var pageTitle: String = ""
    
    private var engineBridge: ChromiumEngineBridge
    private var historyManager: HistoryManager
    private var cookieManager: CookieManager
    private var tabs: [BrowserTab] = []
    private var currentTabIndex: Int = 0
    
    init() {
        self.engineBridge = ChromiumEngineBridge()
        self.historyManager = HistoryManager()
        self.cookieManager = CookieManager()
        
        // Create initial tab
        let initialTab = BrowserTab()
        tabs.append(initialTab)
        
        setupEngineCallbacks()
    }
    
    private func setupEngineCallbacks() {
        engineBridge.onLoadingStateChanged = { [weak self] loading in
            DispatchQueue.main.async {
                self?.isLoading = loading
            }
        }
        
        engineBridge.onProgressChanged = { [weak self] progress in
            DispatchQueue.main.async {
                self?.loadingProgress = progress
            }
        }
        
        engineBridge.onURLChanged = { [weak self] url in
            DispatchQueue.main.async {
                self?.currentURL = url
                self?.isSecure = url.hasPrefix("https://")
                
                // Add to history if not in private mode
                if !(self?.isPrivateMode ?? false) {
                    self?.historyManager.addEntry(url: url, title: self?.pageTitle ?? "")
                }
            }
        }
        
        engineBridge.onTitleChanged = { [weak self] title in
            DispatchQueue.main.async {
                self?.pageTitle = title
            }
        }
        
        engineBridge.onNavigationStateChanged = { [weak self] canGoBack, canGoForward in
            DispatchQueue.main.async {
                self?.canGoBack = canGoBack
                self?.canGoForward = canGoForward
            }
        }
    }
    
    func navigate(to urlString: String) {
        var finalURL = urlString
        
        // Check if it's a search query or URL
        if !urlString.contains("://") && !urlString.contains(".") {
            // Treat as search query
            finalURL = "https://duckduckgo.com/?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)"
        } else if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            // Add https:// if no protocol specified
            finalURL = "https://\(urlString)"
        }
        
        currentURL = finalURL
        engineBridge.loadURL(finalURL)
    }
    
    func goBack() {
        engineBridge.goBack()
    }
    
    func goForward() {
        engineBridge.goForward()
    }
    
    func reload() {
        if isLoading {
            engineBridge.stopLoading()
        } else {
            engineBridge.reload()
        }
    }
    
    func togglePrivateMode() {
        isPrivateMode.toggle()
        
        if isPrivateMode {
            // Clear cookies for private session
            cookieManager.clearSessionCookies()
        }
    }
    
    func clearHistory() {
        historyManager.clearAll()
    }
    
    func clearCookies() {
        cookieManager.clearAllCookies()
    }
    
    func newTab() {
        let tab = BrowserTab()
        tabs.append(tab)
        currentTabIndex = tabs.count - 1
        tabCount = tabs.count
        
        // Reset state for new tab
        currentURL = ""
        pageTitle = ""
        canGoBack = false
        canGoForward = false
        isLoading = false
        loadingProgress = 0.0
    }
    
    func closeTab(at index: Int) {
        guard tabs.count > 1 else { return }
        
        tabs.remove(at: index)
        tabCount = tabs.count
        
        if currentTabIndex >= tabs.count {
            currentTabIndex = tabs.count - 1
        }
        
        switchToTab(at: currentTabIndex)
    }
    
    func switchToTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        
        // Save current tab state
        if currentTabIndex < tabs.count {
            tabs[currentTabIndex].url = currentURL
            tabs[currentTabIndex].title = pageTitle
        }
        
        currentTabIndex = index
        let tab = tabs[index]
        
        // Restore tab state
        if let url = tab.url, !url.isEmpty {
            navigate(to: url)
        } else {
            currentURL = ""
            pageTitle = ""
        }
    }
}

struct BrowserTab {
    var id = UUID()
    var url: String?
    var title: String?
    var favicon: Data?
    var lastVisited: Date = Date()
}