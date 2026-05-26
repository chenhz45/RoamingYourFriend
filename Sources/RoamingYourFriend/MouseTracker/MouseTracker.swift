import AppKit

/// Tracks global mouse position via polling (`NSEvent.mouseLocation` — no permission needed)
/// and detects clicks via `NSEvent.addGlobalMonitorForEvents`.
final class MouseTracker: @unchecked Sendable {

    static let shared = MouseTracker()

    private(set) var currentMousePosition: NSPoint?
    private(set) var lastClickOnCharacterTimestamp: CFTimeInterval?
    let heatmap = HeatmapGrid()

    weak var characterWindow: CharacterWindow?

    private var pollTimer: Timer?
    private var clickMonitor: Any?

    private let queue = DispatchQueue(label: "com.roamingyourfriend.mouse")

    private init() {}

    // MARK: - Public

    var isTracking: Bool { pollTimer != nil }

    func start() {
        heatmap.startDecayTimer()
        startPolling()
        startClickMonitor()
        observeScreenChanges()
        print("[MouseTracker] Started — polling NSEvent.mouseLocation")
    }

    func stop() {
        heatmap.stopDecayTimer()
        stopPolling()
        stopClickMonitor()
    }

    @MainActor
    func pointInWindow(_ point: NSPoint) -> Bool {
        guard let window = characterWindow else { return false }
        return window.frame.contains(point)
    }

    // MARK: - Position polling (no permission needed)

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pos = NSEvent.mouseLocation // AppKit coords, always available
            self.queue.async {
                self.currentMousePosition = pos
                self.heatmap.recordPosition(pos)
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Click monitor (needs accessibility)

    private func startClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return }
            let pos = event.locationInWindow // screen coords in AppKit
            DispatchQueue.main.async {
                if self.pointInWindow(pos) {
                    self.lastClickOnCharacterTimestamp = CACurrentMediaTime()
                    print("[MouseTracker] Character clicked at \(pos)")
                }
            }
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Display change handling

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange() {
        heatmap.rebuildIfNeeded()
    }
}
