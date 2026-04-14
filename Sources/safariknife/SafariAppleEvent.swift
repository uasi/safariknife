// SPDX-License-Identifier: MIT

import ApplicationServices
import Foundation

struct SafariAppleEvent {
    enum Error: Swift.Error, LocalizedError {
        case safariNotRunning
        case sendFailed(OSStatus)
        case sendNotPermitted

        var errorDescription: String? {
            switch self {
            case .safariNotRunning:
                "Safari is not running"
            case .sendFailed(let status):
                "failed to send Apple Event to Safari (OSStatus \(status))"
            case .sendNotPermitted:
                "automating Safari is not permitted for this application"
            }
        }
    }

    struct ReadingList {
        static func add(url: String) throws {
            let bundleData = "com.apple.Safari".data(using: .utf8)!
            guard
                let target = NSAppleEventDescriptor(
                    descriptorType: fcc("bund"),
                    data: bundleData
                )
            else {
                throw Error.sendFailed(-1)
            }

            let event = NSAppleEventDescriptor.appleEvent(
                withEventClass: fcc("sfri"),
                eventID: fcc("arli"),
                targetDescriptor: target,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )

            event.setParam(
                NSAppleEventDescriptor(string: url),
                forKeyword: keyDirectObject
            )

            guard let eventDesc = event.aeDesc else {
                throw Error.sendFailed(-1)
            }

            var reply = AEDesc()
            let status = AESendMessage(
                eventDesc,
                &reply,
                AESendMode(kAEWaitReply | kAECanInteract),
                kAEDefaultTimeout
            )
            defer { if status == noErr { AEDisposeDesc(&reply) } }

            if errorParamValue(aeDescNoCopy: &reply) == Int32(errAEEventNotPermitted) {
                throw Error.sendNotPermitted
            }

            if status == procNotFound {
                throw Error.safariNotRunning
            }

            if status != noErr {
                throw Error.sendFailed(status)
            }
        }
    }
}

private func errorParamValue(aeDescNoCopy: UnsafePointer<AEDesc>) -> Int32? {
    let errorDesc = NSAppleEventDescriptor(aeDescNoCopy: aeDescNoCopy)
        .paramDescriptor(forKeyword: keyErrorNumber)

    return errorDesc?.int32Value
}

private func fcc(_ value: StaticString) -> FourCharCode {
    precondition(
        value.utf8CodeUnitCount == 4, "FourCharCode requires exactly 4 ASCII characters")

    return value.withUTF8Buffer { b in
        FourCharCode(b[0]) << 24
            | FourCharCode(b[1]) << 16
            | FourCharCode(b[2]) << 8
            | FourCharCode(b[3])
    }
}
