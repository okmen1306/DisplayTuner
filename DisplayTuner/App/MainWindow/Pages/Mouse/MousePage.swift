//
//  MousePage.swift
//  DisplayTuner
//
//  Görev: macOS mouse ayarları: scroll yönü, imleç hızı, ivme, imleç boyutu.
//  Faz: 4  ·  Kararlar: D-50…D-53, 7.3  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

struct MousePage: View {
    let reverser: ScrollReverser
    let pointer: PointerSettings
    let cursor: CursorService
    let appearance: CursorAppearance
    @State private var trusted = ScrollReverser.hasAccessibility
    @State private var linearMouseRunning = false
    @MainActor private static var didPrompt = false

    var body: some View {
        Form {
            Section {
                Toggle("Mouse tekerleğini ters çevir", isOn: Binding(get: { reverser.isEnabled }, set: { reverser.isEnabled = $0 }))

            } header: {
                Text("Kaydırma")
            } footer: {
                Text("Trackpad doğal kaydırmada kalır; sadece mouse tekerleği ters döner.")
            }
            if linearMouseRunning {
                Section {
                    Label("LinearMouse açık. Çift ters çevirmeyi önlemek için önce onu kapatın.", systemImage: "exclamationmark.triangle.fill")
                    Button("LinearMouse'u Kapat") {
                        NSRunningApplication.runningApplications(withBundleIdentifier: "com.lujjjh.LinearMouse").forEach { $0.terminate() }
                        Task { try? await Task.sleep(for: .seconds(1)); refresh() }
                    }
                }
            }
            if !trusted {
                Section {
                    Label("Erişilebilirlik izni gerekiyor.", systemImage: "lock.fill")
                    Button("İzin Ver…") { ScrollReverser.requestAccessibility() }
                } footer: {
                    Text("Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik'te DisplayTuner'ı açın.")
                }
            }
            Section("İmleç") {
                SettingRow(title: "Hız", symbol: "hare.fill") {
                    Slider(value: Binding(get: { pointer.speed }, set: { pointer.speed = $0 }), in: 0...PointerSettings.maxSpeed)
                        .frame(width: 220)
                    Text(pointer.speed, format: .number.precision(.fractionLength(1))).monospacedDigit().frame(width: 32)
                }
                .disabled(!pointer.isAvailable)
                Toggle("İvmeyi kapat (doğrusal hareket)", isOn: Binding(get: { pointer.linear }, set: { pointer.linear = $0 }))
                    .disabled(!pointer.isAvailable)
                SettingRow(title: "İmleç boyutu", symbol: "cursorarrow") {
                    Slider(value: Binding(get: { cursor.scale }, set: { cursor.scale = $0 }), in: 1...4)
                        .frame(width: 220)
                    Text(cursor.scale, format: .number.precision(.fractionLength(1))).monospacedDigit().frame(width: 32)
                }
            }
            Section {
                Picker("Şekil", selection: Binding(get: { appearance.shape }, set: { appearance.shape = $0 })) {
                    ForEach(CursorAppearance.Shape.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                InlineColorPicker(title: "Dolgu rengi", color: Binding(get: { Color(nsColor: appearance.fill) },
                                                                      set: { appearance.fill = NSColor($0) }))
                    .disabled(appearance.shape == .system)
                InlineColorPicker(title: "Kenar rengi", color: Binding(get: { Color(nsColor: appearance.outline) },
                                                                      set: { appearance.outline = NSColor($0) }))
                    .disabled(appearance.shape == .system)
                Button("Varsayılana Dön") { appearance.reset() }
            } header: {
                Text("İmleç görünümü")
            } footer: {
                Text("Ok imlecinin şeklini ve rengini değiştirir. \"Sistem\" macOS'un kendi imlecidir.")
            }
            .disabled(!appearance.isAvailable)
        }
        .formStyle(.grouped)
        .onAppear {
            refresh()
            // İzin yoksa macOS isteğini otomatik göster; uygulama Erişilebilirlik listesine kendiliğinden eklenir.
            if !trusted && !Self.didPrompt {
                Self.didPrompt = true          // her açılışta en fazla bir kez sor
                ScrollReverser.requestAccessibility()
            }
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refresh() }
    }

    private func refresh() {
        trusted = ScrollReverser.hasAccessibility
        linearMouseRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.lujjjh.LinearMouse").isEmpty
        if trusted && reverser.isEnabled && !reverser.isRunning { reverser.start() }
    }
}
