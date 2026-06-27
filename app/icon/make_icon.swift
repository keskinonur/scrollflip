import AppKit
import CoreGraphics

// Original ScrollFlip app icon, drawn from scratch (no SF Symbols, no third
// party art). A white mouse on an indigo squircle; its scroll wheel is an
// up/down double chevron, the app's whole idea. Run:
//   swift make_icon.swift <output-iconset-dir>

func makeIcon(_ s: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(s), height: Int(s), bitsPerComponent: 8,
        bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)

    // Squircle background with a top-to-bottom indigo gradient.
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let corner = s * 0.2237
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.46, green: 0.55, blue: 1.00, alpha: 1),
        CGColor(red: 0.28, green: 0.30, blue: 0.86, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // Mouse body: a vertical white capsule, centered.
    let mw = s * 0.36, mh = s * 0.52
    let mx = (s - mw) / 2, my = (s - mh) / 2
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: mx, y: my, width: mw, height: mh),
        cornerWidth: mw / 2, cornerHeight: mw / 2, transform: nil))
    ctx.fillPath()

    // Scroll wheel as an up/down double chevron, in the gradient's deep indigo.
    let cx = s / 2
    let yc = my + mh * 0.66          // sits in the upper third of the mouse
    let aw = mw * 0.40               // chevron half-spread
    let ah = s * 0.060               // chevron height
    let gap = s * 0.022
    ctx.setStrokeColor(CGColor(red: 0.28, green: 0.30, blue: 0.86, alpha: 1))
    ctx.setLineWidth(s * 0.026)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    // up chevron
    ctx.move(to: CGPoint(x: cx - aw / 2, y: yc + gap))
    ctx.addLine(to: CGPoint(x: cx, y: yc + gap + ah))
    ctx.addLine(to: CGPoint(x: cx + aw / 2, y: yc + gap))
    ctx.strokePath()
    // down chevron
    ctx.move(to: CGPoint(x: cx - aw / 2, y: yc - gap))
    ctx.addLine(to: CGPoint(x: cx, y: yc - gap - ah))
    ctx.addLine(to: CGPoint(x: cx + aw / 2, y: yc - gap))
    ctx.strokePath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let out = CommandLine.arguments[1]
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    writePNG(makeIcon(CGFloat(px)), "\(out)/\(name).png")
}
print("wrote \(sizes.count) png files to \(out)")
