//
//  Models.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

struct AuthorizedDirectoryRecord: Identifiable, Hashable, Codable {
    var id: String
    var directoryLocation: URL
    var bookmarkBlob: Data

    init(id: String, directoryLocation: URL, bookmarkBlob: Data) {
        self.id = id
        self.directoryLocation = directoryLocation
        self.bookmarkBlob = bookmarkBlob
    }

    init(snapshot: AuthorizedDirectory) {
        self.init(
            id: snapshot.id,
            directoryLocation: snapshot.url,
            bookmarkBlob: snapshot.bookmark
        )
    }

    var resolvedPath: String {
        directoryLocation.path
    }

    func asAuthorizedDirectory() -> AuthorizedDirectory {
        .init(
            id: id,
            url: directoryLocation,
            bookmark: bookmarkBlob
        )
    }
}
