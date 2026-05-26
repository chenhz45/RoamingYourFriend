import AppKit

final class CharacterWindow: NSWindow {

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 150, height: 200)

        self.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.ignoresMouseEvents = true

        let view = CharacterView(frame: contentRect)
        view.wantsLayer = true
        self.contentView = view
    }
}
