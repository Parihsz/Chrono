# Shared.Snapshots

## Methods

### `Push(t: number, cframe: CFrame, velocity: Vector3) -> ()`

Inserts a snapshot in time order. Drops the oldest when the buffer is full.

### `PushWithCheck(t: number, cframe: CFrame, velocity: Vector3?, tickrate: number, stopped: boolean?) -> ()`

`Push` with the checks Chrono uses for replicated entities. `tickrate` is the expected time between snapshots.

- `stopped` pushes the snapshot with zero velocity.
- Resuming movement adds a zero-velocity snapshot just before the new one.
- Large movements are treated as teleports.
- If `velocity` is nil, it's estimated.

### `GetLatest() -> { t: number, value: CFrame, velocity: Vector3 }?`

The newest snapshot, or nil if the buffer is empty.

### `GetAt(t: number, bypassLock: boolean?) -> CFrame?`

Returns the CFrame at `t`, blending the two snapshots around it with the snapshot's `Lerp` function. Entities use their type's [`INTERPOLATION_FUNCTION`](../getting-started/configurations.md#interpolation-function).

- With only one snapshot, or a `t` outside the stored range, it returns the nearest snapshot.
- A negative `t` returns the newest snapshot.
- After `Entity.SetCFrame`, earlier times are clamped to the teleport. Pass `bypassLock` to read past it.
- Returns nil if the buffer is empty.

### `Clear() -> ()`

Clears the buffer.
