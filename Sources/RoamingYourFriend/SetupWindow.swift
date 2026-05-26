import AppKit

@MainActor
final class SetupWindow: NSWindow {

    let setupView: SetupView

    init() {
        let view = SetupView(frame: .zero)
        self.setupView = view
        view.wantsLayer = true
        view.layer?.cornerRadius = 20
        view.layer?.masksToBounds = true

        let rect = NSRect(x: 0, y: 0, width: 560, height: 440)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = Loc.appTitle
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        level = .floating
        backgroundColor = .clear
        isOpaque = false

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .windowBackground
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        contentView = view
        view.addSubview(visualEffect, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        center()
    }
}
