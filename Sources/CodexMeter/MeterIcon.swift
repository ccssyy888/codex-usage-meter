import AppKit

enum MeterIcon {
    static let menuBarImage: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = side * 0.30
            let lineWidth = side * 0.115

            context.setShouldAntialias(true)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)

            for segment in 0..<6 {
                let start = degrees(CGFloat(segment) * 60 + 10)
                context.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: start + degrees(40),
                    clockwise: false
                )
                context.strokePath()
            }

            let hubRadius = side * 0.075
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
    }()

    private static func degrees(_ value: CGFloat) -> CGFloat {
        value * .pi / 180
    }
}
