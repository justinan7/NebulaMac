import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                NetworksTab()
                    .tabItem { Label("Networks", systemImage: "point.3.connected.trianglepath.dotted") }
                GeneralTab()
                    .tabItem { Label("General", systemImage: "gearshape") }
                AdvancedTab()
                    .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            }
            SettingsFooter()
        }
        .frame(width: 520, height: 500)
    }
}
