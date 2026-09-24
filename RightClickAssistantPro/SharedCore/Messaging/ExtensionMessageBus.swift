//
//  ExtensionMessageBus.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

struct ExtensionMessagePayload: Codable, CustomStringConvertible {
    var action: String = ""
    var target: [String] = []
    var rid: String = ""
    var trigger: String = ""

    var description: String {
        "ExtensionMessagePayload(action: \(action), target: \(target), rid: \(rid), trigger: \(trigger))"
    }
}

private enum ExtensionMessageCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ payload: ExtensionMessagePayload) -> String {
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return text
    }

    static func decode(_ rawValue: String) throws -> ExtensionMessagePayload {
        let payloadData = Data(rawValue.utf8)
        return try decoder.decode(ExtensionMessagePayload.self, from: payloadData)
    }
}

private final class ExtensionMessageHandlerRegistry {
    typealias Handler = (ExtensionMessagePayload) -> Void

    private var handlersByName: [String: Handler] = [:]

    func store(_ handler: @escaping Handler, for name: String) -> Bool {
        let shouldRegisterObserver = handlersByName[name] == nil
        handlersByName[name] = handler
        return shouldRegisterObserver
    }

    func handler(for name: String) -> Handler? {
        handlersByName[name]
    }
}

final class ExtensionMessageBus: NSObject {
    static let shared = ExtensionMessageBus()

    @AssistantLogger(category: "messager")
    private var logger

    private let center: DistributedNotificationCenter
    private let handlers = ExtensionMessageHandlerRegistry()

    init(center: DistributedNotificationCenter = .default()) {
        self.center = center
        super.init()
    }

    func sendMessage(name: String, data: ExtensionMessagePayload) {
        let notificationName = Notification.Name(name)
        let serializedPayload = createMessageData(messsagePayload: data)
        logger.debug("dispatch extension message to \(name)")
        center.postNotificationName(
            notificationName,
            object: serializedPayload,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    func createMessageData(messsagePayload: ExtensionMessagePayload) -> String {
        ExtensionMessageCodec.encode(messsagePayload)
    }

    func reconstructEntry(messagePayload: String) -> ExtensionMessagePayload {
        do {
            return try ExtensionMessageCodec.decode(messagePayload)
        } catch {
            logger.warning("Failed to decode ExtensionMessagePayload: \(error.localizedDescription)")
            return ExtensionMessagePayload()
        }
    }

    func on(name: String, handler: @escaping (ExtensionMessagePayload) -> Void) {
        let isFirstObserverForName = handlers.store(handler, for: name)
        guard isFirstObserverForName else {
            return
        }

        center.addObserver(
            self,
            selector: #selector(receivedMessage(_:)),
            name: Notification.Name(name),
            object: nil
        )
    }

    @objc private func receivedMessage(_ notification: Notification) {
        guard let rawValue = notification.object as? String else {
            logger.warning("Extension message payload is not a UTF-8 string")
            return
        }

        let payload = reconstructEntry(messagePayload: rawValue)
        guard let handler = handlers.handler(for: notification.name.rawValue) else {
            logger.warning("No handler registered for \(notification.name.rawValue)")
            return
        }

        handler(payload)
    }
}
