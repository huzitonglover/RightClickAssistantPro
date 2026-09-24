//
//  FinderSelectionContextResolver.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import FinderSync
import Foundation

struct FinderSelectionContext {
    let targets: [String]
    let trigger: String
}

enum FinderSelectionContextResolver {
    static func resolve(
        for menuKind: FIMenuKind,
        controller: FIFinderSyncController = .default(),
        fallbackContainerURL: URL? = nil
    ) -> FinderSelectionContext {
        FinderSelectionContext(
            targets: targets(
                for: menuKind,
                controller: controller,
                fallbackContainerURL: fallbackContainerURL
            ),
            trigger: triggerKind(for: menuKind)
        )
    }

    private static func targets(
        for menuKind: FIMenuKind,
        controller: FIFinderSyncController,
        fallbackContainerURL: URL?
    ) -> [String] {
        switch menuKind {
        case .contextualMenuForItems:
            let selectedTargets = controller.selectedItemURLs()?.map(\.path) ?? []
            if !selectedTargets.isEmpty {
                return selectedTargets
            }
            return targetedTargets(controller: controller)

        case .toolbarItemMenu:
            let selectedTargets = controller.selectedItemURLs()?.map(\.path) ?? []
            if !selectedTargets.isEmpty {
                return selectedTargets
            }
            return containerTargets(
                controller: controller,
                fallbackContainerURL: fallbackContainerURL
            )

        default:
            return containerTargets(
                controller: controller,
                fallbackContainerURL: fallbackContainerURL
            )
        }
    }

    private static func targetedTargets(controller: FIFinderSyncController) -> [String] {
        controller.targetedURL().map { [$0.path] } ?? []
    }

    private static func containerTargets(
        controller: FIFinderSyncController,
        fallbackContainerURL: URL?
    ) -> [String] {
        if let targetedURL = controller.targetedURL() {
            return [targetedURL.path]
        }

        return fallbackContainerURL.map { [$0.standardizedFileURL.path] } ?? []
    }

    private static func triggerKind(for menuKind: FIMenuKind) -> String {
        switch menuKind {
        case .contextualMenuForItems:
            return "ctx-items"
        case .contextualMenuForContainer:
            return "ctx-container"
        case .contextualMenuForSidebar:
            return "ctx-sidebar"
        case .toolbarItemMenu:
            return "toolbar"
        default:
            return "unknown"
        }
    }
}
