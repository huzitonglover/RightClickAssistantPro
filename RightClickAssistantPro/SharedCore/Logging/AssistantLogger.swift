//
//  AppLogger.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import OSLog
import Foundation

private enum AssistantLogSystemResolver {
    static func subsystemName(from override: String?) -> String {
        if let override, !override.isEmpty {
            return override
        }

        return Bundle.main.bundleIdentifier ?? "rightPro.touch.assistant"
    }
}

struct AssistantRuntimeLogger {
    private let logger: Logger

    init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func trace(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.trace("\(text, privacy: .public)")
        #endif
    }

    func debug(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.debug("\(text, privacy: .public)")
        #endif
    }

    func info(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.info("\(text, privacy: .public)")
        #endif
    }

    func notice(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.notice("\(text, privacy: .public)")
        #endif
    }

    func warning(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.warning("\(text, privacy: .public)")
        #endif
    }

    func error(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.error("\(text, privacy: .public)")
        #endif
    }

    func critical(_ message: @autoclosure () -> AssistantLogMessage) {
        #if DEBUG
        let text = message().description
        logger.critical("\(text, privacy: .public)")
        #endif
    }
}

enum AssistantLogPrivacy {
    case auto
    case `public`
    case `private`
}

struct AssistantLogMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    let description: String

    init(stringLiteral value: String) {
        description = value
    }

    init(stringInterpolation: StringInterpolation) {
        description = stringInterpolation.output
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var output = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity + interpolationCount * 16)
        }

        mutating func appendLiteral(_ literal: String) {
            output.append(literal)
        }

        mutating func appendInterpolation<T>(_ value: T) {
            output.append(String(describing: value))
        }

        mutating func appendInterpolation<T>(_ value: T, privacy: AssistantLogPrivacy) {
            output.append(String(describing: value))
        }
    }
}

func makeAssistantLogger(subsystem: String? = nil, category: String = "main") -> AssistantRuntimeLogger {
    return AssistantRuntimeLogger(
        subsystem: AssistantLogSystemResolver.subsystemName(from: subsystem),
        category: category
    )
}

@propertyWrapper
struct AssistantLogger {
    private final class Storage {
        let value: AssistantRuntimeLogger

        init(subsystem override: String?, category: String) {
            value = makeAssistantLogger(subsystem: override, category: category)
        }
    }

    private let storage: Storage

    init(subsystem: String? = nil, category: String = "main") {
        storage = Storage(subsystem: subsystem, category: category)
    }

    var wrappedValue: AssistantRuntimeLogger { storage.value }
}
