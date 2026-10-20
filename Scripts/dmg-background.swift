// The installer window's background, from Tally's look: black glass, its name, light from the bottom edge in the
// icon's green and cyan, light tags for the icons' names and a ledge of light under them. As Brimlight's.
// Usage: swift Scripts/dmg-background.swift OUT_PREFIX  →  OUT_PREFIX.png (640×420) and OUT_PREFIX@2x.png
import AppKit

let out = CommandLine.arguments[1]
let W = 640.0, H = 420.0
let green = NSColor(red: 0x34 / 255, green: 0xD3 / 255, blue: 0x99 / 255, alpha: 1)
let cyan = NSColor(red: 0x22 / 255, green: 0xD3 / 255, blue: 0xEE / 255, alpha: 1)

func write(_ text: String, size: CGFloat, weight: NSFont.Weight, white: CGFloat, alpha: CGFloat, y: Double) {
    let words = text as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                     .foregroundColor: NSColor(white: white, alpha: alpha), .kern: size > 20 ? -0.6 : 0]
    words.draw(at: NSPoint(x: (W - words.size(withAttributes: attributes).width) / 2, y: y), withAttributes: attributes)
}

func render(scale: Double, to file: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext // in pixels: scaled once, here
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: H); ctx.scaleBy(x: 1, y: -1) // y down, as the window is laid out
    // Black glass, a little lighter at the top.
    let glass = CGGradient(colorsSpace: nil, colors: [NSColor(white: 0.1, alpha: 1).cgColor, NSColor(white: 0.02, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(glass, start: .zero, end: CGPoint(x: 0, y: H), options: [])
    // Light from the bottom edge: two glows whose shapes sit below the window, so only their light shows (a shadow
    // moves in the bitmap's own space, up being positive, whatever the flip).
    for (x, colour) in [(200.0, green), (440.0, cyan)] {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 62 * scale), blur: 56 * scale, color: colour.withAlphaComponent(0.65).cgColor)
        ctx.setFillColor(colour.cgColor)
        ctx.fillEllipse(in: CGRect(x: x - 190, y: H + 40, width: 380, height: 60))
        ctx.restoreGState()
    }
    // The name, and what it is.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    write("Tally", size: 34, weight: .semibold, white: 1, alpha: 0.95, y: 46)
    write("Your month at a glance. It stays on your Mac.", size: 12.5, weight: .regular, white: 1, alpha: 0.5, y: 94)
    NSGraphicsContext.restoreGraphicsState()
    // Finder writes the icons' names in black over a picture, whatever the appearance: a soft
    // light tag behind each name (where Finder puts it, under icons centred at y 250) keeps them readable.
    for x in [214.0, 426.0] {
        ctx.setFillColor(NSColor(white: 0.92, alpha: 0.9).cgColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: x - 52, y: 323.5, width: 104, height: 20), cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
    }
    // The ledge of light under the icons.
    let ledge = CGGradient(colorsSpace: nil, colors: [NSColor(white: 1, alpha: 0).cgColor, NSColor(white: 1, alpha: 0.5).cgColor,
                                                      NSColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 0.5, 1])!
    ctx.saveGState(); ctx.clip(to: CGRect(x: 110, y: 356, width: 420, height: 1.5))
    ctx.drawLinearGradient(ledge, start: CGPoint(x: 110, y: 0), end: CGPoint(x: 530, y: 0), options: []); ctx.restoreGState()
    // What to do, quietly.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    write("Drag Tally onto Applications", size: 11.5, weight: .medium, white: 1, alpha: 0.55, y: 372)
    NSGraphicsContext.restoreGraphicsState()
    rep.size = NSSize(width: W, height: H) // so the @2x one is known as 144 dpi
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: file))
}

render(scale: 1, to: out + ".png")
render(scale: 2, to: out + "@2x.png")
