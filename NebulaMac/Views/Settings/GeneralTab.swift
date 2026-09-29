import SwiftUI
import NebulaMacCore
import ServiceManagement

struct GeneralTab: View {
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("iconArmMode") private var iconArmMode = IconArmMode.perNetwork.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                Toggle("Reconnect networks on launch", isOn: $autoConnect)
                Toggle("Notify when a network connects or drops", isOn: $notificationsEnabled)
            }
            Section("Menu bar icon") {
                Picker("Arms", selection: $iconArmMode) {
                    Text("One per network").tag(IconArmMode.perNetwork.rawValue)
                    Text("Classic three").tag(IconArmMode.threeArms.rawValue)
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }
}
