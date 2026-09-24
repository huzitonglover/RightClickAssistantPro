//
//  ModelContainer.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

final class SharedModelStore {
    static let appGroupIdentifier = Constants.appGroupIdentifier

    static let sharedContainerURL = AssistantSharedModelContainerFactory.sharedContainerURL(
        appGroupIdentifier: appGroupIdentifier
    )
}
