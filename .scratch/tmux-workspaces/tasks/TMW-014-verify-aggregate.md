# TMW-014: Verify aggregate launcher behavior

Status: pending

Area: Verification

Depends on: TMW-006, TMW-009, TMW-010, TMW-011, TMW-012, TMW-013

Source: [Tmux Workspace Restructuring spec](../spec.md)

## Outcome

Exercise aggregate repetition, ordering, attachment, switching, and partial-failure propagation in isolation.

## Acceptance checklist

- [ ] Start twice and confirm no sessions or windows are duplicated.
- [ ] Stop twice and confirm both runs succeed and use the required reverse group order.
- [ ] Force one start child to fail and confirm later groups are still invoked.
- [ ] Confirm a partial start failure identifies the failing group and returns nonzero.
- [ ] Confirm aggregate start neither attaches nor switches after a partial failure.
- [ ] Confirm successful start attaches outside tmux and switches clients inside tmux.
- [ ] Force a stop child to fail and confirm later groups still run, the failure is identified, and aggregate stop returns nonzero.
- [ ] Record the focused verification evidence.

## Verification evidence

_Add evidence here when completing the task._

