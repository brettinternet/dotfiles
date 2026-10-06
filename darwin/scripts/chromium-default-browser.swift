import AppKit

// Run via xcrun swift; no persistent helper or browser process is needed.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, ["--set", "--check"].contains(arguments[0]) else {
    fail("Usage: chromium-default-browser.swift --set|--check /path/to/Chromium Default.app")
}
let applicationURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
guard Bundle(url: applicationURL)?.bundleIdentifier == "local.chromium-default-url-handler" else {
    fail("Install Chromium Default with chromium-apps --install-url-handler first.")
}

if #available(macOS 12.0, *) {
    Task { @MainActor in
        let workspace = NSWorkspace.shared
        var failed = false
        for scheme in ["http", "https"] {
            let probe = URL(string: "\(scheme)://example.invalid/")!
            if arguments[0] == "--set",
               workspace.urlForApplication(toOpen: probe)?.standardizedFileURL != applicationURL {
                do {
                    try await workspace.setDefaultApplication(at: applicationURL, toOpenURLsWithScheme: scheme)
                } catch {
                    FileHandle.standardError.write(Data(("\(scheme): \(error.localizedDescription)\n").utf8))
                    failed = true
                }
            }
            let actual = workspace.urlForApplication(toOpen: probe)?.standardizedFileURL
            print("\(scheme): \(actual?.path ?? "no handler")")
            if actual != applicationURL { failed = true }
        }
        if failed {
            fail("Default-browser verification failed; settings may be partially changed. Approve the macOS prompt or select Chromium Default in System Settings, then retry.")
        }
        exit(0)
    }
    RunLoop.main.run()
} else {
    fail("Default-browser setup requires macOS 12 or later.")
}
