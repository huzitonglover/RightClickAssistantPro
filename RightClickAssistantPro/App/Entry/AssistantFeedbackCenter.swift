//
//  AssistantFeedbackCenter.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation
import UserNotifications
import os.log

enum AssistantFeedbackDelivery {
    case banner
    case modal
}

final class AssistantBannerNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AssistantBannerNotificationCenter()

    private let center = UNUserNotificationCenter.current()
    private let logger = makeAssistantLogger(
        subsystem: Bundle.main.bundleIdentifier ?? "RightClickAssistantPro",
        category: "banner_notification"
    )
    private var isConfigured = false

    func prepare() {
        configureIfNeeded()
    }

    func requestAuthorizationIfNeeded() {
        configureIfNeeded()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.logger.info("Notification authorization already available")
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        self.logger.error("Request notification authorization on launch failed: \(error.localizedDescription)")
                        return
                    }

                    if granted {
                        self.logger.info("Notification authorization granted")
                    } else {
                        self.logger.warning("Notification authorization declined by user")
                    }
                }
            case .denied:
                self.logger.warning("Notification authorization denied in System Settings")
            @unknown default:
                self.logger.warning("Unknown notification authorization status on launch")
            }
        }
    }

    func post(title: String, body: String) {
        configureIfNeeded()

        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.enqueue(title: title, body: body)
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        self.logger.error("Request notification authorization failed: \(error.localizedDescription)")
                        return
                    }

                    guard granted else {
                        self.logger.warning("Notification authorization denied by user")
                        return
                    }

                    self.enqueue(title: title, body: body)
                }
            case .denied:
                self.logger.warning("Notification authorization denied, skip banner: \(title)")
            @unknown default:
                self.logger.warning("Unknown notification authorization status, skip banner: \(title)")
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        center.delegate = self
        isConfigured = true
    }

    private func enqueue(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: "assistant.banner.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Add notification request failed: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner])
    }
}
