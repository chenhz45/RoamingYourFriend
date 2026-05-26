import AppKit

final class CharacterView: NSView {

    // MARK: - Configuration

    var avatarImagePath: String? = nil {
        didSet { loadAvatarImage() }
    }

    var bodyColor: NSColor = NSColor(white: 0.25, alpha: 0.85)

    /// When non-nil, a speech bubble is drawn above the character's head.
    var bubbleText: String? = nil {
        didSet { needsDisplay = true }
    }

    // MARK: - Animation state

    private var animationTimer: Timer?
    private var animationStartTime: CFTimeInterval = 0

    // MARK: - Cached image

    private var avatarImage: NSImage?

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        guard animationTimer == nil else { return }
        animationStartTime = CACurrentMediaTime()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    // MARK: - Image loading

    private func loadAvatarImage() {
        guard let path = avatarImagePath else {
            avatarImage = nil
            needsDisplay = true
            return
        }
        avatarImage = NSImage(contentsOfFile: path)
        needsDisplay = true
    }

    /// Pixel-grid scale: content is rendered at 1/scale resolution then scaled up
    /// with nearest-neighbour for a uniform pixel-art look.
    private let pixelScale: CGFloat = 3.0

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let elapsed = CACurrentMediaTime() - animationStartTime
        let bobY = sin(elapsed * 2.0 * .pi * 1.8) * 4.0

