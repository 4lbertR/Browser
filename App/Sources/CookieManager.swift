import Foundation

struct Cookie: Codable {
    let domain: String
    let name: String
    let value: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHttpOnly: Bool
    let sameSite: String?
    
    init(domain: String, name: String, value: String, path: String = "/",
         expiresDate: Date? = nil, isSecure: Bool = false,
         isHttpOnly: Bool = false, sameSite: String? = nil) {
        self.domain = domain
        self.name = name
        self.value = value
        self.path = path
        self.expiresDate = expiresDate
        self.isSecure = isSecure
        self.isHttpOnly = isHttpOnly
        self.sameSite = sameSite
    }
}

class CookieManager {
    private let cookiesKey = "browser.cookies"
    private var cookies: [Cookie] = []
    private var sessionCookies: [Cookie] = []
    
    init() {
        loadCookies()
    }
    
    private func loadCookies() {
        guard let data = UserDefaults.standard.data(forKey: cookiesKey),
              let decoded = try? JSONDecoder().decode([Cookie].self, from: data) else {
            return
        }
        
        // Filter out expired cookies
        let now = Date()
        cookies = decoded.filter { cookie in
            if let expiresDate = cookie.expiresDate {
                return expiresDate > now
            }
            return true
        }
    }
    
    private func saveCookies() {
        guard let encoded = try? JSONEncoder().encode(cookies) else { return }
        UserDefaults.standard.set(encoded, forKey: cookiesKey)
    }
    
    func setCookie(_ cookie: Cookie) {
        // Remove existing cookie with same domain and name
        cookies.removeAll { $0.domain == cookie.domain && $0.name == cookie.name }
        cookies.append(cookie)
        saveCookies()
    }
    
    func getCookies(for domain: String) -> [Cookie] {
        return cookies.filter { cookie in
            // Simple domain matching (should be more sophisticated in production)
            domain.hasSuffix(cookie.domain) || cookie.domain.hasSuffix(domain)
        }
    }
    
    func clearAllCookies() {
        cookies.removeAll()
        sessionCookies.removeAll()
        UserDefaults.standard.removeObject(forKey: cookiesKey)
    }
    
    func clearSessionCookies() {
        sessionCookies.removeAll()
        
        // Remove session cookies from persistent storage
        cookies = cookies.filter { $0.expiresDate != nil }
        saveCookies()
    }
    
    func clearCookies(for domain: String) {
        cookies.removeAll { cookie in
            domain.hasSuffix(cookie.domain) || cookie.domain.hasSuffix(domain)
        }
        saveCookies()
    }
    
    func getCookieString(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        let relevantCookies = getCookies(for: host)
        guard !relevantCookies.isEmpty else { return nil }
        
        // Filter cookies based on secure flag and path
        let isSecure = url.scheme == "https"
        let path = url.path.isEmpty ? "/" : url.path
        
        let validCookies = relevantCookies.filter { cookie in
            // Check secure flag
            if cookie.isSecure && !isSecure {
                return false
            }
            
            // Check path
            if !path.hasPrefix(cookie.path) {
                return false
            }
            
            // Check expiration
            if let expiresDate = cookie.expiresDate, expiresDate < Date() {
                return false
            }
            
            return true
        }
        
        guard !validCookies.isEmpty else { return nil }
        
        // Build cookie string
        return validCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }
}