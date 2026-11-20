// Renders Parrot's app icon (white bars on a black squircle) at every macOS size.
// Usage: swift scripts/make-icon.swift <AppIcon.appiconset dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let sizes: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    // Apple icon grid: 824pt body centered in 1024 canvas, ~185pt corner radius.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 28 * s,
                                                    color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    NSColor.white.withAlphaComponent(0.10).setStroke(); path.lineWidth = 3 * s; path.stroke()
    // Five bars, waveform silhouette.
    let heights: [CGFloat] = [170, 330, 470, 290, 190]
    let w: CGFloat = 54 * s, gap: CGFloat = 46 * s
    let total = CGFloat(heights.count) * w + CGFloat(heights.count - 1) * gap
    var x = body.midX - total / 2
    NSColor.white.setFill()
    for h in heights {
        let hh = h * s
        NSBezierPath(roundedRect: NSRect(x: x, y: body.midY - hh / 2, width: w, height: hh), xRadius: w / 2, yRadius: w / 2).fill()
        x += w + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for (size, scale) in sizes {
    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try! render(size * scale).write(to: out.appendingPathComponent(name))
    images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
}
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]],
                                       options: [.prettyPrinted, .sortedKeys])
try! json.write(to: out.appendingPathComponent("Contents.json"))
print("wrote \(images.count) icons")
