# Snapshots

## Types

### `SnapshotData<T>`

| Field     | Type   | Description              |
|----------|-------|--------------------------|
| `t`      | number | The snapshot timestamp   |
| `value`  | `T`    | The stored value         |

---

### `Snapshot<T>`

A snapshot buffer with indexing and interpolation.

| Field / Method                  | Type                                               | Description                                    |
|---------------------------------|---------------------------------------------------|------------------------------------------------|
| `cache`                         | `{ SnapshotData<T> }`                              | Internal buffer                                 |
| `lerp(a: T, b: T, alpha: number)` | `(T, T, number) -> T`                            | Linear interpolation function for type `T`     |
| `Push(t, value)`                 | `(self, number, T) -> ()`                         | Inserts a snapshot at timestamp `t`            |
| `GetLatest()`                    | `(self) -> SnapshotData<T>?`                      | Returns the most recent snapshot               |
| `GetAt(t)`                       | `(self, number) -> T?`                            | Returns an **interpolated value** at time `t`  |

---

## Methods

### `Push(t: number, value: T)`

Inserts a snapshot into the buffer.

- Maintains **chronological order**  
- Overwrites **oldest entries** when full

---

### `GetLatest() → SnapshotData<T>?`

Returns the **most recent snapshot**, or `nil` if empty.

---

### `GetAt(t: number) → T?`

Returns the **interpolated value** at timestamp `t`:

- Interpolates linearly between **before** and **after** snapshots
- Handles **wrap-around** between `0` and `255` timestamps
- Returns the **closest value** if interpolation is not possible

---

## Usage Notes

- `lerp` must handle your type `T` (e.g., `CFrame.Lerp`, `Vector3:Lerp`)  
- Used internally by **Chrono replication** for **smooth CFrame interpolation**  
- Buffer automatically handles **late or out-of-order packets** without breaking motion continuity
