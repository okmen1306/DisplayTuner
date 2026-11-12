//
//  ConnectedDevicesPage.swift
//  DisplayTuner
//
//  Görev: Bağlı cihazlar listesi.
//  Faz: 2  ·  Kararlar: D-23, 7.4  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct ConnectedDevicesPage: View {
    let services: AppServices
    let select: (SidebarItem) -> Void

    var body: some View {
        Form {
            Section {
                row(.headset, "BlackShark V2 HyperSpeed", present: services.devices.headset != nil,
                    status: services.batteries.states[.headset].map { "%\($0.percent)" } ?? "Kapalı")
                row(.mouseDevice, "ROG Gladius II Wireless", present: services.devices.mouse != nil,
                    status: services.batteries.states[.mouse].map { "%\($0.percent)" } ?? "—")
                row(.keyboard, "PUSAT K3 Pro", present: true,
                    status: services.devices.keyboard == nil ? "İzin gerekli" : "Bağlı")
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ item: SidebarItem, _ name: String, present: Bool, status: String) -> some View {
        Button { select(item) } label: {
            HStack {
                SidebarIcon(symbol: item.symbol, color: item.color)
                Text(name)
                Spacer()
                Text(present ? status : "Bağlı değil").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