        // --- Offscreen low-res bitmap for pixel-art effect ---
        let smallW = Int(bounds.width / pixelScale)
        let smallH = Int(bounds.height / pixelScale)
        let smallBounds = NSRect(x: 0, y: 0, width: CGFloat(smallW), height: CGFloat(smallH))

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: smallW,
            pixelsHigh: smallH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: smallW * 4,
            bitsPerPixel: 32
        ) else { return }

        guard let offscreen = NSGraphicsContext(bitmapImageRep: bitmap) else { return }

        offscreen.cgContext.setShouldAntialias(false)
        offscreen.cgContext.setAllowsAntialiasing(false)
        offscreen.imageInterpolation = .none

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = offscreen

        let transform = NSAffineTransform()
        transform.scale(by: 1.0 / pixelScale)
        transform.concat()

        drawCharacterContent(elapsed: elapsed, bobY: bobY)

        NSGraphicsContext.restoreGraphicsState()

        // Scale up with nearest-neighbour
        guard let cgImage = bitmap.cgImage else { return }
        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: cgImage, size: smallBounds.size).draw(in: bounds)

        // Draw bubble text at full resolution (readable, not pixelated)
        if let text = bubbleText {
            let headCY = 145.0 + bobY
            drawBubbleText(text: text, anchorX: bounds.midX, anchorY: headCY + 25 + 4)
        }
    }

    private func drawCharacterContent(elapsed: CFTimeInterval, bobY: CGFloat) {
        let centerX = bounds.midX
        let headCY = 145.0 + bobY

        let headRadius: CGFloat = 25
        let headRect = NSRect(
            x: centerX - headRadius,
            y: headCY - headRadius,
            width: headRadius * 2,
            height: headRadius * 2
        )

        // ---- Wings (semi-transparent, behind head) ----
        let wingFlutter = sin(elapsed * 2.0 * .pi * 4.5) * 2.0
        let wingLen: CGFloat = 44
        let wingWide: CGFloat = 18
        let wingAngle: CGFloat = 0.5

        NSColor(white: 0.9, alpha: 0.32).setFill()
        NSColor(white: 0.5, alpha: 0.2).setStroke()

        let leftWing = NSBezierPath(ovalIn: NSRect(x: 0, y: -wingWide / 2, width: wingLen, height: wingWide))
        let rightWing = NSBezierPath(ovalIn: NSRect(x: 0, y: -wingWide / 2, width: wingLen, height: wingWide))

        for (wing, anchorX, anchorY, flip, angleOff) in [
            (leftWing, centerX - headRadius * 0.1, headCY - 2, CGFloat(1), wingAngle + wingFlutter * 0.01),
            (rightWing, centerX + headRadius * 0.1, headCY - 2, CGFloat(-1), -wingAngle + wingFlutter * 0.01)
        ] {
            NSGraphicsContext.current?.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: anchorX, yBy: anchorY)
            t.rotate(byDegrees: angleOff * 180 / .pi)
            t.scaleX(by: flip, yBy: 1)
            t.concat()
            wing.fill()
            wing.lineWidth = 0.5
            wing.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        // ---- Head ----
        NSGraphicsContext.current?.saveGraphicsState()
        let headClip = NSBezierPath(ovalIn: headRect)
        headClip.addClip()

        if let img = avatarImage {
            img.draw(in: headRect)
        } else {
            // Placeholder face
            NSColor.systemGray.withAlphaComponent(0.3).setFill()
            headClip.fill()

            // Eyes
            let eyeRadius: CGFloat = 3
            let leftEye = NSRect(x: centerX - 9 - eyeRadius, y: headCY - eyeRadius + 2, width: eyeRadius * 2, height: eyeRadius * 2)
            let rightEye = NSRect(x: centerX + 9 - eyeRadius, y: headCY - eyeRadius + 2, width: eyeRadius * 2, height: eyeRadius * 2)
            NSColor.darkGray.setFill()
            NSBezierPath(ovalIn: leftEye).fill()
            NSBezierPath(ovalIn: rightEye).fill()

            // Mouth
            let mouthPath = NSBezierPath()
            mouthPath.move(to: NSPoint(x: centerX - 7, y: headCY - 10))
            mouthPath.curve(to: NSPoint(x: centerX + 7, y: headCY - 10),
                           controlPoint1: NSPoint(x: centerX - 3, y: headCY - 16),
                           controlPoint2: NSPoint(x: centerX + 3, y: headCY - 16))
            mouthPath.lineWidth = 1.5
            NSColor.darkGray.setStroke()
            mouthPath.stroke()
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // Head outline
        NSColor(white: 0.3, alpha: 0.6).setStroke()
        headClip.lineWidth = 1.5
        headClip.stroke()

        // ---- Antennae (cockroach style, independent wobble) ----
        let antWobble = sin(elapsed * 2.0 * .pi * 2.3 + 0.7) * 2.5
        let antBaseY = headCY + headRadius - 4
        let antBaseLX = centerX - headRadius * 0.55
        let antBaseRX = centerX + headRadius * 0.55
        let antLen: CGFloat = 18
        let bulbRadius: CGFloat = 2.5

        bodyColor.setStroke()
        bodyColor.setFill()

        let antLPath = NSBezierPath()
        antLPath.move(to: NSPoint(x: antBaseLX, y: antBaseY))
        antLPath.curve(to: NSPoint(x: antBaseLX - 9 + antWobble, y: antBaseY + antLen),
                       controlPoint1: NSPoint(x: antBaseLX - 5, y: antBaseY + 9),
                       controlPoint2: NSPoint(x: antBaseLX - 11 + antWobble * 0.5, y: antBaseY + 18))
        antLPath.lineWidth = 1.5
        antLPath.stroke()

        let leftBulb = NSRect(x: antBaseLX - 9 + antWobble - bulbRadius,
                               y: antBaseY + antLen - bulbRadius,
                               width: bulbRadius * 2, height: bulbRadius * 2)
        NSBezierPath(ovalIn: leftBulb).fill()

        let antRPath = NSBezierPath()
        antRPath.move(to: NSPoint(x: antBaseRX, y: antBaseY))
        antRPath.curve(to: NSPoint(x: antBaseRX + 9 - antWobble, y: antBaseY + antLen),
                       controlPoint1: NSPoint(x: antBaseRX + 5, y: antBaseY + 9),
                       controlPoint2: NSPoint(x: antBaseRX + 11 - antWobble * 0.5, y: antBaseY + 18))
        antRPath.lineWidth = 1.5
        antRPath.stroke()

        let rightBulb = NSRect(x: antBaseRX + 9 - antWobble - bulbRadius,
                                y: antBaseY + antLen - bulbRadius,
                                width: bulbRadius * 2, height: bulbRadius * 2)
        NSBezierPath(ovalIn: rightBulb).fill()

        // ---- Limbs (grow directly from the circular avatar) ----

        bodyColor.setStroke()

        // Arms
        let armL_x = centerX - headRadius
        let armR_x = centerX + headRadius
        let armY   = headCY + 6

        let armPath = NSBezierPath()
        armPath.move(to: NSPoint(x: armL_x, y: armY))
        armPath.curve(to: NSPoint(x: armL_x - 6, y: armY - 22),
                      controlPoint1: NSPoint(x: armL_x - 10, y: armY - 6),
                      controlPoint2: NSPoint(x: armL_x - 8, y: armY - 16))
        armPath.move(to: NSPoint(x: armR_x, y: armY))
        armPath.curve(to: NSPoint(x: armR_x + 6, y: armY - 22),
                      controlPoint1: NSPoint(x: armR_x + 10, y: armY - 6),
                      controlPoint2: NSPoint(x: armR_x + 8, y: armY - 16))
        armPath.lineWidth = 2.5
        armPath.stroke()

        // Middle legs (between arms and legs, for 6-legged cockroach look)
        let midL_x = centerX - headRadius * 0.88
        let midR_x = centerX + headRadius * 0.88
        let midY = headCY - 4

        let midPath = NSBezierPath()
        midPath.move(to: NSPoint(x: midL_x, y: midY))
        midPath.curve(to: NSPoint(x: midL_x - 7, y: midY - 20),
                      controlPoint1: NSPoint(x: midL_x - 3, y: midY - 7),
                      controlPoint2: NSPoint(x: midL_x - 6, y: midY - 14))
        midPath.move(to: NSPoint(x: midR_x, y: midY))
        midPath.curve(to: NSPoint(x: midR_x + 7, y: midY - 20),
                      controlPoint1: NSPoint(x: midR_x + 3, y: midY - 7),
                      controlPoint2: NSPoint(x: midR_x + 6, y: midY - 14))
        midPath.lineWidth = 2.5
        midPath.stroke()

        // Legs
        let legDX = headRadius * 0.6
        let legDY = sqrt(headRadius * headRadius - legDX * legDX)
        let legL_x = centerX - legDX
        let legR_x = centerX + legDX
        let legY   = headCY - legDY

        let legPath = NSBezierPath()
        legPath.move(to: NSPoint(x: legL_x, y: legY))
        legPath.curve(to: NSPoint(x: legL_x - 4, y: legY - 26),
                      controlPoint1: NSPoint(x: legL_x - 2, y: legY - 10),
                      controlPoint2: NSPoint(x: legL_x - 5, y: legY - 18))
        legPath.move(to: NSPoint(x: legR_x, y: legY))
        legPath.curve(to: NSPoint(x: legR_x + 4, y: legY - 26),
                      controlPoint1: NSPoint(x: legR_x + 2, y: legY - 10),
                      controlPoint2: NSPoint(x: legR_x + 5, y: legY - 18))
        legPath.lineWidth = 2.5
        legPath.stroke()

        // ---- Speech bubble background (pixel-style via offscreen bitmap) ----
        if let text = bubbleText {
            drawSpeechBubbleBackground(text: text, anchorX: centerX, anchorY: headCY + headRadius + 4)
        }
    }

    // MARK: - Speech bubble

    /// Lays out the speech bubble geometry (does not draw).
    private func bubbleLayout(text: String, anchorX: CGFloat, anchorY: CGFloat) -> (bubble: NSRect, textFrame: NSRect) {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let padX: CGFloat = 10
        let padY: CGFloat = 6
        let bubbleW = textSize.width + padX * 2
        let bubbleH = textSize.height + padY * 2

        let bubbleX = anchorX - bubbleW / 2
        let bubbleY = anchorY

        let bubbleRect = NSRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        let textRect = NSRect(x: bubbleX + padX, y: bubbleY + padY, width: textSize.width, height: textSize.height)
        return (bubbleRect, textRect)
    }

    /// Draws only the bubble shape (fill + stroke) — called inside the offscreen pixel bitmap.
    private func drawSpeechBubbleBackground(text: String, anchorX: CGFloat, anchorY: CGFloat) {
        let cornerR: CGFloat = 8
        let tipH: CGFloat = 5

        let (bubbleRect, _) = bubbleLayout(text: text, anchorX: anchorX, anchorY: anchorY)
        let bubbleY = bubbleRect.origin.y

        let path = NSBezierPath()
        path.appendRoundedRect(bubbleRect, xRadius: cornerR, yRadius: cornerR)
        path.move(to: NSPoint(x: anchorX - 5, y: bubbleY))
        path.line(to: NSPoint(x: anchorX, y: bubbleY - tipH))
        path.line(to: NSPoint(x: anchorX + 5, y: bubbleY))
        path.close()

        NSColor.white.withAlphaComponent(0.92).setFill()
        path.fill()
        NSColor(white: 0.6, alpha: 0.5).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    /// Draws the bubble text at full resolution — called AFTER the pixel bitmap is composited.
    private func drawBubbleText(text: String, anchorX: CGFloat, anchorY: CGFloat) {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let (_, textFrame) = bubbleLayout(text: text, anchorX: anchorX, anchorY: anchorY)
        (text as NSString).draw(
            at: textFrame.origin,
            withAttributes: [.font: font, .foregroundColor: NSColor.darkGray]
        )
    }
}
