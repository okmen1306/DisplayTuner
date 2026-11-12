//
//  MainWindowView.swift
//  DisplayTuner
//
//  Görev: NavigationSplitView: sidebar + detay.
//  Faz: 1  ·  Kararlar: D-22  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

@MainActor
@Observable
final class MainWindowState {
    var selection: SidebarItem? = .display
    /// D-149: sağ renk paneli.
    let colorPanel = ColorPanelHost()
}

struct MainWindowView: View {
    @Bindable var state: MainWindowState
    let services: AppServices

    var body: some View {
        HStack(spacing: 0) {
            split
            if let edit = state.colorPanel.edit {
                Divider()
                ColorSidePanel(edit: edit) { state.colorPanel.close() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .environment(\.colorPanel, state.colorPanel)
        .onChange(of: state.selection) { state.colorPanel.close() }
    }

    private var split: some View {
        NavigationSplitView {
            SidebarView(selection: $state.selection)
        } detail: {
            detail(for: state.selection ?? .display)
                .navigationTitle(Text((state.selection ?? .display).title))
                // Cihaz sayfaları açıkken durum 5 sn'de bir yenilenir (kapanan/çıkarılan cihaz hemen görünür).
                .task(id: state.selection) {
                    let deviceItems: [SidebarItem] = [.devices, .headset, .mouseDevice, .keyboard]
                    guard let selection = state.selection, deviceItems.contains(selection) else { return }
                    while !Task.isCancelled {
                        await services.batteries.refresh()
                        try? await Task.sleep(for: .seconds(5))
                    }
                }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .display: DisplayPage(services: services)
        case .mouse: MousePage(reverser: services.scrollReverser, pointer: services.pointer, cursor: services.cursor,
                               appearance: services.cursorAppearance)
        case .devices: ConnectedDevicesPage(services: services) { state.selection = $0 }
        case .headset: HeadsetPage(services: services)
        case .mouseDevice: MouseDevicePage(services: services) { state.selection = .mouse }
        case .keyboard: KeyboardPage(services: services)
        case .notifications: NotificationsPage(services: services)
        case .automation: AutomationPage(services: services)
        default: placeholder(for: item)
        }
    }

    /// Sayfalar ilgili fazlarda gelecek; o zamana kadar yer tutucu.
    private func placeholder(for item: SidebarItem) -> some View {
        ContentUnavailableView {
            Label { Text(item.title) } icon: { Image(systemName: item.symbol) }
        } description: {
            Text("Bu sayfa Faz \(item.phase)'te eklenecek.")
        }
    }
}
