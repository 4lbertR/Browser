import Foundation

// Browser Configuration
struct BrowserConfig {
    // STEP 1: Sign up for FREE at one of these services:
    // - https://apiflash.com (100 free screenshots/month)
    // - https://screenshotmachine.com (100 free/month)
    // - https://screenshotapi.net (100 free/month)
    
    // STEP 2: Replace with your actual API key
    static let apiflashKey = "YOUR_API_KEY_HERE"
    
    // Alternative: Use Screenshot Machine (also free)
    static let screenshotMachineKey = "YOUR_KEY_HERE"
    
    // Or deploy the included server/ to Replit and use WebSocket
    static let customServerURL = "wss://your-server.replit.app"
    
    // Choose which service to use
    enum RenderingService {
        case apiflash
        case screenshotMachine
        case customServer
        case none
    }
    
    // Change this to your preferred service after adding API key
    static let activeService: RenderingService = .apiflash
    
    // Get the screenshot URL for the selected service
    static func getScreenshotURL(for url: URL) -> String? {
        switch activeService {
        case .apiflash:
            if apiflashKey == "YOUR_API_KEY_HERE" {
                return nil
            }
            return "https://api.apiflash.com/v1/urltoimage?access_key=\(apiflashKey)&url=\(url.absoluteString)&format=png&width=390&height=844&fresh=true&full_page=true&scroll_page=true&wait_until=page_loaded"
            
        case .screenshotMachine:
            if screenshotMachineKey == "YOUR_KEY_HERE" {
                return nil
            }
            return "https://api.screenshotmachine.com?key=\(screenshotMachineKey)&url=\(url.absoluteString)&dimension=390x844&format=png&cacheLimit=0&delay=3000"
            
        case .customServer:
            return customServerURL
            
        case .none:
            return nil
        }
    }
    
    // Check if API is configured
    static var isConfigured: Bool {
        switch activeService {
        case .apiflash:
            return apiflashKey != "YOUR_API_KEY_HERE"
        case .screenshotMachine:
            return screenshotMachineKey != "YOUR_KEY_HERE"
        case .customServer:
            return !customServerURL.contains("your-server")
        case .none:
            return false
        }
    }
}