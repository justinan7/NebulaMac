#!/usr/bin/swift
import AppKit
import CoreGraphics

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let center = CGPoint(x: size / 2, y: size / 2)
    let radius = size * 0.42

    // Background: rounded rectangle with deep space gradient
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: size * 0.02, dy: size * 0.02),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius,
                        transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Radial gradient background: deep purple to dark navy
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.25, green: 0.10, blue: 0.45, alpha: 1.0),
        CGColor(red: 0.06, green: 0.04, blue: 0.15, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: center.x * 0.85, y: center.y * 1.15),
                               startRadius: 0,
                               endCenter: center,
                               endRadius: size * 0.75,
                               options: .drawsAfterEndLocation)
    }

    // Subtle nebula glow in the center
    let glowColors = [
        CGColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 0.3),
        CGColor(red: 0.2, green: 0.1, blue: 0.5, alpha: 0.0)
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGrad,
                               startCenter: center,
                               startRadius: 0,
                               endCenter: center,
                               endRadius: radius * 0.8,
                               options: [])
    }

    // Mesh nodes: positions in a roughly hexagonal/mesh layout
    struct Node {
        let x: CGFloat
        let y: CGFloat
    }

    let nodes: [Node] = [
        // Center
        Node(x: 0.50, y: 0.50),
        // Inner ring
        Node(x: 0.50, y: 0.28),
        Node(x: 0.69, y: 0.39),
        Node(x: 0.69, y: 0.61),
        Node(x: 0.50, y: 0.72),
        Node(x: 0.31, y: 0.61),
        Node(x: 0.31, y: 0.39),
        // Outer accents
        Node(x: 0.35, y: 0.20),
        Node(x: 0.65, y: 0.20),
        Node(x: 0.80, y: 0.50),
        Node(x: 0.65, y: 0.80),
        Node(x: 0.35, y: 0.80),
        Node(x: 0.20, y: 0.50),
    ]

    // Connections (index pairs)
    let connections: [(Int, Int)] = [
        // Center to inner ring
        (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6),
        // Inner ring
        (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1),
        // Inner to outer
        (1, 7), (1, 8), (2, 8), (2, 9), (3, 9), (3, 10),
        (4, 10), (4, 11), (5, 11), (5, 12), (6, 12), (6, 7),
        // Outer ring partial
        (7, 8), (9, 10), (11, 12),
    ]

    // Draw connections as glowing lines
    for (i, j) in connections {
        let from = CGPoint(x: nodes[i].x * size, y: nodes[i].y * size)
        let to = CGPoint(x: nodes[j].x * size, y: nodes[j].y * size)

        // Outer glow
        ctx.setStrokeColor(CGColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.15))
        ctx.setLineWidth(max(size * 0.012, 1.5))
        ctx.setLineCap(.round)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()

        // Core line
        let isInner = i == 0 || (i <= 6 && j <= 6)
        ctx.setStrokeColor(CGColor(red: 0.4, green: 0.7, blue: 1.0, alpha: isInner ? 0.6 : 0.35))
        ctx.setLineWidth(max(size * 0.005, 0.8))
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
    }

    // Draw nodes
    for (idx, node) in nodes.enumerated() {
        let pos = CGPoint(x: node.x * size, y: node.y * size)
        let isCenter = idx == 0
        let isInner = idx <= 6
        let nodeRadius = isCenter ? size * 0.035 : (isInner ? size * 0.022 : size * 0.015)

        // Outer glow
        let glowRadius = nodeRadius * 3.0
        let nodeGlowColors = [
            CGColor(red: 0.4, green: 0.7, blue: 1.0, alpha: isCenter ? 0.5 : 0.25),
            CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.0)
        ] as CFArray
        if let nodeGlow = CGGradient(colorsSpace: colorSpace, colors: nodeGlowColors, locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(nodeGlow,
                                   startCenter: pos,
                                   startRadius: 0,
                                   endCenter: pos,
                                   endRadius: glowRadius,
                                   options: [])
        }

        // Node dot
        let nodeRect = CGRect(x: pos.x - nodeRadius, y: pos.y - nodeRadius,
                              width: nodeRadius * 2, height: nodeRadius * 2)
        ctx.setFillColor(CGColor(red: 0.6, green: 0.85, blue: 1.0, alpha: isCenter ? 1.0 : 0.9))
        ctx.fillEllipse(in: nodeRect)

        // Bright center highlight
        if isCenter || isInner {
            let highlightRadius = nodeRadius * 0.5
            let highlightRect = CGRect(x: pos.x - highlightRadius, y: pos.y - highlightRadius,
                                       width: highlightRadius * 2, height: highlightRadius * 2)
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8))
            ctx.fillEllipse(in: highlightRect)
        }
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Required sizes: (point size, scale) -> pixel size
let sizes: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

for s in sizes {
    let px = s.pt * s.scale
    let image = drawIcon(size: CGFloat(px))
    let filename = "icon_\(s.pt)x\(s.pt)@\(s.scale)x.png"
    savePNG(image, to: "\(outputDir)/\(filename)")
}

print("Done! Generated all icon sizes.")
