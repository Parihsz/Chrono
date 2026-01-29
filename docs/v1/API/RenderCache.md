# RenderCache

## Initialization

### `RenderCache.Init(dependencies)`

Initializes the module.

| Parameter             | Type                  | Description                                    |
|-----------------------|----------------------|------------------------------------------------|
| `playerTickRates`     | `{ [number]: number }` | Map of network IDs to tick rates.              |
| `bufferTracker`       | `InterpolationBuffer` | Reference to an interpolation buffer tracker.  |

---

## Methods

### `RenderCache.GetBuffer(id: number) → number`

Returns the **current interpolation buffer** for the given network ID.

- NPCs use the **fixed buffer** from `Config.NPC_TYPES`  
- Players use the **dynamic buffer** calculated by `InterpolationBuffer`  

---

### `RenderCache.OnSnapshotUpdate(snapshot: { [number]: number })`

Updates **internal timing** whenever a new snapshot of **server timestamps** is received.

- Stores the last known server tick for each entity  
- Prepares for calculating the **next render timestamp**

---

### `RenderCache.Update(deltaTime: number)`

Advances **target render times** per entity.

- Predicts server time based on last tick and delta  
- Smooths timing errors using drift correction  
- Snaps to server time if error exceeds **0.1s**

---

### `RenderCache.GetTargetRenderTime(id: number) → number`

Returns the **target render timestamp** for a given entity.  
If no render time exists yet, returns `0` and emits a warning.

---

### `RenderCache.GetEstimatedServerTime(id: number) → number`

Estimates the **current server time** for an entity.  
Uses the last known tick plus local elapsed time.

---

### `RenderCache.Add(id: number, isNPC: boolean?, npcType: string?)`

Registers a new **player or NPC** in the cache.

- Initializes timing data  
- NPCs are flagged and associated with a type if provided

---

### `RenderCache.Remove(id: number)`

Removes an entity from the cache and clears all timing information.
