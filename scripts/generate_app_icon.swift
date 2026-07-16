#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift scripts/generate_app_icon.swift <resources-directory>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default
let temporaryDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("CodexUsageMeterIcon-\(UUID().uuidString)", isDirectory: true)

try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
var generationSucceeded = false
defer {
    if generationSucceeded {
        try? fileManager.removeItem(at: temporaryDirectory)
    }
}

func renderIcon(pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    let scale = CGFloat(pixelSize) / 1024
    let canvas = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let tile = canvas.insetBy(dx: 72 * scale, dy: 72 * scale)
    let center = CGPoint(x: canvas.midX, y: canvas.midY)
    let background = NSColor(calibratedRed: 0.035, green: 0.105, blue: 0.090, alpha: 1)
    let foreground = NSColor(calibratedRed: 0.955, green: 0.960, blue: 0.935, alpha: 1)
    let accent = NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.57, alpha: 1)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.cgContext.clear(canvas)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 34 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.set()

    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 218 * scale, yRadius: 218 * scale)
    background.setFill()
    tilePath.fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    let insetStroke = NSBezierPath(roundedRect: tile.insetBy(dx: 5 * scale, dy: 5 * scale), xRadius: 213 * scale, yRadius: 213 * scale)
    insetStroke.lineWidth = 10 * scale
    foreground.withAlphaComponent(0.08).setStroke()
    insetStroke.stroke()

    for segment in 0..<6 {
        let arc = NSBezierPath()
        let startAngle = CGFloat(segment) * 60 + 10
        arc.appendArc(withCenter: center, radius: 238 * scale, startAngle: startAngle, endAngle: startAngle + 40)
        arc.lineWidth = 92 * scale
        arc.lineCapStyle = .round
        (segment == 1 ? accent : foreground).setStroke()
        arc.stroke()
    }

    let hubOuter = NSBezierPath(ovalIn: CGRect(
        x: center.x - 70 * scale,
        y: center.y - 70 * scale,
        width: 140 * scale,
        height: 140 * scale
    ))
    foreground.setFill()
    hubOuter.fill()

    let hubInner = NSBezierPath(ovalIn: CGRect(
        x: center.x - 29 * scale,
        y: center.y - 29 * scale,
        width: 58 * scale,
        height: 58 * scale
    ))
    background.setFill()
    hubInner.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

func runTool(_ executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.executableNotLoadable)
    }
}

let tiffSizes = [16, 32, 48, 128, 256, 512, 1024]
var tiffFiles: [URL] = []

for size in tiffSizes {
    let png = temporaryDirectory.appendingPathComponent("icon_\(size).png")
    let tiff = temporaryDirectory.appendingPathComponent("icon_\(size).tiff")
    try renderIcon(pixelSize: size).write(to: png)
    try runTool("/usr/bin/sips", arguments: ["-s", "format", "tiff", png.path, "--out", tiff.path])
    tiffFiles.append(tiff)
}

let combinedTiff = temporaryDirectory.appendingPathComponent("AppIcon.tiff")
try runTool(
    "/usr/bin/tiffutil",
    arguments: ["-catnosizecheck"] + tiffFiles.map(\.path) + ["-out", combinedTiff.path]
)
try runTool(
    "/usr/bin/tiff2icns",
    arguments: [combinedTiff.path, outputDirectory.appendingPathComponent("AppIcon.icns").path]
)
generationSucceeded = true
