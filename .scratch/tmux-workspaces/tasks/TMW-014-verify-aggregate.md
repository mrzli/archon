# TMW-014: Verify aggregate launcher behavior

Status: completed

Area: Verification

Depends on: TMW-006, TMW-009, TMW-010, TMW-011, TMW-012, TMW-013

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise aggregate repetition, ordering, attachment, switching, and partial-failure propagation in isolation.

## Acceptance checklist

- [x] Start twice and confirm no sessions or windows are duplicated.
- [x] Stop twice and confirm both runs succeed and use the required reverse group order.
- [x] Force one start child to fail and confirm later groups are still invoked.
- [x] Confirm a partial start failure identifies the failing group and returns nonzero.
- [x] Confirm aggregate start neither attaches nor switches after a partial failure.
- [x] Confirm successful start attaches outside tmux and switches clients inside tmux.
- [x] Force a stop child to fail and confirm later groups still run, the failure is identified, and aggregate stop returns nonzero.
- [x] Record the focused verification evidence.

## Verification evidence

The `aggregate start and stop` and `aggregate failure propagation` isolated tests passed. Real child launchers start twice without duplicate state, attach outside tmux, switch inside tmux, and stop twice in reverse group order. Stub children verify caller-directory independence, continued invocation after start and stop failures, failure identification and status propagation, and suppression of attach/switch after partial start failure.
