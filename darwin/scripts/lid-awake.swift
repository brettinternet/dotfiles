import Foundation
import IOKit.ps

// The installing user owns this directory, so requests need no sudo. The daemon
// only tests for the file and deletes it; it never reads user-controlled content.
let request = "/Library/Application Support/local.lid-awake/enabled"

// Unknown readings must not erase an observed AC connection. Failed resets retry.
struct LidState {
    var wasOnAC: Bool?
    var needsReset = true
    var applied = false

    // Returns the override to write, or nil when nothing should change.
    mutating func next(onAC: Bool?, requested: Bool) -> Bool? {
        if let onAC {
            if wasOnAC == true && !onAC { needsReset = true }
            wasOnAC = onAC
        }
        if needsReset { return false }
        return requested == applied ? nil : requested
    }

    mutating func wrote(_ disabled: Bool) {
        applied = disabled
        if !disabled { needsReset = false }
    }
}

func run(_ executable: String, _ arguments: [String]) throws -> (Int32, String) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: output, as: UTF8.self))
}

func fail(_ message: String) -> NSError {
    NSError(domain: "lid-awake", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

func setSleepDisabled(_ disabled: Bool) throws {
    let (status, output) = try run("/usr/bin/pmset", ["-a", "disablesleep", disabled ? "1" : "0"])
    guard status == 0 else { throw fail(output) }
}

func clearRequest() throws {
    guard unlink(request) == 0 || errno == ENOENT else { throw fail(String(cString: strerror(errno))) }
}

func onACPower() -> Bool? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return nil }
    switch source as String {
    case kIOPSACPowerValue: return true
    case kIOPSBatteryPowerValue: return false
    default: return nil
    }
}

#if !TESTING
@main
struct LidAwake {
    static func main() {
        guard CommandLine.arguments.count == 2, CommandLine.arguments[1] == "watch" else {
            fputs("Usage: lid-awake watch\n", stderr)
            exit(1)
        }
        guard getuid() == 0 else {
            fputs("Run as the root LaunchDaemon.\n", stderr)
            exit(1)
        }
        // Reset on every daemon start, including reboot or crash recovery.
        // No persistent enabled state can strand the laptop on battery.
        var state = LidState()
        // Wake immediately on request changes; kqueue costs nothing while idle.
        let wake = DispatchSemaphore(value: 0)
        let directory = open((request as NSString).deletingLastPathComponent, O_EVTONLY)
        let source = directory >= 0
            ? DispatchSource.makeFileSystemObjectSource(fileDescriptor: directory, eventMask: .write)
            : nil
        source?.setEventHandler { wake.signal() }
        source?.resume()
        while true {
            if let value = state.next(onAC: onACPower(), requested: access(request, F_OK) == 0) {
                do {
                    // A reset consumes the request so it cannot re-enable the override.
                    if state.needsReset { try clearRequest() }
                    try setSleepDisabled(value)
                    state.wrote(value)
                } catch {
                    fputs("lid-awake update failed: \(error.localizedDescription)\n", stderr)
                }
            }
            _ = wake.wait(timeout: .now() + 1)
        }
    }
}
#endif
