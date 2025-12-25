// SPDX-License-Identifier: MIT

import Foundation

enum BookmarkNode: Decodable {
    case leaf(Leaf)
    case list(List)
    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "WebBookmarkTypeLeaf":
            self = .leaf(try Leaf(from: container))
        case "WebBookmarkTypeList":
            self = .list(try List(from: container))
        default:
            self = .unsupported
        }
    }

    enum CodingKeys: String, CodingKey {
        case children = "Children"
        case readingList = "ReadingList"
        case title = "Title"
        case type = "WebBookmarkType"
        case uriDictionary = "URIDictionary"
        case url = "URLString"
        case uuid = "WebBookmarkUUID"
    }

    struct Leaf {
        let title: String
        let url: String
        let uuid: String

        private let readingListItemMetadata: ReadingListItemMetadata?

        var previewText: String? {
            readingListItemMetadata?.previewText
        }

        var inReadingList: Bool {
            readingListItemMetadata != nil
        }

        init(from container: KeyedDecodingContainer<BookmarkNode.CodingKeys>) throws {
            self.readingListItemMetadata = try container.decodeIfPresent(
                ReadingListItemMetadata.self, forKey: .readingList)
            self.title = try decodeTitle(from: container)
            self.url = try container.decode(String.self, forKey: .url)
            self.uuid = try container.decode(String.self, forKey: .uuid)
        }
    }

    struct List {
        let children: [BookmarkNode]
        let title: String
        let uuid: String

        init(from container: KeyedDecodingContainer<BookmarkNode.CodingKeys>) throws {
            self.children =
                try container.decodeIfPresent([BookmarkNode].self, forKey: .children) ?? []
            self.title = try decodeTitle(from: container)
            self.uuid = try container.decode(String.self, forKey: .uuid)
        }
    }
}

private struct ReadingListItemMetadata: Decodable {
    let previewText: String?

    enum CodingKeys: String, CodingKey {
        case previewText = "PreviewText"
    }
}

private struct URIDictionary: Decodable {
    let title: String?
}

private func decodeTitle(from container: KeyedDecodingContainer<BookmarkNode.CodingKeys>) throws
    -> String
{
    if let dict = try container.decodeIfPresent(URIDictionary.self, forKey: .uriDictionary) {
        return dict.title ?? ""
    } else if let title = try container.decodeIfPresent(String.self, forKey: .title) {
        return title
    } else {
        return ""
    }
}
