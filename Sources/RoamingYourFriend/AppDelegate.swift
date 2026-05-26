import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var characterWindow: CharacterWindow?
    private let roamingController = RoamingController()
    private let mainMenu = MainMenu()
    private var isRoaming = false
    private var setupWindow: SetupWindow?
    private var processedAvatarPath: String?

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        showSetupWindow(mode: .onboarding)
    }

    func applicationWillTerminate(_ notification: Notification) {
        roamingController.stop()
        MouseTracker.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Menu

    private func setupMainMenu() {
        // Main menu with Edit items (enables Cmd+C/V/X/A in text fields)
        let appMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        appMenu.addItem(editItem)
        NSApp.mainMenu = appMenu

        mainMenu.onOpenSettings = { [weak self] in
            self?.showSetupWindow(mode: .display)
        }
        mainMenu.onQuit = {
            NSApp.terminate(nil)
        }
        mainMenu.setup()
    }

    // MARK: - Setup window

    func showSetupWindow(mode: SetupView.Mode) {
        if let existing = setupWindow {
            existing.setupView.displayAvatarPath = processedAvatarPath
            existing.setupView.mode = mode
            existing.setupView.historyEntries = HistoryStore.shared.allEntries
            existing.makeKeyAndOrderFront(nil)
            existing.makeFirstResponder(nil)
            return
        }

        let window = SetupWindow()
        let view = window.setupView
        view.displayAvatarPath = processedAvatarPath

        view.historyEntries = HistoryStore.shared.allEntries

        view.onPhotoSelected = { [weak self] path in
            self?.previewPhoto(path)
        }

        view.onStart = { [weak self] path in
            self?.startCharacter(withAvatar: path)
        }

        view.onQuit = {
            NSApp.terminate(nil)
        }

        view.onHistorySelected = { [weak self] path in
            self?.processedAvatarPath = path
        }

        view.onModeChanged = { [weak window] m in
            if m == .display {
                let newFrame = NSRect(x: 0, y: 0, width: 280, height: 300)
                window?.setFrame(newFrame, display: true, animate: true)
                window?.center()
            } else {
                let newFrame = NSRect(x: 0, y: 0, width: 560, height: 440)
                window?.setFrame(newFrame, display: true, animate: true)
                window?.center()
            }
        }

        view.mode = mode

        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
        self.setupWindow = window
    }

    // MARK: - Preview (run Python on photo selection)

    private func previewPhoto(_ inputPath: String) {
        let outputPath = appSupportPath("avatar_user.png")

        // Try standalone binary first, fall back to python3 + script
        let binPath = resourcePath("face_crop")
        let scriptPath = resourcePath("PythonScripts/face_crop.py")
        let fm = FileManager.default
        let bridge: PythonBridge
        if fm.fileExists(atPath: binPath) {
            bridge = PythonBridge(binaryPath: binPath)
        } else {
            bridge = PythonBridge(scriptPath: scriptPath)
        }

        bridge.process(inputPath: inputPath, outputPath: outputPath) { [weak self] result in
            guard let self, let view = self.setupWindow?.setupView else { return }

            let avatarPath: String
            switch result {
            case .success(let path):
                avatarPath = path
                let archived = HistoryStore.shared.archiveProcessedAvatar(from: path)
                HistoryStore.shared.add(originalPath: inputPath, processedPath: archived)
                view.historyEntries = HistoryStore.shared.allEntries
            case .noFace(let path):
                avatarPath = path
            case .failure:
                avatarPath = inputPath
            }

            self.processedAvatarPath = avatarPath
            view.showProcessedPreview(avatarPath)
        }
    }

    // MARK: - Character

    private func startCharacter(withAvatar avatarPath: String) {
        guard !isRoaming else { return }

        setupWindow?.close()

        let window = CharacterWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.characterWindow = window

        if let view = window.contentView as? CharacterView {
            view.avatarImagePath = avatarPath
        }

        MouseTracker.shared.characterWindow = window
        MouseTracker.shared.start()

        roamingController.characterWindow = window
        roamingController.start()

        isRoaming = true
        mainMenu.setSelectPhotoEnabled(false)
    }
}

/// Resolve a path to a bundled resource (scripts, models).
private func resourcePath(_ relative: String) -> String {
    guard let resPath = Bundle.main.resourcePath else {
        return relative
    }
    return resPath + "/" + relative
}

/// Resolve a writable path in Application Support.
func appSupportPath(_ relative: String) -> String {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("RoamingYourFriend")
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base.appendingPathComponent(relative).path
}
