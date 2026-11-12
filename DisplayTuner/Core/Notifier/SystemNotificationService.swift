//
//  SystemNotificationService.swift
//  DisplayTuner
//
//  Görev: UNUserNotificationCenter (pil halkası eki Faz 8'de).
//  Faz: 2  ·  Kararlar: 8.4  (bkz. AGENT_BRIEF.md)
//

import Foundation
import os
import UserNotifications

@MainActor
final class SystemNotificationService {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Notifications")

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            logger.info("Bildirim izni: \(granted)")
            if let error { logger.error("Bildirim izni hatası: \(error.localizedDescription)") }
        }
    }

    /// Aynı cihazın bildirimleri `threadIdentifier` ile gruplanır.
    func post(title: String, body: String, thread: String, sound: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = thread
        content.categoryIdentifier = "battery"
        if sound { content.sound = .default }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
