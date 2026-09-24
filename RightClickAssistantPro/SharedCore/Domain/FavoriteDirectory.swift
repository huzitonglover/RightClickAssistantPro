//
//  FavoriteDirectory.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

struct FavoriteDirectory: AssistantModelIdentity {
    var id: String
    var name: String
    var url: URL
    var icon: String

    var displayPath: String {
        url.path
    }
}
