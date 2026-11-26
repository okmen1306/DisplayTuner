//
//  BrightnessRow.swift
//  DisplayTuner
//
//  Görev: Ekran başına parlaklık satırı (DDC / DisplayServices).
//  Faz: 1  ·  Kararlar: 7.1  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

/// Popover'daki parlaklık modeli. Harici ekran DDC, dahili ekran DisplayServices.
@MainActor
@Observable
final class BrightnessModel {
    struct Row: Identifiable, Equatable {
        enum Kind { case builtin, external }
        let id: Kind
        let name: String
        var value: Double
        var maximum: Int
        /// PopoverLayout anahtarı (D-161).
        var key: String { id == .builtin ? "builtin" : "monitor" }
    }

    private(set) var rows: [Row] = []
    private(set) var isLoading = false
    private var pendingWrite: Task<Void, Never>?

    private var screenObserver: NSObjectProtocol?

    init() {
        // D-155: ekran takılıp çıkınca satırlar kendiliğinden yenilenir; DDC servisi tazelenir.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                await DDCService.shared.refresh()
                await self?.load()
            }
        }
    }

    /// D-155: Monitör satırı DDC okumasına değil, monitörün gerçekten bağlı olmasına göre gösterilir.
    /// DDC o an cevap vermezse servis tazelenip bir kez daha denenir; yine olmazsa son bilinen değer gösterilir.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        var result: [Row] = []
        if let value = BuiltinBrightness.value {
            result.append(Row(id: .builtin, name: String(localized: "Dahili Ekran"), value: value, maximum: 1))
        }
        if ProfileStore.monitorDisplayID != nil {
            var ddc = await DDCService.shared.read(.brightness)
            if ddc == nil {
                await DDCService.shared.refresh()
                ddc = await DDCService.shared.read(.brightness)
            }
            let defaults = UserDefaults.standard
            if let ddc {
                defaults.set(ddc.fraction, forKey: "monitorBrightness.last")
                defaults.set(ddc.maximum, forKey: "monitorBrightness.max")
            }
            let value = ddc?.fraction ?? (defaults.object(forKey: "monitorBrightness.last") as? Double ?? 0.5)
            let maximum = ddc?.maximum ?? (defaults.object(forKey: "monitorBrightness.max") as? Int ?? 100)
            result.append(Row(id: .external, name: "PR27R165QC", value: value, maximum: maximum))
        }
        rows = result
    }

    func set(_ kind: Row.Kind, to value: Double) {
        guard let index = rows.firstIndex(where: { $0.id == kind }) else { return }
        rows[index].value = value
        switch kind {
        case .builtin:
            BuiltinBrightness.set(value)
        case .external:
            // Slider sürüklenirken her harekette DDC'ye yazmamak için kısa debounce (D-37: 50 ms aralık).
            let target = Int((value * Double(rows[index].maximum)).rounded())
            pendingWrite?.cancel()
            pendingWrite = Task {
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                await DDCService.shared.write(.brightness, value: target)
            }
        }
    }
}

struct BrightnessRow: View {
    let row: BrightnessModel.Row
    var title: String? = nil
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title ?? row.name)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { row.value }, set: onChange), in: 0...1)
                    .accessibilityLabel(String(localized: "\(title ?? row.name) parlaklığı"))
                Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
            }
        }
    }
}
