import AppKit
import Foundation

/// A 2D grid tracking mouse-position frequency across all screens.
/// Thread-safe via a serial dispatch queue.
final class HeatmapGrid: @unchecked Sendable {

    let columns: Int
    let rows: Int
    private(set) var screenBounds: NSRect

    private var cells: [Int]
    private(set) var totalEvents: Int = 0
    private(set) var droppedEvents: Int = 0
    private let queue = DispatchQueue(label: "com.roamingyourfriend.heatmap")

    private var decayTimer: Timer?
    private let decayInterval: TimeInterval = 10.0
    private let decayFactor: Double = 0.95

    init(columns: Int = 40, rows: Int = 22) {
        self.columns = columns
        self.rows = rows
        self.screenBounds = Self.computeScreenBounds()
        self.cells = Array(repeating: 0, count: columns * rows)
    }

    func startDecayTimer() {
        stopDecayTimer()
        decayTimer = Timer.scheduledTimer(withTimeInterval: decayInterval, repeats: true) { [weak self] _ in
            self?.decayAll()
        }
    }

    func stopDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = nil
    }

    func recordPosition(_ point: NSPoint) {
        guard let (col, row) = cellIndex(for: point) else {
            queue.async { [weak self] in
                self?.droppedEvents += 1
            }
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            self.totalEvents += 1
            let idx = row * self.columns + col
            if idx >= 0, idx < self.cells.count {
                self.cells[idx] += 1
            }
        }
    }

    func cellValue(at col: Int, row: Int) -> Int {
        queue.sync {
            let idx = row * columns + col
            guard idx >= 0, idx < cells.count else { return 0 }
            return cells[idx]
        }
    }

    func snapshot() -> [Int] {
        queue.sync { cells }
    }

    func rebuildIfNeeded() {
        queue.async { [weak self] in
            guard let self else { return }
            let newBounds = Self.computeScreenBounds()
            guard newBounds != self.screenBounds else { return }
            self.screenBounds = newBounds
            self.cells = Array(repeating: 0, count: self.columns * self.rows)
        }
    }

    func cellIndex(for point: NSPoint) -> (col: Int, row: Int)? {
        let relative = NSPoint(x: point.x - screenBounds.origin.x,
                               y: point.y - screenBounds.origin.y)
        guard relative.x >= 0, relative.y >= 0 else { return nil }

        let cellW = screenBounds.width  / Double(columns)
        let cellH = screenBounds.height / Double(rows)
        guard cellW > 0, cellH > 0 else { return nil }

        let col = min(Int(relative.x / cellW), columns - 1)
        let row = min(Int(relative.y / cellH), rows - 1)
        return (col, row)
    }

    private func decayAll() {
        queue.async { [weak self] in
            guard let self else { return }
            for i in 0..<self.cells.count where self.cells[i] > 0 {
                let v = Double(self.cells[i]) * self.decayFactor
                self.cells[i] = v < 1.0 ? 0 : Int(v)
            }
        }
    }

    private static func computeScreenBounds() -> NSRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return .zero }
        var union = screens[0].frame
        for s in screens.dropFirst() {
            union = union.union(s.frame)
        }
        return union
    }
}
