import AppKit

enum MeterIcon {
    static func menuBarImage(remainingPercent: Int?) -> NSImage {
        let clampedRemaining = remainingPercent.map { min(max($0, 0), 100) }
        let label = clampedRemaining.map(String.init) ?? "–"
        let fontSize: CGFloat = switch label.count {
        case 1: 10.2
        case 2: 10
        default: 8.2
        }
        let image = NSImage(size: NSSize(width: 21, height: 18), flipped: false) { rect in
            guard let graphicsContext = NSGraphicsContext.current else { return false }
            let context = graphicsContext.cgContext

            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(true)
            context.setShouldSmoothFonts(true)

            let contour = codexContour(in: rect.insetBy(dx: 0.4, dy: 0.2))
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
            let labelY = rect.midY - labelSize.height / 2 - 0.2
            let labelOrigin = NSPoint(
                x: (labelX * scaleX).rounded() / scaleX,
                y: (labelY * scaleY).rounded() / scaleY
            )

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
