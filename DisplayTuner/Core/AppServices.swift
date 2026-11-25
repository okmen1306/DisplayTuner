//
//  AppServices.swift
//  DisplayTuner
//
//  Görev: Sayfaların ihtiyaç duyduğu servislerin tek kabı.
//  Faz: 2  ·  Kararlar: 6  (bkz. AGENT_BRIEF.md)
//

import Foundation

@MainActor
final class AppServices {
    let devices: DeviceRegistry
    let batteries: BatteryMonitor
    let notifier: Notifier
    let profiles: ProfileStore
    let scrollReverser = ScrollReverser()
    let pointer = PointerSettings()
    let cursor = CursorService()
    let cursorAppearance = CursorAppearance()
    let eq = HeadsetEQStore()
    let mouseButtons = MouseButtonMapper()
    let eyeComfort: EyeComfort
    let systemEQ = SystemEQ()

    init(devices: DeviceRegistry, batteries: BatteryMonitor, notifier: Notifier, profiles: ProfileStore) {
        self.devices = devices
        self.batteries = batteries
        self.notifier = notifier
        self.profiles = profiles
        self.eyeComfort = EyeComfort(store: profiles)
    }
}
