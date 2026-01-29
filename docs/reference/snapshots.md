# Shared.Snapshots

## Methods

### `Push(t: number, value: T)`

Inserts a snapshot into the buffer.

- Maintains **chronological order**  
- Overwrites **oldest entries** when full

---

### `GetLatest() → SnapshotData<T>?`

Returns the **most recent snapshot**, or `nil` if empty.

---

### `GetAt(t: number, bypassLock: boolean? ) → T?`

Returns the **interpolated value** at timestamp `t`:

- Interpolates linearly between **before** and **after** snapshots
- Handles **wrap-around** between `0` and `255` timestamps
- Returns the **closest value** if interpolation is not possible
- `bypassLock` - If true, ignores any locks on the snapshot buffer when retrieving data. Locks prevent interpolation after certain time.

---

### `Clear() -> ()`
Clears the snapshot buffer.

## Usage Notes

- `lerp` must handle your type `T` (e.g., `CFrame.Lerp`, `Vector3:Lerp`)  
- Used internally by **Chrono replication** for **smooth CFrame interpolation**  
- Buffer automatically handles **late or out-of-order packets** without breaking motion continuity
