import Foundation
import IOKit.ps

// Unknown readings must not erase an observed AC connection. Failed resets retry.
struct UndockPolicy {
    var wasOnAC: Bool?
    var needsReset = true

    mutating func observe(onAC: Bool?) {
        guard let onAC else { return }
        if wasOnAC == true && !onAC { needsReset = true }
        wasOnAC = onAC
    }

    mutating func didReset() { needsReset = false }
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

func setSleepDisabled(_ disabled: Bool) throws {
    let (status, output) = try run("/usr/bin/pmset", ["-a", "disablesleep", disabled ? "1" : "0"])
    guard status == 0 else {
        throw NSError(domain: "lid-awake", code: Int(status), userInfo: [NSLocalizedDescriptionKey: output])
    }
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

// Capture power before any enable work: the watcher may reset during that work.
func enableOverride(
    readPower: () -> Bool?,
    checkWatcher: () throws -> Void,
    writeOverride: (Bool) throws -> Void
) throws {
    let startedOnAC = readPower()
    try checkWatcher()
    try writeOverride(true)
    if startedOnAC != false && readPower() != true {
        // Unknown power is conservative; a known battery start is explicitly allowed.
        try writeOverride(false)
    }
}

#if !TESTING
@main
struct LidAwake {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2,
                  ["enable", "disable", "watch"].contains(CommandLine.arguments[1]) else {
                throw NSError(domain: "lid-awake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Usage: lid-awake enable|disable|watch"])
            }
            guard getuid() == 0 else {
                throw NSError(domain: "lid-awake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Run through the installed sudo rule."])
            }
            switch CommandLine.arguments[1] {
            case "enable":
                try enableOverride(readPower: onACPower, checkWatcher: {
                    let (status, output) = try run("/bin/launchctl", ["print", "system/local.lid-awake"])
                    guard status == 0 && output.contains("state = running") else {
                        throw NSError(domain: "lid-awake", code: 1, userInfo: [NSLocalizedDescriptionKey: "Undock watcher is not running; refusing to disable sleep."])
                    }
                }, writeOverride: setSleepDisabled)
            case "disable":
                try setSleepDisabled(false)
            default:
                var policy = UndockPolicy()
                // Reset on every daemon start, including reboot or crash recovery.
                // No persistent enabled state can strand the laptop on battery.
                while true {
                    policy.observe(onAC: onACPower())
                    if policy.needsReset {
                        do {
                            try setSleepDisabled(false)
                            policy.didReset()
                        } catch {
                            fputs("lid-awake reset failed: \(error.localizedDescription)\n", stderr)
                        }
                    }
                    Thread.sleep(forTimeInterval: 1)
                }
            }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
#endif
