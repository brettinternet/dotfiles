import Foundation

@main
struct PolicyTests {
    static func main() throws {
        var policy = UndockPolicy()
        precondition(policy.needsReset, "Startup/reboot must restore normal sleep")
        policy.observe(onAC: false)
        policy.didReset()
        policy.observe(onAC: false)
        precondition(!policy.needsReset, "Enabling on battery must remain allowed")

        policy.observe(onAC: true)
        precondition(!policy.needsReset, "Plugging in must not reset an override")
        policy.observe(onAC: nil)
        precondition(!policy.needsReset, "Unknown power must not trigger reset")
        policy.observe(onAC: false)
        precondition(policy.needsReset, "Unplugging after an unknown reading must reset")
        policy.observe(onAC: false)
        precondition(policy.needsReset, "Failed resets must retry")
        policy.observe(onAC: true)
        precondition(policy.needsReset, "Replugging must not cancel a failed reset")
        policy.didReset()
        precondition(!policy.needsReset)
        policy.observe(onAC: false)
        precondition(policy.needsReset, "Subsequent undocks must also reset")
        policy.didReset()
        policy.observe(onAC: false)
        precondition(!policy.needsReset, "Do not repeatedly reset while on battery")

        // Deterministically interleave an undock reset before the enable write.
        var ac = true
        var disabled = false
        try enableOverride(readPower: { ac }, checkWatcher: {
            ac = false
            disabled = false // Watcher has completed its undock reset.
        }, writeOverride: { disabled = $0 })
        precondition(!disabled, "An in-flight enable must not overwrite the undock reset")

        try enableOverride(readPower: { false }, checkWatcher: {}, writeOverride: { disabled = $0 })
        precondition(disabled, "A request starting on battery is still allowed")
        try enableOverride(readPower: { true }, checkWatcher: {}, writeOverride: { disabled = $0 })
        precondition(disabled, "Stable AC permits enable")
        try enableOverride(readPower: { nil }, checkWatcher: {}, writeOverride: { disabled = $0 })
        precondition(!disabled, "Unknown power must fail safe")

        disabled = false
        do {
            try enableOverride(readPower: { true }, checkWatcher: {
                throw NSError(domain: "test", code: 1)
            }, writeOverride: { disabled = $0 })
            preconditionFailure("Missing watcher must reject enable")
        } catch {
            precondition(!disabled, "Rejected requests must not disable sleep")
        }
    }
}
