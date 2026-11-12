//
//  SidebarView.swift
//  DisplayTuner
//
//  Görev: Sidebar: Ekran, Mouse, Bağlı Cihazlar (+cihazlar), Otomasyon, Bildirimler.
//  Faz: 1  ·  Kararlar: D-22, D-23  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.primary) { row($0) }
                // D-22/D-23: bağlı cihazlar alt öğe olarak.
                ForEach(SidebarItem.deviceChildren) { row($0).padding(.leading, 14) }
            }
            Section {
                ForEach(SidebarItem.secondary) { row($0) }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    }

    private func row(_ item: SidebarItem) -> some View {
        Label {
            Text(item.title)
        } icon: {
            SidebarIcon(symbol: item.symbol, color: item.color)
        }
        .tag(item)
    }
}
