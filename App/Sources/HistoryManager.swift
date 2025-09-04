import Foundation

struct HistoryEntry: Codable {
    let id: UUID
    let url: String
    let title: String
    let visitDate: Date
    
    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.visitDate = Date()
    }
}

class HistoryManager {
    private let historyKey = "browser.history"
    private let maxHistoryEntries = 1000
    private var entries: [HistoryEntry] = []
    
    init() {
        loadHistory()
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }
    
    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(encoded, forKey: historyKey)
    }
    
    func addEntry(url: String, title: String) {
        let entry = HistoryEntry(url: url, title: title)
        entries.insert(entry, at: 0)
        
        // Limit history size
        if entries.count > maxHistoryEntries {
            entries = Array(entries.prefix(maxHistoryEntries))
        }
        
        saveHistory()
    }
    
    func getHistory() -> [HistoryEntry] {
        return entries
    }
    
    func clearAll() {
        entries.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveHistory()
    }
    
    func search(query: String) -> [HistoryEntry] {
        let lowercasedQuery = query.lowercased()
        return entries.filter { entry in
            entry.url.lowercased().contains(lowercasedQuery) ||
            entry.title.lowercased().contains(lowercasedQuery)
        }
    }
}