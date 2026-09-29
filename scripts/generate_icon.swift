// Generates the app icon PNGs from the same swirl geometry as the menu bar icon.
// Usage: make icon
//   (swiftc -parse-as-library -o .build/generate_icon NebulaMacCore/Swirl.swift scripts/generate_icon.swift
//    && .build/generate_icon NebulaMac/Assets.xcassets/AppIcon.appiconset)
import AppKit

func drawIcon(px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px)

    // macOS icon grid: 824/1024 body with ~185/1024 corner radius.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: s * 185 / 1024, cornerHeight: s * 185 / 1024, transform: nil)

    // Body: deep navy, slightly lighter at the top.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let bg = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.09, green: 0.11, blue: 0.17, alpha: 1),
        CGColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

    // Map the 24×24 swirl design space into the body, flipped to match the menu bar drawing.
    let scale = body.width * 0.78 / 24
    ctx.translateBy(x: s / 2, y: s / 2)
    ctx.scaleBy(x: scale, y: -scale)
    ctx.translateBy(x: -12, y: -12)

    // Soft glow behind the core only.
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.75, green: 0.85, blue: 1, alpha: 0.55),
        CGColor(red: 0.75, green: 0.85, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: SwirlGeometry.center, startRadius: 0,
                           endCenter: SwirlGeometry.center, endRadius: SwirlGeometry.haloRadius * 1.8, options: [])

    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.setFillColor(white)
    ctx.setStrokeColor(white)
    for i in 0..<3 {
        ctx.addLines(between: SwirlGeometry.bulgeOutline(arm: i, of: 3))
        ctx.closePath()
        ctx.fillPath()
        ctx.setLineWidth(SwirlGeometry.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addLines(between: SwirlGeometry.linePoints(arm: i, of: 3, from: SwirlGeometry.bulgeLength - 0.01, to: 1))
        ctx.strokePath()
    }
    let r = SwirlGeometry.coreRadius
    ctx.fillEllipse(in: CGRect(x: 12 - r, y: 12 - r, width: 2 * r, height: 2 * r))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

@main
struct GenerateIcon {
    static func main() throws {
        let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
            let path = "\(outputDir)/icon_\(pt)x\(pt)@\(scale)x.png"
            try drawIcon(px: pt * scale).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        }
    }
}
