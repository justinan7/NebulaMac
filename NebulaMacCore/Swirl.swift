import CoreGraphics
import Foundation

/// State of one arm of the menu-bar swirl.
public enum ArmState: Equatable {
    case on, off, connecting, error
}

/// How the menu-bar swirl maps networks to arms.
public enum IconArmMode: String, CaseIterable {
    /// One arm per network (default).
    case perNetwork
    /// Always three arms, all showing one combined state.
    case threeArms
}

/// What the menu-bar swirl should show.
public struct SwirlModel: Equatable {
    public let arms: [ArmState]

    /// Filled core + glow when anything is up (or coming up); hollow ring otherwise.
    public var coreLit: Bool { arms.contains { $0 == .on || $0 == .connecting } }
    /// Only animate (pulse) while something is connecting.
    public var isAnimating: Bool { arms.contains(.connecting) }

    public static func make(states: [ArmState], mode: IconArmMode) -> SwirlModel {
        if states.isEmpty { return SwirlModel(arms: [.off, .off, .off]) }
        switch mode {
        case .perNetwork:
            return SwirlModel(arms: states)
        case .threeArms:
            let combined = combine(states)
            return SwirlModel(arms: [combined, combined, combined])
        }
    }

    /// Lit while any network remains connected; otherwise connecting > error > off.
    static func combine(_ states: [ArmState]) -> ArmState {
        if states.contains(.on) { return .on }
        if states.contains(.connecting) { return .connecting }
        if states.contains(.error) { return .error }
        return .off
    }
}

/// Swirl geometry in a 24×24 design space (scaled down when drawn).
/// Arms curl out of the centre and swell into a central bulge.
public enum SwirlGeometry {
    public static let center = CGPoint(x: 12, y: 12)
    public static let radius: CGFloat = 10.6
    /// How far each arm curls, in radians (~210°).
    public static let sweep: CGFloat = 210 * .pi / 180
    public static let lineWidth: CGFloat = 1.7
    /// Arm width where it enters the core.
    public static let bulgeWidth: CGFloat = 4.2
    /// Fraction of the arm's length that swells into the bulge.
    public static let bulgeLength: CGFloat = 0.28
    public static let coreRadius: CGFloat = 2.5
    public static let haloRadius: CGFloat = 4.3

    /// A point along arm `i` of `n`, `t` from 0 (centre) to 1 (tip).
    public static func point(arm i: Int, of n: Int, t: CGFloat) -> CGPoint {
        let a = CGFloat(i) * 2 * .pi / CGFloat(max(n, 1)) + t * sweep
        let r = radius * t
        return CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a))
    }

    /// Points along an arm's centre line between `t0` and `t1`.
    public static func linePoints(arm i: Int, of n: Int, from t0: CGFloat, to t1: CGFloat, steps: Int = 40) -> [CGPoint] {
        (0...steps).map { k in point(arm: i, of: n, t: t0 + (t1 - t0) * CGFloat(k) / CGFloat(steps)) }
    }

    /// Filled outline of the bulge: left edge out, right edge back; width `bulgeWidth` → `lineWidth`.
    public static func bulgeOutline(arm i: Int, of n: Int, upTo tEnd: CGFloat = bulgeLength, steps: Int = 30) -> [CGPoint] {
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for k in 0...steps {
            let f = CGFloat(k) / CGFloat(steps)
            let t = tEnd * f
            let p = point(arm: i, of: n, t: t)
            let q = point(arm: i, of: n, t: t + 0.005)
            let dx = q.x - p.x, dy = q.y - p.y
            let len = max(hypot(dx, dy), .ulpOfOne)
            let nx = -dy / len, ny = dx / len
            let half = (bulgeWidth * (1 - f) + lineWidth * f) / 2
            left.append(CGPoint(x: p.x + nx * half, y: p.y + ny * half))
            right.append(CGPoint(x: p.x - nx * half, y: p.y - ny * half))
        }
        return left + right.reversed()
    }
}
