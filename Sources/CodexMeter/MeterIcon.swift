import AppKit

enum MeterIcon {
    static func menuBarImage(
        remainingPercent: Int?,
        activityPhase: Double = 0,
        activityOpacity: Double = 0
    ) -> NSImage {
        let clampedRemaining = remainingPercent.map { min(max($0, 0), 100) }
        let label = clampedRemaining.map(String.init) ?? "–"
        let fontSize: CGFloat = switch label.count {
        case 1: 10.2
        case 2: 10
        default: 8.2
        }
        let image = NSImage(size: NSSize(width: 29, height: 22), flipped: false) { rect in
            guard let graphicsContext = NSGraphicsContext.current else { return false }
            let context = graphicsContext.cgContext

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(true)
            context.setShouldSmoothFonts(true)

            // Fixed width avoids menu-bar movement as the animation starts/stops.
            // Keep the badge legible and reserve space above and beside it for ash.
            let badgeRect = NSRect(x: rect.midX - 10.5, y: rect.minY, width: 21, height: 18)
            let contour = codexContour(in: badgeRect.insetBy(dx: 0.4, dy: 0.2))
            NSColor.black.setFill()
            contour.fill()

            let layoutAttributes: [NSAttributedString.Key: Any] = [
                .font: quotaFont(ofSize: fontSize),
                .kern: -0.5,
                .foregroundColor: NSColor.black,
            ]
            let labelSize = NSAttributedString(string: label, attributes: layoutAttributes).size()
            let scaleX = max(abs(context.ctm.a), 1)
            let scaleY = max(abs(context.ctm.d), 1)
            let labelX = rect.midX - labelSize.width / 2
            let labelY = badgeRect.midY - labelSize.height / 2 - 0.2
            let labelOrigin = NSPoint(
                x: (labelX * scaleX).rounded() / scaleX,
                y: (labelY * scaleY).rounded() / scaleY
            )

            if activityOpacity > 0 {
                drawEvaporation(
                    in: rect, badge: badgeRect, contour: contour, context: context,
                    phase: activityPhase, opacity: activityOpacity,
                    protectedDigits: NSRect(
                        x: badgeRect.midX - labelSize.width / 2 - 0.6,
                        y: badgeRect.midY - 4.5,
                        width: labelSize.width + 1.2, height: 9
                    )
                )
            }

            graphicsContext.saveGraphicsState()
            graphicsContext.compositingOperation = .clear
            NSAttributedString(string: label, attributes: layoutAttributes).draw(at: labelOrigin)
            graphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Codex Usage Meter"
        return image
    }

    private static func drawEvaporation(
        in rect: NSRect, badge: NSRect, contour: NSBezierPath,
        context: CGContext, phase: Double, opacity: Double, protectedDigits: NSRect
    ) {
        // Large, opaque grains remain visible for most of their upward travel.
        // Asynchronous bites in the rim communicate loss without moving digits.
        let sources: [CGFloat] = [-8.2, -5.8, -3.2, -0.4, 2.8, 5.7, 8.2]
        context.saveGState()
        defer { context.restoreGState() }
        context.addRect(rect)
        context.addRect(protectedDigits)
        context.clip(using: .evenOdd)
        for (index, offset) in sources.enumerated() {
            let progress = (phase + Double(index) * 0.381966).truncatingRemainder(dividingBy: 1)
            let x = badge.midX + offset
            var rim = badge.maxY
            while rim > badge.midY, !contour.contains(NSPoint(x: x, y: rim)) { rim -= 0.1 }
            let grainSize = CGFloat(1.8 + Double(index % 3) * 0.4)
            let erosion = sin(.pi * min(1, progress / 0.60))
            context.setBlendMode(.destinationOut)
            context.setFillColor(NSColor.black.withAlphaComponent(opacity * erosion * 0.9).cgColor)
            context.fillEllipse(in: NSRect(
                x: x - grainSize * 0.6, y: rim - grainSize * 0.8,
                width: grainSize * 1.2, height: grainSize * 1.2
            ))

            let travel = max(1, rect.maxY - 0.8 - rim)
            let drift = (index.isMultiple(of: 2) ? -1.8 : 1.8) * progress
            let size = grainSize * (1 - progress * 0.25)
            let alpha = opacity * min(1, progress / 0.08) * min(1, (1 - progress) / 0.30)
            context.setBlendMode(.normal)
            context.setFillColor(NSColor.black.withAlphaComponent(alpha).cgColor)
            context.fill(CGRect(
                x: x + drift - size / 2,
                y: rim + 0.5 + progress * travel - size / 2,
                width: size, height: size
            ))
        }
    }

    private static func codexContour(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let horizontalRadius = rect.width / 2
        let verticalRadius = rect.height / 2
        let pointCount = 96

        for index in 0...pointCount {
            let angle = CGFloat(index) / CGFloat(pointCount) * 2 * .pi
            let lobe = 0.91 + 0.09 * cos(6 * (angle - .pi / 2))
            let point = NSPoint(
                x: center.x + cos(angle) * horizontalRadius * lobe,
                y: center.y + sin(angle) * verticalRadius * lobe
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }

        path.close()
        return path
    }

    private static func quotaFont(ofSize size: CGFloat) -> NSFont {
        let openAIFontNames = [
            "OpenAISans-Semibold",
            "OpenAI Sans Semibold",
            "OpenAISansSemibold",
            "OpenAI Sans",
        ]

        for fontName in openAIFontNames {
            if let font = NSFont(name: fontName, size: size) {
                return font
            }
        }

        return .systemFont(ofSize: size, weight: .bold)
    }
}
