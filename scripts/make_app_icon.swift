import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift scripts/make_app_icon.swift <iconset-dir>\n", stderr)
    exit(64)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let outputs: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for output in outputs {
    let image = drawIcon(size: output.pixels)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(output.name)")
    }
    try png.write(to: iconsetURL.appendingPathComponent(output.name))
}

private func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.shouldAntialias = true
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024

    drawRoundedGradientBackground(in: bounds, radius: 214 * scale)
    drawCard(
        in: rect(x: 244, y: 310, width: 510, height: 388, scale: scale),
        tabWidth: 160 * scale,
        fill: NSColor(red: 0.23, green: 0.28, blue: 0.32, alpha: 1),
        stroke: NSColor.white.withAlphaComponent(0.16),
        offsetAlpha: 0.58
    )
    drawCard(
        in: rect(x: 204, y: 260, width: 550, height: 408, scale: scale),
        tabWidth: 174 * scale,
        fill: NSColor(red: 0.17, green: 0.22, blue: 0.27, alpha: 1),
        stroke: NSColor.white.withAlphaComponent(0.20),
        offsetAlpha: 0.76
    )
    drawCard(
        in: rect(x: 270, y: 218, width: 514, height: 430, scale: scale),
        tabWidth: 190 * scale,
        fill: NSColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1),
        stroke: NSColor.white.withAlphaComponent(0.26),
        offsetAlpha: 1
    )

    drawListLines(scale: scale)
    drawSubtleHighlight(scale: scale)
    return image
}

private func drawRoundedGradientBackground(in rect: NSRect, radius: CGFloat) {
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035), xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.08, green: 0.10, blue: 0.12, alpha: 1),
        NSColor(red: 0.20, green: 0.23, blue: 0.27, alpha: 1)
    ])
    gradient?.draw(in: path, angle: -38)

    NSColor.white.withAlphaComponent(0.09).setStroke()
    path.lineWidth = max(1, rect.width * 0.012)
    path.stroke()
}

private func drawCard(in rect: NSRect, tabWidth: CGFloat, fill: NSColor, stroke: NSColor, offsetAlpha: CGFloat) {
    let tabHeight = rect.height * 0.18
    let radius = rect.width * 0.055
    let tabRect = NSRect(x: rect.minX, y: rect.maxY - tabHeight, width: tabWidth, height: tabHeight)
    let bodyRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tabHeight * 0.28)

    NSColor.black.withAlphaComponent(0.24 * offsetAlpha).setFill()
    NSBezierPath(roundedRect: bodyRect.offsetBy(dx: 0, dy: -18 * rect.width / 514), xRadius: radius, yRadius: radius).fill()

    NSColor(red: 0.20, green: 0.52, blue: 0.92, alpha: 0.96 * offsetAlpha).setFill()
    NSBezierPath(roundedRect: tabRect, xRadius: radius * 0.82, yRadius: radius * 0.82).fill()

    fill.withAlphaComponent(offsetAlpha).setFill()
    NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius).fill()

    stroke.setStroke()
    let outline = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
    outline.lineWidth = max(1, rect.width * 0.011)
    outline.stroke()
}

private func drawListLines(scale: CGFloat) {
    let lineColor = NSColor.white.withAlphaComponent(0.32)
    let blueLine = NSColor(red: 0.20, green: 0.52, blue: 0.92, alpha: 0.95)
    let lines: [(x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor)] = [
        (382, 524, 264, blueLine),
        (382, 454, 310, lineColor),
        (382, 384, 250, lineColor)
    ]

    for line in lines {
        let path = NSBezierPath(roundedRect: rect(x: line.x, y: line.y, width: line.width, height: 24, scale: scale), xRadius: 12 * scale, yRadius: 12 * scale)
        line.color.setFill()
        path.fill()
    }

    for y in [524, 454, 384] as [CGFloat] {
        NSColor(red: 0.20, green: 0.52, blue: 0.92, alpha: 0.88).setFill()
        NSBezierPath(roundedRect: rect(x: 326, y: y - 2, width: 28, height: 28, scale: scale), xRadius: 6 * scale, yRadius: 6 * scale).fill()
    }
}

private func drawSubtleHighlight(scale: CGFloat) {
    let highlight = NSBezierPath(roundedRect: rect(x: 300, y: 610, width: 392, height: 34, scale: scale), xRadius: 17 * scale, yRadius: 17 * scale)
    NSColor.white.withAlphaComponent(0.12).setFill()
    highlight.fill()
}

private func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, scale: CGFloat) -> NSRect {
    NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
}
