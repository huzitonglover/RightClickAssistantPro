//
//  Extension+.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation
import SwiftUI

private enum AppActivityEvent {
    case movedToBackground
    case movedToForeground

    var notificationName: Notification.Name {
        switch self {
        case .movedToBackground:
            NSApplication.willResignActiveNotification
        case .movedToForeground:
            NSApplication.didBecomeActiveNotification
        }
    }
}

private struct AppActivityModifier: ViewModifier {
    let event: AppActivityEvent
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: event.notificationName)) { _ in
            action()
        }
    }
}

extension View {
    func onBackground(_ action: @escaping () -> Void) -> some View {
        modifier(AppActivityModifier(event: .movedToBackground, action: action))
    }

    func onForeground(_ action: @escaping () -> Void) -> some View {
        modifier(AppActivityModifier(event: .movedToForeground, action: action))
    }

    @ViewBuilder
    func compatibilityGroupedFormStyle() -> some View {
        if #available(macOS 13.0, *) {
            formStyle(.grouped)
        } else {
            self
        }
    }
}
