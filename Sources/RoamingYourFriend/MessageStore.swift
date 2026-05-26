import Foundation

@MainActor
final class MessageStore {

    static let shared = MessageStore()

    static let maxMessages = 3
    static let maxLength = 50

    var messages: [String] = ["", "", ""] {
        didSet { save() }
    }

    /// Non-empty messages for random selection.
    var activeMessages: [String] {
        messages.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var storeURL: URL {
        URL(fileURLWithPath: appSupportPath("history/messages.json"))
    }

    init() {
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let loaded = try? JSONDecoder().decode([String].self, from: data),
              loaded.count == Self.maxMessages else { return }
        messages = loaded.map { String($0.prefix(Self.maxLength)) }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: storeURL)
    }
}
