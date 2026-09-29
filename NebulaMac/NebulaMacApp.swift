import SwiftUI
import NebulaMacCore
import UserNotifications
import Combine

@main
struct NebulaMacApp: App {
    @StateObject private var nebulaService = NebulaService()
    @StateObject private var configManager = ConfigManager()
    @StateObject private var iconAnimator = IconAnimator()
    @AppStorage("iconArmMode") private var iconArmMode = IconArmMode.perNetwork.rawValue
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @State private var hasAutoConnected = false
    /// Outer subscription — watches the connections dictionary itself.
    @State private var dictionaryCancellable: AnyCancellable?
    /// Inner subscriptions — one per active connection's $state.
    @State private var perConnectionCancellables = Set<AnyCancellable>()

    init() {
        // Point at wherever nebula is actually installed (Homebrew, Nix, ...) unless the
        // stored path already works. Runs before any @AppStorage reader is created.
        let defaults = UserDefaults.standard
        for (key, name) in [("nebulaPath", "nebula"), ("nebulaCertPath", "nebula-cert")] {
            let stored = defaults.string(forKey: key) ?? "/usr/local/bin/\(name)"
            defaults.set(BinaryLocator.resolve(stored: stored, name: name), forKey: key)
        }
    }

    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(nebulaService)
                .environmentObject(configManager)
                .task {
                    if canUseNotifications {
                        await requestNotificationPermission()
                    }
                    await autoConnectIfNeeded()
                    observeStateChanges()
                }
        } label: {
            let count = nebulaService.connectedCount
            Label {
                if count > 0 {
                    Text("Nebula (\(count))")
                } else {
                    Text("Nebula")
                }
            } icon: {
                Image(nsImage: SwirlIconRenderer.image(for: swirlModel, pulse: iconAnimator.pulse))
            }
            .onChange(of: swirlModel.isAnimating, initial: true) { _, animating in
                iconAnimator.setAnimating(animating)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(nebulaService)
                .environmentObject(configManager)
        }
    }

    /// One arm per mesh (in list order), or three synced arms, per Settings.
    private var swirlModel: SwirlModel {
        let states = configManager.meshes.map { nebulaService.connectionState(for: $0).armState }
        return SwirlModel.make(states: states, mode: IconArmMode(rawValue: iconArmMode) ?? .perNetwork)
    }

    private func autoConnectIfNeeded() async {
        guard !hasAutoConnected else { return }
        hasAutoConnected = true

        // Certs first: adoption matches each mesh's utun by its cert IP.
        await configManager.refreshCerts()

        // Always adopt already-running Nebula processes first
        await nebulaService.adoptRunningMeshes(from: configManager.meshes)

        // Then auto-connect saved meshes (skips already-adopted ones)
        if autoConnect {
            nebulaService.autoConnectSavedMeshes(from: configManager.meshes)
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    private func observeStateChanges() {
        // Outer subscription: watch the connections dictionary for additions/removals.
        // Stored separately so inner cleanup doesn't cancel it.
        dictionaryCancellable = nebulaService.$connections
            .receive(on: DispatchQueue.main)
            .sink { connections in
                // Clear inner subscriptions and rebuild for current connection set
                perConnectionCancellables.removeAll()
                for (name, connection) in connections {
                    // Initialize from current state to avoid spurious notification
                    // on subscription replay when connections dictionary changes.
                    var previousState: ConnectionState = connection.state
                    connection.$state
                        .receive(on: DispatchQueue.main)
                        .sink { newState in
                            guard notificationsEnabled, canUseNotifications else { return }

                            switch (previousState, newState) {
                            case (_, .connected(let ip, _)) where !previousState.isConnected:
                                sendNotification(
                                    title: "\(name.capitalized) Connected",
                                    body: "Connected to mesh — \(ip)"
                                )
                            case (.connected, .disconnected):
                                sendNotification(
                                    title: "\(name.capitalized) Disconnected",
                                    body: "VPN connection lost"
                                )
                            case (_, .error(let msg)):
                                sendNotification(
                                    title: "\(name.capitalized) Error",
                                    body: msg
                                )
                            default:
                                break
                            }

                            previousState = newState
                        }
                        .store(in: &perConnectionCancellables)
                }
            }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
