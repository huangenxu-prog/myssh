import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
defer { image.unlockFocus() }

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSGradient(starting: NSColor(calibratedRed: 0.02, green: 0.70, blue: 0.98, alpha: 1),
                    ending: NSColor(calibratedRed: 0.48, green: 0.09, blue: 0.96, alpha: 1))!
bg.draw(in: bounds, angle: -25)

func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 32
shadow.shadowOffset = NSSize(width: 0, height: -14)
NSGraphicsContext.saveGraphicsState()
shadow.set()
rounded(NSRect(x: 120, y: 235, width: 784, height: 580), 82, NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.25, alpha: 1))
NSGraphicsContext.restoreGraphicsState()

rounded(NSRect(x: 120, y: 235, width: 784, height: 580), 82, NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.26, alpha: 1))
rounded(NSRect(x: 120, y: 705, width: 784, height: 110), 75, NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.53, alpha: 1))
rounded(NSRect(x: 120, y: 700, width: 784, height: 40), 0, NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.53, alpha: 1))

for (i, color) in [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 190 + i * 66, y: 747, width: 38, height: 38)).fill()
}

func label(_ value: String, x: CGFloat, y: CGFloat, font: CGFloat, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: font, weight: .bold),
        .foregroundColor: color
    ]
    (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}
label(">_", x: 200, y: 485, font: 155, color: NSColor(calibratedRed: 0.30, green: 1, blue: 0.38, alpha: 1))
label("SSH", x: 205, y: 335, font: 155, color: .white)

// VPS server stack with bright status LEDs
for y in [205, 305] {
    rounded(NSRect(x: 625, y: y, width: 310, height: 90), 24, NSColor(calibratedRed: 0.78, green: 0.86, blue: 1, alpha: 1))
    for x in [660, 695, 730] {
        rounded(NSRect(x: x, y: y + 22, width: 13, height: 46), 6, NSColor(calibratedRed: 0.24, green: 0.38, blue: 0.61, alpha: 1))
    }
    NSColor.systemGreen.setFill()
    NSBezierPath(ovalIn: NSRect(x: 863, y: y + 27, width: 35, height: 35)).fill()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: bounds)
NSGraphicsContext.restoreGraphicsState()
let url = URL(fileURLWithPath: "Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try rep.representation(using: .png, properties: [:])!.write(to: url)
print("Generated AppIcon.png")
