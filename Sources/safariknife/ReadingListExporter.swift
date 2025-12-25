// SPDX-License-Identifier: MIT

import Foundation

import protocol ArgumentParser.ExpressibleByArgument

struct ReadingListExporter {
    fileprivate enum Input {
        case defaultFile
        case file(URL)

        init(_ input: String?) {
            if let input = input, !input.isEmpty {
                self = .file(URL(fileURLWithPath: input))
            } else {
                self = .defaultFile
            }
        }

        func readBookmarkTree() throws -> BookmarkTree {
            let data: Data
            switch self {
            case .file(let url):
                data = try Data(contentsOf: url)
            case .defaultFile:
                data = try Data(contentsOf: Resources.bookmarksFile)
            }

            return try BookmarkTree(data: data)
        }
    }

    fileprivate enum Output {
        case file(URL)
        case standardOutput

        init(_ output: String?) {
            if output == "-" {
                self = .standardOutput
            } else if let output = output, !output.isEmpty {
                self = .file(URL(fileURLWithPath: output))
            } else {
                self = .standardOutput
            }
        }

        func write(_ data: Data) throws {
            switch self {
            case .standardOutput:
                try FileHandle.standardOutput.write(contentsOf: data)
            case .file(let url):
                try data.write(to: url)
            }
        }
    }

    enum Format: String, CaseIterable, ExpressibleByArgument {
        case json
        case jsonl
        case text

        static let `default`: Self = .json

        fileprivate init(detectingFromOutput output: Output, preferredFormat: Format?) {
            switch output {
            case .standardOutput:
                self = preferredFormat ?? Self.default
            case .file(let url):
                self = preferredFormat ?? Self(fromURL: url) ?? Self.default
            }
        }

        private init?(fromURL url: URL) {
            switch url.pathExtension.lowercased() {
            case "json":
                self = .json
            case "jsonl":
                self = .jsonl
            case "txt":
                self = .text
            default:
                return nil
            }
        }
    }

    private let input: Input
    private let output: Output
    private let format: Format

    init?(input: String?, output: String?, preferredFormat: Format?) {
        self.input = Input(input)
        self.output = Output(output)
        self.format = Format(
            detectingFromOutput: self.output, preferredFormat: preferredFormat
        )
    }

    func export() {
        let tree: BookmarkTree
        do {
            tree = try self.input.readBookmarkTree()
        } catch {
            print("error: could not read from input: \(error)", to: &StandardError.shared)
            return
        }

        let outputData: Data
        do {
            outputData = try encode(tree)
        } catch {
            print(
                "error: could not encode reading list: \(error)",
                to: &StandardError.shared
            )
            return
        }

        do {
            try output.write(outputData)
        } catch {
            print("error: could not write to output: \(error)", to: &StandardError.shared)
            return
        }
    }

    private func encode(_ tree: BookmarkTree) throws -> Data {
        switch self.format {
        case .json:
            let encoder = JSONEncoder.forPrettyJSON()

            let items = tree.leaves().compactMap { ReadingListItem(node: $0) }
            var data = try encoder.encode(items)
            data.appendLineFeed()
            return data
        case .jsonl:
            let encoder = JSONEncoder.forPrettyJSONLines()

            var data = Data()
            for leaf in tree.leaves() {
                if let item = ReadingListItem(node: leaf) {
                    data.append(try encoder.encode(item))
                    data.appendLineFeed()
                }
            }
            return data
        case .text:
            var data = Data()
            for leaf in tree.leaves() {
                if let item = ReadingListItem(node: leaf) {
                    let title = item.title.replacingOccurrences(
                        of: "[\n\t]", with: " ", options: .regularExpression)
                    let previewText =
                        item.previewText?.replacingOccurrences(
                            of: "[\n\t]", with: " ", options: .regularExpression) ?? ""
                    data.append(string: "\(item.url)\t\(title)\t\(previewText)")
                    data.appendLineFeed()
                }
            }
            return data
        }
    }
}

private struct ReadingListItem: Codable {
    let previewText: String?
    let title: String
    let url: String

    init?(node: BookmarkNode) {
        switch node {
        case .leaf(let leaf) where leaf.inReadingList:
            self.previewText = leaf.previewText
            self.title = leaf.title
            self.url = leaf.url
        default:
            return nil
        }
    }
}
