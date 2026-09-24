// Renders MenuType's app icon: a dark squircle with a monospaced "mt", an
// accent cursor block behind the first letter and a caret bar beside it —
// the same visual language as the tape in the panel.
//
// Usage: make-icon <output-dir>   (writes a .iconset directory)
import AppKit

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let accent = NSColor(red: 0.44, green: 0.85, blue: 0.72, alpha: 1)

func draw(size px: Int, to path: String) {
    let s = CGFloat(px) / 1024.0
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Squircle plate, following Apple's icon grid (art inset ~10% of the canvas).
    let inset = 100 * s
    let plate = NSRect(x: inset, y: inset, width: CGFloat(px) - inset * 2, height: CGFloat(px) - inset * 2)
    let squircle = NSBezierPath(roundedRect: plate, xRadius: 185 * s, yRadius: 185 * s)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1),
        NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1),
    ])!
    gradient.draw(in: squircle, angle: -90)
    NSColor(white: 1, alpha: 0.09).setStroke()
    squircle.lineWidth = 2 * s
    squircle.stroke()

    // "mt" in the same monospaced face the tape uses.
    let fontSize = 430 * s
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    let text = "mt" as NSString
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
    let textSize = text.size(withAttributes: attrs)
    let textX = plate.midX - textSize.width / 2 + 30 * s
    let textY = plate.midY - textSize.height / 2 + 10 * s

    // Cursor block behind the first glyph.
    let cell = NSRect(x: textX - 24 * s, y: textY + 18 * s,
                      width: textSize.width / 2 + 30 * s, height: textSize.height - 16 * s)
    accent.withAlphaComponent(0.32).setFill()
    NSBezierPath(roundedRect: cell, xRadius: 40 * s, yRadius: 40 * s).fill()

    // Caret bar to the left, clipped to the plate.
    let caret = NSRect(x: textX - 74 * s, y: cell.minY + 12 * s, width: 16 * s, height: cell.height - 24 * s)
    accent.setFill()
    NSBezierPath(roundedRect: caret, xRadius: 8 * s, yRadius: 8 * s).fill()

    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

for (name, px) in sizes {
    draw(size: px, to: "\(outDir)/\(name).png")
}
print("wrote \(sizes.count) images to \(outDir)")
