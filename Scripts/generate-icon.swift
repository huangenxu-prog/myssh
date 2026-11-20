import AppKit

// Minimal dark terminal icon matching the supplied >_ reference.
let size = 1024
let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: bounds.size)
image.lockFocus()
defer { image.unlockFocus() }

let background = NSGradient(colorsAndLocations:
    (NSColor(calibratedRed: 0.065, green: 0.115, blue: 0.19, alpha: 1), 0),
    (NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.09, alpha: 1), 1))!
background.draw(in: bounds, angle: -90)

// Subtle teal halo behind the terminal prompt.
let haloCenter = NSPoint(x: 500, y: 510)
for radius in stride(from: 470, through: 40, by: -5) {
    let progress = 1 - CGFloat(radius) / 470
    NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.43,
            alpha: 0.0035 + progress * 0.0015).setFill()
    NSBezierPath(ovalIn: NSRect(x: haloCenter.x - CGFloat(radius),
                               y: haloCenter.y - CGFloat(radius),
                               width: CGFloat(radius) * 2,
                               height: CGFloat(radius) * 2)).fill()
}

let mint = NSColor(calibratedRed: 0.13, green: 0.98, blue: 0.65, alpha: 1)
func stroke(_ points: [NSPoint], width: CGFloat) {
    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = width
    path.move(to: points[0])
    for point in points.dropFirst() { path.line(to: point) }
    mint.setStroke()
    path.stroke()
}

// Coordinates are converted from the provided 1024-square image.
stroke([NSPoint(x: 263, y: 694), NSPoint(x: 502, y: 512), NSPoint(x: 263, y: 330)], width: 94)
stroke([NSPoint(x: 607, y: 313), NSPoint(x: 744, y: 313)], width: 94)

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
