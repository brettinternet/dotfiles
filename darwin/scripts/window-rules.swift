import AppKit

// Watches app launches and applies the first matching rule to each new process.
// Add a Rule to handle another app; add an Action case for a new interaction.

struct Target {
    let pid: pid_t
    let bundleID: String
    let arguments: [String]
}

struct Keystroke: Equatable {
    let key: Character
    let modifiers: CGEventFlags
}

enum Action: Equatable {
    // Sends the keystroke once a window is on screen, retrying a few times until the process exits.
    case quitWithKeystroke(Keystroke)
}

struct Rule {
    let name: String
    let bundleID: String
    // Returns nil to leave a process of this app alone.
    let plan: (Target) -> Action?
}

let rules = [
    Rule(name: "defer MDM restart prompt", bundleID: "au.csiro.dialog", plan: deferRestartPrompt),
]

// The MDM script restarts when swiftDialog exits 0 (Restart button or a normal app
// quit) or 4 (timer); its quit key exits 10, which the script treats as a deferral.
func deferRestartPrompt(_ target: Target) -> Action? {
    let text = [("title", "t"), ("message", "m"), ("button1text", nil)]
        .compactMap { option($0.0, short: $0.1, in: target.arguments) }
    guard text.contains(where: { $0.localizedCaseInsensitiveContains("restart") }) else { return nil }
    return swiftDialogQuitKey(target.arguments).map(Action.quitWithKeystroke)
}

// Mirrors swiftDialog's CLOptionText: the value follows the first occurrence of the flag.
func option(_ long: String, short: String? = nil, in arguments: [String]) -> String? {
    let flags = ["--\(long)"] + (short.map { ["-\($0)"] } ?? [])
    guard let index = arguments.firstIndex(where: flags.contains), index + 1 < arguments.count,
          !arguments[index + 1].hasPrefix("-") else { return nil }
    return arguments[index + 1]
}

// swiftDialog quits on Command+<quitkey>, default "q"; an uppercase key adds Shift
// and must arrive as its lowercase character (captureQuitKey in swiftDialog 2.5).
func swiftDialogQuitKey(_ arguments: [String]) -> Keystroke? {
    let value = option("quitkey", in: arguments) ?? "q"
    guard value.count == 1, let key = value.lowercased().first, keyCodes[key] != nil else { return nil }
    return Keystroke(key: key, modifiers: value == value.lowercased() ? .maskCommand : [.maskCommand, .maskShift])
}

// ANSI virtual key codes; characters are posted explicitly, so the layout does not matter.
let keyCodes: [Character: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
    "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31,
    "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
]

// Parses sysctl KERN_PROCARGS2: argc, executable path, NUL padding, then argv.
func parseProcessArguments(_ bytes: [UInt8]) -> [String]? {
    guard bytes.count >= 4 else { return nil }
    let argc = Int(Int32(littleEndian: bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }))
    var index = 4
    while index < bytes.count && bytes[index] != 0 { index += 1 }
    while index < bytes.count && bytes[index] == 0 { index += 1 }
    var arguments: [String] = []
    while arguments.count < argc && index < bytes.count {
        let start = index
        while index < bytes.count && bytes[index] != 0 { index += 1 }
        arguments.append(String(decoding: bytes[start..<index], as: UTF8.self))
        index += 1
    }
    return arguments.count == argc ? arguments : nil
}

func processArguments(_ pid: pid_t) -> [String]? {
    var mib = [CTL_KERN, KERN_PROCARGS2, pid]
    var size = 0
    guard sysctl(&mib, 3, nil, &size, nil, 0) == 0 else { return nil }
    var bytes = [UInt8](repeating: 0, count: size)
    guard sysctl(&mib, 3, &bytes, &size, nil, 0) == 0 else { return nil }
    return parseProcessArguments(Array(bytes.prefix(size)))
}

func plan(_ target: Target, rules: [Rule]) -> (Rule, Action)? {
    for rule in rules where rule.bundleID == target.bundleID {
        if let action = rule.plan(target) { return (rule, action) }
    }
    return nil
}

func log(_ message: String) {
    fputs("\(ISO8601DateFormatter().string(from: Date())) \(message)\n", stderr)
}

func isRunning(_ pid: pid_t) -> Bool {
    kill(pid, 0) == 0 || errno == EPERM
}

func hasWindow(_ pid: pid_t) -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return windows.contains { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
}

// Posting to the process reaches its event monitors without focusing it.
func post(_ keystroke: Keystroke, to pid: pid_t) {
    guard let code = keyCodes[keystroke.key] else { return }
    var characters = Array(String(keystroke.key).utf16)
    for down in [true, false] {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
        event.flags = keystroke.modifiers
        event.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: &characters)
        event.postToPid(pid)
    }
}

func perform(_ action: Action, on target: Target, rule: Rule) {
    switch action {
    case .quitWithKeystroke(let keystroke):
        var attempts = 0
        while isRunning(target.pid) && attempts < 5 {
            if !CGPreflightPostEventAccess() {
                // The access check is cached per process. Exiting lets launchd restart the
                // agent, whose initial scan picks this prompt up again once access is granted.
                log("\(rule.name): grant Accessibility to \(CommandLine.arguments[0])")
                exit(1)
            } else if hasWindow(target.pid) {
                post(keystroke, to: target.pid)
                attempts += 1
                Thread.sleep(forTimeInterval: 2)
            } else {
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        log("\(rule.name): pid \(target.pid) \(isRunning(target.pid) ? "ignored \(attempts) keystrokes" : "quit")")
    }
}

final class Watcher {
    private var seen = Set<pid_t>()
    private var observation: NSKeyValueObservation?

    func start() {
        observation = NSWorkspace.shared.observe(\.runningApplications, options: [.initial]) { [weak self] workspace, _ in
            self?.scan(workspace.runningApplications)
        }
    }

    // KVO on runningApplications also reports LSUIElement apps, which the
    // didLaunchApplication notification omits.
    private func scan(_ apps: [NSRunningApplication]) {
        seen.formIntersection(apps.map(\.processIdentifier))
        for app in apps where seen.insert(app.processIdentifier).inserted {
            let pid = app.processIdentifier
            guard let bundleID = app.bundleIdentifier, rules.contains(where: { $0.bundleID == bundleID }) else { continue }
            guard let arguments = processArguments(pid) else {
                log("\(bundleID): cannot read arguments for pid \(pid)")
                continue
            }
            let target = Target(pid: pid, bundleID: bundleID, arguments: arguments)
            guard let (rule, action) = plan(target, rules: rules) else { continue }
            log("\(rule.name): pid \(pid) matched")
            DispatchQueue.global().async { perform(action, on: target, rule: rule) }
        }
    }
}

#if !TESTING
@main
struct WindowRules {
    static func main() {
        guard CommandLine.arguments.count == 2, CommandLine.arguments[1] == "watch" else {
            fputs("Usage: window-rules watch\n", stderr)
            exit(1)
        }
        if !CGRequestPostEventAccess() {
            log("Accessibility not granted; rules cannot send input until it is")
        }
        let watcher = Watcher()
        watcher.start()
        RunLoop.main.run()
    }
}
#endif
