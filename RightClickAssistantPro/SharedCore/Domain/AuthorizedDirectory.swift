//
//  AuthorizedDirectory.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation
import OSLog

private enum AuthorizedDirectoryBookmarkFactory {
    private static let logger = makeAssistantLogger(
        subsystem: Bundle.main.bundleIdentifier ?? "RightClickAssistantPro",
        category: "folder_item"
    )

    static func make(for url: URL) throws -> Data {
        let didEnterScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didEnterScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        logger.info("prepare bookmark for \(url.path)")

        if !didEnterScopedAccess {
            logger.error("Fail to start access security scoped resource on \(url.path)")
        }

        do {
            return try url.bookmarkData(options: .withSecurityScope)
        } catch {
            logger.warning("\(error.localizedDescription)")
            throw error
        }
    }
}

private enum AuthorizedDirectorySeedCatalog {
    static func homeDirectoryURL() -> URL? {
        guard let passwordEntry = getpwuid(getuid()),
              let homePathPointer = passwordEntry.pointee.pw_dir
        else {
            return nil
        }

        let homePath = FileManager.default.string(
            withFileSystemRepresentation: homePathPointer,
            length: strlen(homePathPointer)
        )
        return URL(fileURLWithPath: homePath)
    }

    static func mountedVisibleVolumes() -> [URL] {
        let visibleVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [],
            options: .skipHiddenVolumes
        ) ?? []
        return Array(visibleVolumes.dropFirst())
    }
}

struct AuthorizedDirectory: AssistantModelIdentity {
    var id: String
    var url: URL
    var bookmark: Data
}

extension AuthorizedDirectory {
    init(permUrl url: URL, id: String = UUID().uuidString) throws {
        self.init(
            id: id,
            url: url,
            bookmark: try AuthorizedDirectoryBookmarkFactory.make(for: url)
        )
    }

    static func bookmarkData(for url: URL) throws -> Data {
        try AuthorizedDirectoryBookmarkFactory.make(for: url)
    }

    static var home: Self? {
        AuthorizedDirectorySeedCatalog.homeDirectoryURL().flatMap { try? Self(permUrl: $0) }
    }

    static var defaultFolders: [Self] {
        var folders: [Self] = []
        if let home {
            folders.append(home)
        }
        folders.append(
            contentsOf: AuthorizedDirectorySeedCatalog.mountedVisibleVolumes().compactMap { try? Self(permUrl: $0) }
        )
        return folders
    }
}
