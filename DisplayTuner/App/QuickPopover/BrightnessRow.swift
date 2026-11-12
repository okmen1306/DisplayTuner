//
//  BrightnessRow.swift
//  DisplayTuner
//
//  Görev: Ekran başına parlaklık satırı (DDC / DisplayServices).
//  Faz: 1  ·  Kararlar: 7.1  (bkz. AGENT_BRIEF.md)
//

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
    }

    private(set) var rows: [Row] = []
    private(set) var isLoading = false
    private var pendingWrite: Task<Void, Never>?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        var result: [Row] = []
        if let value = BuiltinBrightness.value {
            result.append(Row(id: .builtin, name: "Dahili Ekran", value: value, maximum: 1))
        }
        if let ddc = await DDCService.shared.read(.brightness) {
            result.append(Row(id: .external, name: "PR27R165QC", value: ddc.fraction, maximum: ddc.maximum))
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
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(row.name)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { row.value }, set: onChange), in: 0...1)
                    .accessibilityLabel("\(row.name) parlaklığı")
                Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
            }
        }
    }
}
