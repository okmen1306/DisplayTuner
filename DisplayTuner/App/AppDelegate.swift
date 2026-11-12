//
//  AppDelegate.swift
//  DisplayTuner
//
//  Görev: Açılış: servisleri başlatır, status item'ı kurar, SMAppService kaydı.
//  Faz: 1  ·  Kararlar: D-07, D-08  (bkz. AGENT_BRIEF.md)
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let dockWatcher = DockWatcher()
    let devices = DeviceRegistry()
    lazy var batteries = BatteryMonitor(registry: devices)
    let notifier = Notifier()
    let profiles = ProfileStore()
    lazy var services = AppServices(devices: devices, batteries: batteries, notifier: notifier, profiles: profiles)
    lazy var mainWindow = MainWindowController(services: services)
    lazy var automation = AutomationEngine(services: services)
    let hotkeys = HotkeyManager()
    let outputSwitcher = OutputSwitcher()
    lazy var colorGuard = ColorGuard(store: profiles)
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Testlerde uygulama test hostu olarak açılır; donanıma dokunmasın (D-132).
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        notifier.start()
        batteries.onThreshold = { [weak self] kind, name, percent, threshold in
            self?.notifier.batteryThreshold(kind: kind, name: name, percent: percent, threshold: threshold)
        }
        batteries.onFullyCharged = { [weak self] kind, name in
            self?.notifier.fullyCharged(kind: kind, name: name)
        }
        batteries.onPresenceChange = { [weak self] kind, present in
            guard let self, kind == .headset,
                  let output = self.outputSwitcher.headsetLinkChanged(isLinked: present) else { return }
            self.notifier.hud(symbol: present ? "headphones" : "speaker.wave.2.fill", text: output)
        }
        statusItem = StatusItemController(mainWindow: mainWindow, services: services)
        dockWatcher.onChange = { [weak self] docked in
            self?.automation.dockChanged(isDocked: docked)
        }
        automation.startMicMonitor()
        services.scrollReverser.startIfEnabled()
        if UserDefaults.standard.object(forKey: "pointerSpeed") != nil { services.pointer.apply() }
        services.cursor.applySaved()
        if services.cursorAppearance.shape != .system { services.cursorAppearance.apply() }
        hotkeys.installDefaults(services: services)
        dockWatcher.start()
        batteries.start()
        profiles.load()
        colorGuard.start()   // Uygulama, renk yönetimi açılana kadar hiçbir şey yazmaz (R3, D-121).
        if let profile = profiles.active {
            Task { await profiles.apply(profile) }   // Açılışta bir kez tam uygulama (mod koşulsuz, D-127).
        }
        settings.applyDefaultsOnFirstLaunch()
    }

    /// Dock'ta ikon yok (D-07); yeniden açılınca ana pencere gösterilir.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return true
    }
}
