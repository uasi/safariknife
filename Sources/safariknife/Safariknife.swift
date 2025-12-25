// SPDX-License-Identifier: MIT

import ArgumentParser

@main
struct Safariknife: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A collection of utilities for Safari.",
        subcommands: [Cookies.self, ReadingList.self],
        defaultSubcommand: nil
    )

    struct Cookies: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manage cookies.",
            subcommands: [Export.self],
            defaultSubcommand: nil
        )

        struct Export: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Export cookies."
            )

            @Option(
                name: [.long, .short],
                help:
                    "Path to export cookies from. '-' for stdin. (default: Safari's default cookies file)"
            )
            var input: String?

            @Option(
                name: [.long, .short],
                help: "Path to export cookies to. '-' for stdout. (default: '-')")
            var output: String?

            @Option(
                name: [.long, .short],
                help:
                    "Output format. If not set, detected from output file extension or defaults to json."
            )
            var format: CookieExporter.Format?

            @Option(
                name: [.long],
                help:
                    "Only export cookies from this domain and path. (example: 'example.com/foo')"
            )
            var only: String?

            func run() {
                let exporter = CookieExporter(
                    input: input, output: output, preferredFormat: format, domainAndPath: only)
                guard let exporter = exporter else { return }
                exporter.export()
            }
        }
    }

    struct ReadingList: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Manage reading list.",
            subcommands: [Export.self],
            defaultSubcommand: nil
        )

        struct Export: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Export reading list items."
            )

            @Option(
                name: [.long, .short],
                help:
                    "Path to export items from. (default: Safari's default bookmarks database)"
            )
            var input: String?

            @Option(
                name: [.long, .short],
                help: "Path to export items to. '-' for stdout. (default: '-')")
            var output: String?

            @Option(
                name: [.long, .short],
                help:
                    "Output format. If not set, detected from output file extension or defaults to json."
            )
            var format: ReadingListExporter.Format?

            func run() {
                let exporter = ReadingListExporter(
                    input: input, output: output, preferredFormat: format)
                guard let exporter = exporter else { return }
                exporter.export()
            }
        }
    }
}
