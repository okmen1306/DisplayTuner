//
//  HotkeyManager.swift
//  DisplayTuner
//
//  Görev: Carbon RegisterEventHotKey kısayolları (izin gerektirmez).
//  Faz: 5  ·  Kararlar: D-110  (bkz. AGENT_BRIEF.md)
//

import Carbon.HIToolbox
import Foundation

/// ⌃⌥1…4 ekran profilleri, ⌃⌥E kulaklık EQ hazır ayar döngüsü.
@MainActor
final class HotkeyManager {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    func register(keyCode: Int, modifiers: Int = controlKey | optionKey, action: @escaping () -> Void) {
        let id = UInt32(handlers.count + 1)
        handlers[id] = action
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4454_554E), id: id)   // "DTUN"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }

    func start() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            let id = hotKeyID.id
            MainActor.assumeIsolated { manager.handlers[id]?() }
            return noErr
        }, 1, &spec, context, &eventHandler)
    }

    /// Uygulamanın varsayılan kısayolları (D-110).
    func installDefaults(services: AppServices) {
        let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4]
        for (index, key) in digitKeys.enumerated() {
            register(keyCode: key) {
                services.profiles.select(index: index)
                if let name = services.profiles.active?.name { services.notifier.hud(symbol: "sun.max.fill", text: name) }
            }
        }
        register(keyCode: kVK_ANSI_E) {
            Task {
                guard let headset = services.devices.headset else { return }
                let order: [RazerEQPreset] = [.flat, .game, .music, .movie, .custom]
                let current = await headset.readByte(.eqPreset).flatMap(RazerEQPreset.init(rawValue:)) ?? .flat
                let next = order[((order.firstIndex(of: current) ?? 0) + 1) % order.count]
                if await headset.write(.eqPreset, [next.rawValue]) {
                    services.notifier.hud(symbol: "slider.vertical.3", text: "EQ: \(next.title)")
                }
            }
        }
        start()
    }
}
