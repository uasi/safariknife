// SPDX-License-Identifier: MIT

import Foundation

struct BookmarkTree {
    let root: BookmarkNode

    init(data: Data) throws {
        root = try PropertyListDecoder().decode(BookmarkNode.self, from: data)
    }

    func leaves() -> [BookmarkNode] {
        func collectLeaves(_ node: BookmarkNode) -> [BookmarkNode] {
            switch node {
            case .leaf:
                return [node]
            case .list(let list):
                return list.children.flatMap(collectLeaves)
            case .unsupported:
                return []
            }
        }
        return collectLeaves(root)
    }
}
