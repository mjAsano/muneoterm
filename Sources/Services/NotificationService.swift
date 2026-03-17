import Foundation
import UserNotifications
import AppKit
import os.log

class NotificationService {
    static let shared = NotificationService()
    private let logger = Logger(subsystem: "com.hosun.terminal", category: "Notification")
    private let isAppBundle: Bool

    private init() {
        // UNUserNotificationCenter requires a proper .app bundle with Info.plist.
        // When running via `swift run`, no bundle proxy exists and the API crashes.
        isAppBundle = Bundle.main.bundleIdentifier != nil
    }

    func requestPermission() {
        guard isAppBundle else {
            logger.info("Skipping notification permission (not running as .app bundle)")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Notification permission error: \(error.localizedDescription)")
            } else {
                self.logger.info("Notification permission granted: \(granted)")
            }
        }
    }

    func notifyAllCompleted(total: Int, errors: Int) {
        // Always play a system sound for immediate feedback
        NSSound(named: "Glass")?.play()

        guard isAppBundle else { return }

        let content = UNMutableNotificationContent()
        content.title = "MuneoTerm"

        if errors > 0 {
            content.body = "\(total)개 패널 완료 · \(errors)개 에러 발생"
            content.sound = .default
        } else {
            content.body = "\(total)개 패널 모두 완료"
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "all-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
