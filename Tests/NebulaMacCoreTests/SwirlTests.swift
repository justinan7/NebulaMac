import CoreGraphics
import Foundation
import Testing
@testable import NebulaMacCore

struct SwirlModelTests {
    @Test func perNetworkKeepsOrderAndStates() {
        let m = SwirlModel.make(states: [.on, .off, .error], mode: .perNetwork)
        #expect(m.arms == [.on, .off, .error])
    }

    @Test func noNetworksShowsThreeFaintArms() {
        #expect(SwirlModel.make(states: [], mode: .perNetwork).arms == [.off, .off, .off])
        #expect(SwirlModel.make(states: [], mode: .threeArms).arms == [.off, .off, .off])
    }

    // In three-arm mode all arms stay lit while any connection remains.
    @Test func threeArmsLitWhileAnyNetworkConnected() {
        #expect(SwirlModel.make(states: [.off, .error, .on], mode: .threeArms).arms == [.on, .on, .on])
        #expect(SwirlModel.make(states: [.on], mode: .threeArms).arms == [.on, .on, .on])
    }

    @Test func threeArmsFallBackConnectingThenErrorThenOff() {
        #expect(SwirlModel.make(states: [.error, .connecting], mode: .threeArms).arms == [.connecting, .connecting, .connecting])
        #expect(SwirlModel.make(states: [.off, .error], mode: .threeArms).arms == [.error, .error, .error])
        #expect(SwirlModel.make(states: [.off, .off], mode: .threeArms).arms == [.off, .off, .off])
    }

    @Test func coreLitAndAnimationFlags() {
        #expect(SwirlModel.make(states: [.on, .off], mode: .perNetwork).coreLit)
        #expect(SwirlModel.make(states: [.connecting], mode: .perNetwork).coreLit)
        #expect(!SwirlModel.make(states: [.off, .error], mode: .perNetwork).coreLit)
        #expect(SwirlModel.make(states: [.on, .connecting], mode: .perNetwork).isAnimating)
        #expect(!SwirlModel.make(states: [.on, .error], mode: .perNetwork).isAnimating)
    }
}

struct SwirlGeometryTests {
    func angle(_ p: CGPoint) -> Double {
        atan2(Double(p.y - SwirlGeometry.center.y), Double(p.x - SwirlGeometry.center.x))
    }

    @Test func everyArmStartsInsideTheCore() {
        for n in 1...4 {
            for i in 0..<n {
                #expect(SwirlGeometry.point(arm: i, of: n, t: 0) == SwirlGeometry.center)
            }
        }
    }

    @Test func armsEndAtTheOuterRadius() {
        let end = SwirlGeometry.point(arm: 0, of: 2, t: 1)
        let r = hypot(Double(end.x - SwirlGeometry.center.x), Double(end.y - SwirlGeometry.center.y))
        #expect(abs(r - Double(SwirlGeometry.radius)) < 1e-9)
    }

    @Test func armsAreEvenlyRotated() {
        for n in 2...4 {
            let step = 2 * Double.pi / Double(n)
            for i in 1..<n {
                var d = angle(SwirlGeometry.point(arm: i, of: n, t: 1)) - angle(SwirlGeometry.point(arm: 0, of: n, t: 1))
                d = (d + 4 * Double.pi).truncatingRemainder(dividingBy: 2 * Double.pi)
                #expect(abs(d - step * Double(i)) < 1e-9)
            }
        }
    }

    @Test func bulgeIsWiderAtTheCoreThanAtItsEnd() {
        let outline = SwirlGeometry.bulgeOutline(arm: 0, of: 1)
        let half = outline.count / 2
        func width(_ k: Int) -> Double {   // outline = left edge, then right edge reversed
            let a = outline[k], b = outline[outline.count - 1 - k]
            return hypot(Double(a.x - b.x), Double(a.y - b.y))
        }
        #expect(width(0) > width(half - 1))
        #expect(abs(width(0) - Double(SwirlGeometry.bulgeWidth)) < 0.01)
    }
}
