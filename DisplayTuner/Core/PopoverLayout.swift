//
//  PopoverLayout.swift
//  DisplayTuner
//
//  Görev: Menü bar panelinin düzeni: ekranların sırası (sürükle-bırak), görünürlüğü, özel adları;
//         göz konforu düğmesi ve pil kartının görünürlüğü.
//  Kararlar: D-161  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation

@MainActor
@Observable
final class PopoverLayout {
    static let shared = PopoverLayout()

    /// Ekran anahtarları: "builtin", "monitor" (PR27R165QC), diğerleri "display-<vendor>-<model>".
    private(set) var order: [String]
    private(set) var hidden: Set<String>
    private(set) var names: [String: String]
    var showEyeComfort: Bool { didSet { defaults.set(showEyeComfort, forKey: "popover.showEye") } }
    var showBatteries: Bool { didSet { defaults.set(showBatteries, forKey: "popover.showBatteries") } }

    private let defaults = UserDefaults.standard

    private init() {
        order = defaults.stringArray(forKey: "popover.order") ?? ["monitor", "builtin"]
        hidden = Set(defaults.stringArray(forKey: "popover.hidden") ?? [])
        names = defaults.dictionary(forKey: "popover.names") as? [String: String] ?? [:]
        showEyeComfort = defaults.object(forKey: "popover.showEye") as? Bool ?? true
        showBatteries = defaults.object(forKey: "popover.showBatteries") as? Bool ?? true
    }

    static func key(for id: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(id) != 0 { return "builtin" }
        if id == ProfileStore.monitorDisplayID { return "monitor" }
        return "display-\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))"
    }

    static func defaultName(_ key: String) -> String {
        switch key {
        case "builtin": String(localized: "Dahili Ekran")
        case "monitor": "PR27R165QC"
        default: String(localized: "Ekran")
        }
    }

    func name(_ key: String, fallback: String? = nil) -> String {
        if let custom = names[key], !custom.trimmingCharacters(in: .whitespaces).isEmpty { return custom }
        return fallback ?? Self.defaultName(key)
    }

    func isVisible(_ key: String) -> Bool { !hidden.contains(key) }

    func setVisible(_ key: String, _ visible: Bool) {
        if visible { hidden.remove(key) } else { hidden.insert(key) }
        defaults.set(Array(hidden), forKey: "popover.hidden")
    }

    func rename(_ key: String, to name: String) {
        names[key] = name
        defaults.set(names, forKey: "popover.names")
    }

    /// Bilinen anahtarlar sırayla; listede olmayanlar sona eklenir.
    func sorted(_ keys: [String]) -> [String] {
        let known = order.filter(keys.contains)
        return known + keys.filter { !known.contains($0) }
    }

    /// Sürükle-bırak: `key`'i `target`'ın yerine taşır.
    func move(_ key: String, onto target: String, in keys: [String]) {
        var list = sorted(keys)
        guard key != target, let from = list.firstIndex(of: key), let to = list.firstIndex(of: target) else { return }
        list.remove(at: from)
        list.insert(key, at: to)
        order = list + order.filter { !list.contains($0) }
        defaults.set(order, forKey: "popover.order")
    }

    func move(_ keys: [String], from source: IndexSet, to destination: Int) {
        var list = sorted(keys)
        list.move(fromOffsets: source, toOffset: destination)
        order = list + order.filter { !list.contains($0) }
        defaults.set(order, forKey: "popover.order")
    }
}
