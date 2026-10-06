import CoreGraphics

func dialog(_ arguments: [String]) -> Target {
    Target(pid: 1, bundleID: "au.csiro.dialog", arguments: ["/Dialog"] + arguments)
}

func procargs(_ arguments: [String]) -> [UInt8] {
    let argc = withUnsafeBytes(of: Int32(arguments.count).littleEndian, Array.init)
    return argc + Array("/exec/path".utf8) + [0, 0, 0] + arguments.flatMap { Array($0.utf8) + [0] } + [0, 0]
}

@main
struct PolicyTests {
    static func main() {
        let quit = Action.quitWithKeystroke(Keystroke(key: "q", modifiers: .maskCommand))
        let restart = ["--title", "Restart required", "--message", "Save your work", "--button1text", "Restart now"]
        precondition(plan(dialog(restart), rules: rules)?.1 == quit, "The MDM restart prompt is deferred with Command-Q")
        precondition(plan(dialog(["--title", "none", "--message", "Your computer will restart soon"]), rules: rules)?.1 == quit,
                     "The untitled final countdown is deferred")
        precondition(plan(dialog(["-t", "RESTART REQUIRED"]), rules: rules)?.1 == quit, "Short flags and case are ignored")
        precondition(plan(dialog(["--title", "Welcome", "--message", "Install complete"]), rules: rules) == nil,
                     "Other swiftDialog prompts are left alone")
        precondition(plan(dialog(["--title", "--message", "restart"]), rules: rules)?.1 == quit,
                     "A flag is not mistaken for the previous option's value")
        precondition(plan(Target(pid: 1, bundleID: "com.example.other", arguments: restart), rules: rules) == nil,
                     "Rules only apply to their app")

        precondition(plan(dialog(restart + ["--quitkey", "x"]), rules: rules)?.1
                     == .quitWithKeystroke(Keystroke(key: "x", modifiers: .maskCommand)), "A custom quit key replaces Command-Q")
        precondition(plan(dialog(restart + ["--quitkey", "X"]), rules: rules)?.1
                     == .quitWithKeystroke(Keystroke(key: "x", modifiers: [.maskCommand, .maskShift])),
                     "An uppercase quit key is sent as Command-Shift with its lowercase character")
        precondition(plan(dialog(restart + ["--quitkey", "§"]), rules: rules) == nil, "Unmapped quit keys are not guessed")

        precondition(parseProcessArguments(procargs(["/Dialog", "--title", "Restart required"]))
                     == ["/Dialog", "--title", "Restart required"], "Arguments keep spaces and skip the executable path")
        precondition(parseProcessArguments(procargs(["/Dialog", ""])) == ["/Dialog", ""], "Empty arguments are preserved")
        precondition(parseProcessArguments(Array(procargs(["/Dialog", "--title"]).dropLast(10))) == nil,
                     "Truncated data is rejected")
    }
}
