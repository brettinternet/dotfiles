import AppKit

// A native app avoids AppleScript's forced startup dialog when Control is held
// (for example, when Herdr opens a link on Ctrl-click).
final class ChromiumURLHandler: NSObject, NSApplicationDelegate {
    private var receivedURLs = false
    private var failed = false

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURLs = true
        for url in urls {
            guard url.isFileURL || ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                report("Only HTTP, HTTPS, and local files are supported.")
                continue
            }
            launchChromium(url.isFileURL ? url.path : url.absoluteString)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch Services delivers initial URL/file events before this callback.
        if !receivedURLs { launchChromium(nil) }
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if failed { exit(1) }
    }

    private func report(_ message: String) {
        failed = true
        FileHandle.standardError.write(Data(("Chromium Default: \(message)\n").utf8))
    }

    private func launchChromium(_ target: String?) {
        // chromium-apps records the machine's browser and profile at install time.
        guard let browser = Bundle.main.object(forInfoDictionaryKey: "BrowserApplication") as? String,
              let profile = Bundle.main.object(forInfoDictionaryKey: "BrowserUserDataDir") as? String else {
            report("Missing browser settings; reinstall with chromium-apps --install-url-handler.")
            return
        }
        guard FileManager.default.fileExists(atPath: browser) else {
            report("Browser not found: \(browser)")
            return
        }
        var arguments = ["-n", "-a", browser, "--args", "--user-data-dir=\(profile)"]
        if Bundle.main.object(forInfoDictionaryKey: "ChromiumRemoteDebuggingEnabled") as? Bool == true {
            arguments.append("--remote-debugging-port=9222")
        }
        if let target { arguments.append(target) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                report("Browser launch exited with status \(process.terminationStatus).")
            }
        } catch {
            report(error.localizedDescription)
        }
    }
}

let application = NSApplication.shared
let handler = ChromiumURLHandler()
application.delegate = handler
application.run()
