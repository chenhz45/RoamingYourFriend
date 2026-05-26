import AppKit

/// Manages the menu bar status item — the primary UI for this .accessory app.
@MainActor
final class MainMenu: NSObject {

    private var statusItem: NSStatusItem?
    private var settingsItem: NSMenuItem?

    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    // MARK: - Setup

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            let img = NSImage(systemSymbolName: "figure.walk",
                              accessibilityDescription: "RoamingYourFriend")
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: Loc.settings,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        self.settingsItem = settingsItem

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: Loc.quit,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    // MARK: - State

    func setSelectPhotoEnabled(_ enabled: Bool) {
        settingsItem?.isEnabled = enabled
    }

    // MARK: - Actions

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        onQuit?()
    }
}
