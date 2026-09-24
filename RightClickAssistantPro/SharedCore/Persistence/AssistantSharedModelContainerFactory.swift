//
//  AssistantSharedModelContainerFactory.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

enum AssistantSharedModelContainerFactory {
    private static let fileManager = FileManager.default

    static func sharedContainerURL(appGroupIdentifier: String) -> URL? {
        fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }
}
