//
//  AuthorizedDirectoryRecoveryCoordinator.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import Foundation

final class AuthorizedDirectoryRecoveryCoordinator {
    static let shared = AuthorizedDirectoryRecoveryCoordinator()

    @AssistantLogger(category: "AuthorizedDirectoryRecovery")
    private var logger

    private let decoder = PropertyListDecoder()

    func recoverDirectories() -> [AuthorizedDirectory] {
        let fallbackDefaults: [UserDefaults] = [
            .group,
            .standard
        ]

        for defaults in fallbackDefaults {
            guard let directories = loadDirectories(from: defaults), !directories.isEmpty else {
                continue
            }

            logger.info("Recovered \(directories.count) directories from fallback defaults")
            return directories
        }

        return []
    }

    private func loadDirectories(from defaults: UserDefaults) -> [AuthorizedDirectory]? {
        guard let data = defaults.data(forKey: SharedPreferenceKey.permDirs) else {
            return nil
        }

        do {
            return try decoder.decode([AuthorizedDirectory].self, from: data)
        } catch {
            logger.warning("Failed to recover authorized directories from fallback defaults: \(error.localizedDescription)")
            return nil
        }
    }
}
