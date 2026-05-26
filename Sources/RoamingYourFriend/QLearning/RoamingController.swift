import AppKit

/// Orchestrates the Q-learning decision loop and character movement.
/// Runs on the main actor since it manipulates the character window.
@MainActor
final class RoamingController {

    weak var characterWindow: CharacterWindow?

    private let engine = QLearningEngine(alpha: 0.2, gamma: 0.9, epsilon: 0.08, minEpsilon: 0.03, epsilonDecay: 0.995)
    private var moveTimer: Timer?
    private let moveInterval: TimeInterval = 0.35

    private var prevState: String?
    private var prevAction: QLearningEngine.Action?
    private var prevHitEdge: Bool = false
    private var lastStepTime: CFTimeInterval = 0
    private var lastClickTimestamp: CFTimeInterval?
    private var lastReward: Double = 0
    private var prevMouseDistance: Double = 0
    private var bubbleShowing = false
    private var lastBubbleTime: CFTimeInterval = 0
    private var sameCellCount: Int = 0
    private var lastCell: String?

    private static let defaultMessages = [
        "嘻嘻，不要发呆",
        "嘿嘿",
        "你跑不过我你信吗"
    ]

    // MARK: - Lifecycle

    func start() {
        lastStepTime = CACurrentMediaTime()
        lastClickTimestamp = MouseTracker.shared.lastClickOnCharacterTimestamp
        prevMouseDistance = currentMouseDistance()
        scheduleNextStep()
        print("[RoamingController] Started — interval \(moveInterval)s")
    }

    func stop() {
        moveTimer?.invalidate()
        moveTimer = nil
        print("[RoamingController] Stopped")
    }

    // MARK: - Main loop

    private func scheduleNextStep() {
        moveTimer = Timer.scheduledTimer(withTimeInterval: moveInterval, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.step()
            }
        }
    }

    private func step() {
        guard let window = characterWindow else {
            scheduleNextStep()
            return
        }

        let heatmap = MouseTracker.shared.heatmap
        let currentCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)

        guard let (col, row) = heatmap.cellIndex(for: currentCenter) else {
            scheduleNextStep()
            return
        }
        let currentState = "\(col),\(row)"

        // Compute reward for the previous action (once, before consuming side effects)
        let reward: Double
        if prevState != nil {
            reward = computeReward(heatmap: heatmap)
            lastReward = reward
        } else {
            reward = 0
        }

        // Update Q-value for the previous action
        if let ps = prevState, let pa = prevAction {
            engine.update(state: ps, action: pa, reward: reward, nextState: currentState)
        }

        // Select next action
        let action = engine.selectAction(for: currentState)

        // Stuck detection — boost exploration if lingering in the same cell
        if currentState == lastCell {
            sameCellCount += 1
            if sameCellCount >= 40 {
                engine.boostExploration()
                sameCellCount = 0
            }
        } else {
            sameCellCount = 0
        }
        lastCell = currentState

        // Compute target position
        let (targetOrigin, hitEdge) = computeTarget(from: (col, row), action: action, heatmap: heatmap, window: window)

        window.setFrameOrigin(targetOrigin)

        // Speech bubble — show when character gets close to the mouse
        if let view = window.contentView as? CharacterView {
            let dist = currentMouseDistance()
            let now = CACurrentMediaTime()

            if !bubbleShowing && dist < 80, now - lastBubbleTime > 3 {
                let pool = MessageStore.shared.activeMessages
                let messages = pool.isEmpty ? Self.defaultMessages : pool
                view.bubbleText = messages.randomElement()!
                bubbleShowing = true
                lastBubbleTime = now
            } else if bubbleShowing && dist > 150 {
                view.bubbleText = nil
                bubbleShowing = false
            }
        }

        // Store for next iteration
        prevState = currentState
        prevAction = action
        prevHitEdge = hitEdge
        lastStepTime = CACurrentMediaTime()

        scheduleNextStep()
    }

    // MARK: - Reward computation

    private func currentMouseDistance() -> Double {
        guard let mousePos = MouseTracker.shared.currentMousePosition,
              let window = characterWindow else { return 0 }
        let cx = window.frame.midX
        let cy = window.frame.midY
        let dx = mousePos.x - cx
        let dy = mousePos.y - cy
        return sqrt(dx * dx + dy * dy)
    }

    private func computeReward(heatmap: HeatmapGrid) -> Double {
        var reward: Double = 0

        // Reward = change in distance to mouse: positive if getting closer
        let currentDist = currentMouseDistance()
        reward += prevMouseDistance - currentDist
        prevMouseDistance = currentDist

        // Click penalty
        if let currentClick = MouseTracker.shared.lastClickOnCharacterTimestamp,
           currentClick != lastClickTimestamp {
            reward -= 50
            lastClickTimestamp = currentClick
        }

        // Edge collision penalty
        if prevHitEdge {
            reward -= 5
        }

        return reward
    }

    // MARK: - Movement

    private func computeTarget(
        from cell: (col: Int, row: Int),
        action: QLearningEngine.Action,
        heatmap: HeatmapGrid,
        window: CharacterWindow
    ) -> (NSPoint, Bool) {
        let bounds = heatmap.screenBounds
        let cellW = bounds.width / Double(heatmap.columns)
        let cellH = bounds.height / Double(heatmap.rows)

        var newCol = cell.col
        var newRow = cell.row

        switch action {
        case .up:    newRow += 1
        case .down:  newRow -= 1
        case .left:  newCol -= 1
        case .right: newCol += 1
        case .stay:  break
        }

        let hitEdge = newCol < 0 || newCol >= heatmap.columns
                   || newRow < 0 || newRow >= heatmap.rows

        newCol = max(0, min(heatmap.columns - 1, newCol))
        newRow = max(0, min(heatmap.rows - 1, newRow))

        let targetX = bounds.origin.x + (Double(newCol) + 0.5) * cellW - window.frame.width / 2
        let targetY = bounds.origin.y + (Double(newRow) + 0.5) * cellH - window.frame.height / 2

        let origin = snapToNearestScreen(NSPoint(x: targetX, y: targetY), window: window)
        return (origin, hitEdge)
    }

    /// Clamp the window origin so it stays within a visible screen.
    private func snapToNearestScreen(_ origin: NSPoint, window: CharacterWindow) -> NSPoint {
        let winCenter = NSPoint(x: origin.x + window.frame.width / 2,
                                y: origin.y + window.frame.height / 2)

        // Find the screen closest to the window center
        var bestScreen = NSScreen.screens.first
        var bestDist = CGFloat.infinity
        for screen in NSScreen.screens {
            let sx = screen.frame.midX
            let sy = screen.frame.midY
            let dist = hypot(winCenter.x - sx, winCenter.y - sy)
            if dist < bestDist {
                bestDist = dist
                bestScreen = screen
            }
        }

        guard let screen = bestScreen else { return origin }

        var snapped = origin
        let sf = screen.frame
        if origin.x + window.frame.width > sf.maxX { snapped.x = sf.maxX - window.frame.width }
        if origin.x < sf.minX { snapped.x = sf.minX }
        if origin.y + window.frame.height > sf.maxY { snapped.y = sf.maxY - window.frame.height }
        if origin.y < sf.minY { snapped.y = sf.minY }
        return snapped
    }
}
