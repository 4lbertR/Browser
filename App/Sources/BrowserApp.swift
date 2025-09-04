import SwiftUI

@main
struct BrowserApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.isDarkMode ? .dark : .light)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Configure app settings
        configureNetworking()
        configurePrivacy()
        disableRestrictionAPIs()
    }
    
    private func configureNetworking() {
        // Configure direct networking without iOS content filtering
        URLSession.shared.configuration.waitsForConnectivity = false
        URLSession.shared.configuration.allowsCellularAccess = true
    }
    
    private func configurePrivacy() {
        // Disable telemetry and tracking
        UserDefaults.standard.set(true, forKey: "NSAppTransportSecurity")
        UserDefaults.standard.set(true, forKey: "PrivacyMode")
    }
    
    private func disableRestrictionAPIs() {
        // Ensure we're not using any Apple restriction APIs
        // This is achieved by not importing or calling:
        // - WebKit framework
        // - ScreenTime framework
        // - FamilyControls framework
        // - Any parental control APIs
    }
}

class AppState: ObservableObject {
    @Published var isDarkMode: Bool = false
    @Published var isFirstLaunch: Bool = true
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        isFirstLaunch = UserDefaults.standard.bool(forKey: "isFirstLaunch")
        
        if isFirstLaunch {
            UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        }
    }
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
}