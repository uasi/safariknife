// SPDX-License-Identifier: MIT

import Foundation

import protocol ArgumentParser.ExpressibleByArgument

struct CookieExporter {
    fileprivate enum Input {
        case defaultFile
        case file(URL)
        case standardInput

        init(_ input: String?) {
            if input == "-" {
                self = .standardInput
            } else if let input = input, !input.isEmpty {
                self = .file(URL(fileURLWithPath: input))
            } else {
                self = .defaultFile
            }
        }

        func read() throws -> Data {
            switch self {
            case .standardInput:
                return try FileHandle.standardInput.readToEnd() ?? Data()
            case .file(let url):
                return try Data(contentsOf: url)
            case .defaultFile:
                return try Data(contentsOf: StandardLocations.containeredCookiesFile)
            }
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
        case netscape

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
                self = .netscape
            default:
                return nil
            }
        }
    }

    private let input: Input
    private let output: Output
    private let format: Format

    init(input: String?, output: String?, preferredFormat: Format?) {
        self.input = Input(input)
        self.output = Output(output)
        self.format = Format(detectingFromOutput: self.output, preferredFormat: preferredFormat)
    }

    func export() {
        let inputData: Data
        do {
            inputData = try input.read()
        } catch {
            print("error: could not read from input: \(error)", to: &StandardError.shared)
            return
        }

        let cookies: [Cookie]
        do {
            cookies = try BinaryCookiesParser.parse(inputData)
        } catch {
            print("error: could not parse cookies: \(error)", to: &StandardError.shared)
            return
        }

        let outputData: Data
        do {
            outputData = try encode(cookies)
        } catch {
            print(
                "error: could not encode cookies: \(error)",
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

    private func encode(_ cookies: [Cookie]) throws -> Data {
        func baseJSONEncoder() -> JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .secondsSince1970
            return encoder
        }

        switch format {
        case .json:
            let encoder = baseJSONEncoder()
            encoder.outputFormatting.insert(.prettyPrinted)

            return try encoder.encode(cookies)
        case .jsonl:
            let encoder = baseJSONEncoder()

            var data = Data()
            for cookie in cookies {
                data.append(try encoder.encode(cookie))
                data.appendLineFeed()
            }
            return data
        case .netscape:
            let preamble = """
                # Netscape cookie file <https://everything.curl.dev/http/cookies/fileformat.html>
                # domain\tinclude_subdomains\tpath\tsecure\texpires\tname\tvalue

                """.data(using: .utf8)!

            var data = Data(preamble)
            for cookie in cookies {
                data.append(string: cookie.domain)
                data.appendTab()
                data.append(string: "FALSE")  // FIXME
                data.appendTab()
                data.append(string: cookie.path)
                data.appendTab()
                data.append(string: cookie.isSecure ? "TRUE" : "FALSE")
                data.appendTab()
                data.append(string: "\(cookie.expiresDate.map { $0.timeIntervalSince1970 } ?? 0)")
                data.appendTab()
                data.append(string: cookie.name)
                data.appendTab()
                data.append(string: cookie.value)
                data.appendLineFeed()
            }
            return data
        }
    }
}
