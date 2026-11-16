@main
struct PolicyTests {
    static func main() {
        var state = LidState()
        precondition(state.next(onAC: true, requested: true, applied: true) == false, "Startup/reboot must restore normal sleep, even with a stale request")
        state.wrote(false)
        precondition(state.next(onAC: true, requested: false, applied: false) == nil, "Idle requests change nothing")
        precondition(state.next(onAC: true, requested: true, applied: false) == true, "A request on AC enables the override")
        precondition(state.next(onAC: true, requested: true, applied: false) == true, "Failed writes retry")
        state.wrote(true)
        precondition(state.next(onAC: true, requested: true, applied: true) == nil, "Applied requests are not rewritten")
        precondition(state.next(onAC: true, requested: true, applied: false) == true, "An externally cleared override is re-applied")
        precondition(state.next(onAC: true, requested: true, applied: nil) == nil, "Unknown live state changes nothing")
        precondition(state.next(onAC: nil, requested: true, applied: true) == nil, "Unknown power must not trigger reset")
        precondition(state.next(onAC: false, requested: true, applied: true) == false, "Unplugging after an unknown reading must reset")
        precondition(state.next(onAC: true, requested: true, applied: true) == false, "Replugging must not cancel a failed reset")
        state.wrote(false)
        precondition(state.next(onAC: true, requested: false, applied: false) == nil, "Reset consumes the request")
        precondition(state.next(onAC: false, requested: false, applied: false) == false, "Subsequent undocks also reset")
        state.wrote(false)
        precondition(state.next(onAC: false, requested: false, applied: false) == nil, "Do not repeatedly reset while on battery")
        precondition(state.next(onAC: false, requested: true, applied: false) == true, "Enabling on battery is allowed")
        state.wrote(true)
        precondition(state.next(onAC: false, requested: false, applied: true) == false, "Removing the request disables the override")
    }
}
