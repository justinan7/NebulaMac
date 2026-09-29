import AppKit
import SwiftUI
import NebulaMacCore

/// Draws the menu-bar nebula swirl as a template image (macOS tints it for light/dark;
/// faint arms and the glow are just transparency).
enum SwirlIconRenderer {
    static let size = NSSize(width: 18, height: 18)

    /// `pulse` (0...1) drives the brightness of connecting arms.
    static func image(for model: SwirlModel, pulse: CGFloat = 1) -> NSImage {
        let image = NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: rect.width / 24, y: rect.height / 24)
            let ink = NSColor.black.cgColor
            let n = model.arms.count

            if model.coreLit {
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.22).cgColor)
                ctx.fillEllipse(in: circle(SwirlGeometry.center, SwirlGeometry.haloRadius))
            }

            for (i, state) in model.arms.enumerated() {
                let alpha: CGFloat
                switch state {
                case .on, .error: alpha = 1
                case .off: alpha = 0.28
                case .connecting: alpha = 0.25 + 0.75 * pulse
                }
                // One transparency layer per arm so the bulge/line overlap doesn't double up.
                ctx.saveGState()
                ctx.setAlpha(alpha)
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                drawArm(ctx, ink: ink, arm: i, of: n, broken: state == .error)
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }

            if model.coreLit {
                ctx.setFillColor(ink)
                ctx.fillEllipse(in: circle(SwirlGeometry.center, SwirlGeometry.coreRadius))
            } else {
                ctx.setStrokeColor(ink)
                ctx.setLineWidth(1.1)
                ctx.strokeEllipse(in: circle(SwirlGeometry.center, 1.8))
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawArm(_ ctx: CGContext, ink: CGColor, arm i: Int, of n: Int, broken: Bool) {
        let tEnd: CGFloat = broken ? 0.5 : 1
        ctx.setFillColor(ink)
        ctx.setStrokeColor(ink)

        ctx.addLines(between: SwirlGeometry.bulgeOutline(arm: i, of: n, upTo: min(SwirlGeometry.bulgeLength, tEnd)))
        ctx.closePath()
        ctx.fillPath()

        if tEnd > SwirlGeometry.bulgeLength {
            ctx.setLineWidth(SwirlGeometry.lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addLines(between: SwirlGeometry.linePoints(arm: i, of: n, from: SwirlGeometry.bulgeLength - 0.01, to: tEnd))
            ctx.strokePath()
        }
        if broken {
            // Error: the arm breaks off, leaving a detached dot near the tip.
            ctx.fillEllipse(in: circle(SwirlGeometry.point(arm: i, of: n, t: 0.92), 1.25))
        }
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect {
        CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
    }
}

/// Drives the connecting-arm pulse; only ticks while something is connecting.
@MainActor
final class IconAnimator: ObservableObject {
    @Published private(set) var pulse: CGFloat = 1
    private var timer: Timer?

    func setAnimating(_ animating: Bool) {
        if animating, timer == nil {
            let start = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                let phase = Date().timeIntervalSince(start) / 1.1 * 2 * .pi
                Task { @MainActor in self?.pulse = CGFloat(0.5 - 0.5 * cos(phase)) }
            }
        } else if !animating {
            timer?.invalidate()
            timer = nil
            pulse = 1
        }
    }
}

extension ConnectionState {
    /// How this connection appears as a swirl arm.
    var armState: ArmState {
        switch self {
        case .connected: return .on
        case .connecting, .disconnecting: return .connecting
        case .error: return .error
        case .disconnected: return .off
        }
    }
}
