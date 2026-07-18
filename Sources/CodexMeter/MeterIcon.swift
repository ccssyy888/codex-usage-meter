import AppKit

enum MeterIcon {
    static func menuBarImage(remainingPercent: Int?) -> NSImage {
        let side: CGFloat = 18
        let fillFraction = remainingPercent.map {
            CGFloat(min(max($0, 0), 100)) / 100
        }
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let hexagon = CGMutablePath()
            hexagon.addLines(between: [
                CGPoint(x: center.x, y: rect.maxY - side * 0.08),
                CGPoint(x: rect.maxX - side * 0.10, y: center.y + side * 0.22),
                CGPoint(x: rect.maxX - side * 0.10, y: center.y - side * 0.22),
                CGPoint(x: center.x, y: rect.minY + side * 0.08),
                CGPoint(x: rect.minX + side * 0.10, y: center.y - side * 0.22),
                CGPoint(x: rect.minX + side * 0.10, y: center.y + side * 0.22),
            ])
            hexagon.closeSubpath()

            context.setShouldAntialias(true)
            context.setLineJoin(.round)

            context.saveGState()
            context.addPath(hexagon)
            context.clip()
            context.setFillColor(NSColor.black.withAlphaComponent(0.10).cgColor)
            context.fill(rect)

            if let fillFraction {
                context.setFillColor(NSColor.black.cgColor)
                context.fill(
                    CGRect(
                        x: rect.minX,
                        y: rect.minY,
                        width: rect.width,
                        height: rect.height * fillFraction
                    )
                )
            }
            context.restoreGState()

            context.addPath(hexagon)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(side * 0.085)
            context.strokePath()

            let hubRadius = side * 0.07
            context.setFillColor(NSColor.black.cgColor)
            context.fillEllipse(
                in: CGRect(
                    x: center.x - hubRadius,
                    y: center.y - hubRadius,
                    width: hubRadius * 2,
                    height: hubRadius * 2
                )
            )
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Codex Usage Meter"
        return image
    }
}
