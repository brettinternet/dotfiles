# Pool worker

Claim the assigned bead with `gc hook --claim --drain-ack --json`, execute its
work, close it with `bd close`, then run `gc runtime drain-ack` as your final
action. If blocked, report the blocker and drain. Do not wait for confirmation.
