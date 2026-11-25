//
//  EyeComfortSection.swift
//  DisplayTuner
//
//  Görev: Ekran sekmesindeki "Göz konforu" bölümü.
//  Kararlar: D-157  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct EyeComfortSection: View {
    @Bindable var eye: EyeComfort

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: eye.isActive ? "moon.stars.fill" : "moon.stars")
                    .font(.title2)
                    .foregroundStyle(eye.isActive ? Color.orange : .secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(eye.isActive ? "Göz konforu açık" : "Göz konforu kapalı").font(.headline)
                    Text(statusLine).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { eye.isActive }, set: { _ in eye.toggle() }))
                    .labelsHidden().toggleStyle(.switch)
            }
            Picker("Çalışma şekli", selection: $eye.mode) {
                ForEach(EyeComfort.Mode.allCases) { Text($0.title).tag($0) }
            }
            if eye.mode == .schedule {
                HStack {
                    DatePicker("Başlangıç", selection: minutesBinding(\.scheduleStart), displayedComponents: .hourAndMinute)
                    DatePicker("Bitiş", selection: minutesBinding(\.scheduleEnd), displayedComponents: .hourAndMinute)
                }
            }
            SettingRow(title: "Sıcaklık", symbol: "thermometer.sun.fill") {
                Slider(value: $eye.strength, in: 0.15...1)
                    .frame(width: 200)
                    .tint(.orange)
                Text(String(localized: "%\(Int((eye.strength * 100).rounded()))")).monospacedDigit().frame(width: 44, alignment: .trailing)
            }
            Toggle(isOn: $eye.builtinEnabled) { Label("MacBook ekranı", systemImage: "laptopcomputer") }
            Toggle(isOn: $eye.monitorEnabled) { Label("PR27R165QC", systemImage: "display") }
        } header: {
            Text("Göz konforu")
        } footer: {
            Text("Mavi ışığı azaltıp ekranı sıcak tona çeker. Renk profilinle birlikte çalışır; kısayol ⌃⌥N.")
        }
    }

    private var statusLine: String {
        switch eye.mode {
        case .off: return String(localized: "Elle açılabilir")
        case .on: return String(localized: "Sen kapatana kadar açık")
        case .schedule:
            return String(localized: "\(Self.format(eye.scheduleStart)) – \(Self.format(eye.scheduleEnd)) arası")
        case .sunset:
            guard let (rise, set) = eye.todaySunTimes else { return String(localized: "Gün batımından gün doğumuna") }
            let f = Date.FormatStyle(date: .omitted, time: .shortened)
            return String(localized: "Bugün \(set.formatted(f)) – yarın \(rise.formatted(f))")
        }
    }

    private static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func minutesBinding(_ key: ReferenceWritableKeyPath<EyeComfort, Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: eye[keyPath: key] / 60, minute: eye[keyPath: key] % 60, second: 0, of: .now) ?? .now
        }, set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            eye[keyPath: key] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
    }
}
