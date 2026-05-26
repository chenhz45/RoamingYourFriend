import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: String
    let originalPath: String
    let processedPath: String
    let timestamp: Date
}

@MainActor
final class HistoryStore {

    static let shared = HistoryStore()

    private var entries: [HistoryEntry] = []
    private let maxEntries = 20

    var allEntries: [HistoryEntry] { entries }

    // MARK: - Paths

    private var storeDir: URL {
        URL(fileURLWithPath: appSupportPath("history"))
    }

    private var storeFile: URL {
        storeDir.appendingPathComponent("history.json")
    }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - Operations

    func add(originalPath: String, processedPath: String) {
        let entry = HistoryEntry(
            id: UUID().uuidString,
            originalPath: originalPath,
            processedPath: processedPath,
            timestamp: Date()
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func remove(id: String) {
        if let entry = entries.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: entry.processedPath))
        }
        entries.removeAll { $0.id == id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeFile) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storeFile)
    }

    /// Copy the processed avatar into the history folder under a unique name.
    /// Returns the path to the permanent copy.
    func archiveProcessedAvatar(from sourcePath: String) -> String {
        let dir = storeDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destName = "avatar_\(UUID().uuidString).png"
        let destURL = dir.appendingPathComponent(destName)
        try? FileManager.default.copyItem(at: URL(fileURLWithPath: sourcePath), to: destURL)
        return destURL.path
    }
}
