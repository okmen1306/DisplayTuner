//
//  TestPatternsView.swift
//  DisplayTuner
//
//  Görev: Tam ekran test desenleri (ESC veya tıklama ile sonraki/çıkış).
//  Faz: 5  ·  Kararlar: 7.2  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

enum TestPattern: CaseIterable {
    case grayscale, blackLevel, whiteLevel, colors, gradient, skin

    var title: String {
        switch self {
        case .grayscale: "Gri skala (11 kademe)"
        case .blackLevel: "Siyah seviyesi (0–10)"
        case .whiteLevel: "Beyaz seviyesi (245–255)"
        case .colors: "Doygun renkler"
        case .gradient: "Gradyan"
        case .skin: "Ten tonları"
        }
    }
}

struct TestPatternsView: View {
    @State private var index = 0
    let close: () -> Void

    var body: some View {
        let pattern = TestPattern.allCases[index]
        ZStack(alignment: .bottom) {
            content(pattern).ignoresSafeArea()
            Text("\(pattern.title)  ·  tıkla: sonraki  ·  ESC: çık")
                .font(.callout).padding(8)
                .background(.black.opacity(0.6), in: Capsule()).foregroundStyle(.white)
                .padding(.bottom, 24)
        }
        .onTapGesture { index = (index + 1) % TestPattern.allCases.count }
        .onExitCommand(perform: close)
    }

    @ViewBuilder
    private func content(_ p: TestPattern) -> some View {
        switch p {
        case .grayscale: steps((0...10).map { Double($0) / 10 })
        case .blackLevel: steps((0...10).map { Double($0) / 255 })
        case .whiteLevel: steps((245...255).map { Double($0) / 255 })
        case .colors:
            HStack(spacing: 0) {
                ForEach([Color.red, .green, .blue, .cyan, .pink, .yellow], id: \.self) { $0 }
            }
        case .gradient:
            VStack(spacing: 0) {
                LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .red], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .green], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black, .blue], startPoint: .leading, endPoint: .trailing)
            }
        case .skin:
            HStack(spacing: 0) {
                ForEach([(0.98, 0.87, 0.78), (0.94, 0.76, 0.62), (0.82, 0.62, 0.47), (0.63, 0.44, 0.31), (0.42, 0.28, 0.19)], id: \.0) {
                    Color(red: $0.0, green: $0.1, blue: $0.2)
                }
            }
        }
    }

    private func steps(_ levels: [Double]) -> some View {
        HStack(spacing: 0) {
            ForEach(levels, id: \.self) { Color(white: $0) }
        }
    }
}

/// Fare imlecinin bulunduğu ekranı tam ekran kaplayan pencere.
@MainActor
enum TestPatternWindow {
    private static var window: NSWindow?

    static func show() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: TestPatternsView { close() })
        w.setFrame(screen.frame, display: true)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = w
    }

    static func close() {
        window?.orderOut(nil)
        window = nil
    }
}
