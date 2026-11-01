# Shared.Entity

```lua
local Entity = require(ReplicatedStorage.Packages.chrono).Entity
```

!!! note
    Call functions on the module with the entity first, like `Entity.SetCFrame(entity, cframe)`. Entity objects don't have methods.

## Properties

Read properties directly. Use the matching function to change them, such as `Entity.SetBroadPhase`.

- `id: number`: unique ID, the same on the server and on clients. `-1` until the entity is registered.
- `entityConfig: EntityConfig`: the entity type's settings.
- `model: Model | BasePart?`: the entity's model.
- `modelString: string?`: the registered model name, if the entity was created from one.
- `modelReplicationMode: "NATIVE" | "CUSTOM"`: `NATIVE_WITH_LOCK` is stored as `NATIVE` plus a lock, so use `Entity.GetModelReplicationType`.
- `networkOwner: Player?`: the owning player, or nil when the server owns it.
- `isContextOwner: boolean`: whether this context owns the entity.
- `registered: boolean`: whether it's registered in the Holder.
- `destroyed: boolean`
- `paused: boolean`: whether replication is paused.
- `autoUpdatePosition: boolean`: whether Chrono reads the model's CFrame every tick.
- `broadPhase: Vector3?`: the culling box size.
- `snapshot: Snapshot?`: [snapshot history](snapshots.md). Available on clients. On the server, requires client ownership or `STORE_SNAPSHOTS`.
- `latestCFrame: CFrame?`: the newest CFrame.
- `latestTime: number?`: the newest snapshot's time. On the server, for client-owned entities, that's when the packet arrived.
- `lastClientClock: number?`: on the server, for client-owned entities, the owner's clock time of the newest packet.
- `mountParentId: number?` and `mountOffset: CFrame?`: see [Mounting](../guides/mounting.md).
- `interpolation: boolean`: whether client interpolation is enabled. Use `Entity.SetInterpolationMode` to control it.

## Functions

### `new(entityType: string?, model: Model | BasePart | string?, modelReplicationMode: MODEL_REPLICATION_MODE?, initCFrame: CFrame?) -> Entity`

Creates and registers an entity. Server only.

- `entityType`: an [entity type](../getting-started/configurations.md#entity-types) name. Falls back to `DEFAULT`.
- `model`: a `Model` (requires a `PrimaryPart`), a `BasePart`, or a registered [entity model](../getting-started/configurations.md#entity-models) name.
- `modelReplicationMode`: overrides the type's `MODEL_REPLICATION_MODE`.
- `initCFrame`: starting CFrame. Defaults to the model's CFrame. Required for entities without a model.

### `Destroy(entity) -> ()`

Destroys the entity and unregisters it, removes it from clients, and destroys its model on the server. Fires `Destroying`, then disconnects the entity's events. Calling it twice does nothing.

### Model

#### `SetModel(entity, model: Model | BasePart | string?, modelReplicationMode: MODEL_REPLICATION_MODE?, noDestroy: boolean?) -> ()`

Swaps the entity's model. `model` takes the same values as in `new`, or nil to remove the model. Leave `modelReplicationMode` out to keep the current mode. On the server, the old model is destroyed unless `noDestroy` is true. Fires `ModelChanged`.

#### `GetModel(entity) -> Model | BasePart?`

Returns the entity's model or part, or nil.

#### `GetPrimaryPart(entity) -> BasePart?`

The part Chrono moves. The model itself if it's a `BasePart`, otherwise the part set with `Config.SetModelPrimaryForChrono`, or the model's `PrimaryPart`.

#### `GetModelReplicationType(entity) -> "NATIVE" | "NATIVE_WITH_LOCK" | "CUSTOM"`

The entity's current model replication mode.

#### `LockNativeServerCFrameReplication(entity) -> ()` and `UnlockNativeServerCFrameReplication(entity) -> ()`

Server only. Switches a `NATIVE` entity to and from `NATIVE_WITH_LOCK`. Errors on the client or for other modes. Fires `LockChanged`.

### Movement

#### `Push(entity, time: number, cframe: CFrame, velocity: Vector3?) -> boolean`

Adds a snapshot and returns whether it's the newest one. Use `os.clock()` for server timestamps. The newest CFrame is sent next tick. If `velocity` is nil, it will be calculated.

`AUTO_UPDATE_POSITION` automatically calls this on the server/client with the model's CFrame each tick.

#### `SetCFrame(entity, cframe: CFrame) -> ()`

Teleports the entity without interpolating to the new CFrame.

#### `GetCFrame(entity) -> CFrame?`

The newest CFrame (`latestCFrame`), or the primary part's CFrame if there isn't one.

#### `GetAt(entity, time: number) -> CFrame?`

Returns the interpolated CFrame at `time`. Times outside the history return the nearest snapshot. Without history, returns `latestCFrame`.

#### `GetTargetRenderTime(entity) -> number`

Returns the client's render time on the server's clock for server-owned entities, or the owner's clock for client-owned ones. Returns `-1` on the server.

#### `Clear(entity) -> ()`

Clears the snapshot history and the latest time. `latestCFrame` is kept.

#### `SetAutoUpdatePos(entity, autoUpdate: boolean) -> ()`

Turns `AUTO_UPDATE_POSITION` on or off for this entity.

### Ownership

#### `SetNetworkOwner(entity, player: Player?) -> ()`

Server only. Hands the entity to `player`, or back to the server with nil. Fires `NetworkOwnerChanged`.

#### `SyncOwnerShip(entity) -> ()`

Restores ownership on the model's parts after Roblox resets it, such as when adding parts or welds.

### Configuration

#### `SetConfig(entity, entityType: string) -> ()`

Switches the entity to another entity type. An unknown name falls back to `DEFAULT`.

#### `SetInterpolationMode(entity, mode: "CFRAME" | "ALIGN" | "NONE" | nil) -> ()`

Overrides `INTERPOLATION_MODE` for this entity. Pass nil to use the type's mode. Server calls replicate to clients.

- `CFRAME`: sets the primary part's CFrame directly.
- `ALIGN`: uses `AlignPosition` and `AlignOrientation` for local physics. See [Ragdolls](../guides/ragdolls.md).
- `NONE`: doesn't move the entity.

#### `GetClock(entity) -> ClientClock?`

Returns the entity's client clock, or nil on the server.

#### `SetClockBuffer(entity, buffer: number?) -> ()`

Client only. Sets a per-entity buffer in seconds. `0` or less uses an automatic buffer. nil restores the type's `BUFFER`.

#### `SetBroadPhase(entity, broadPhase: Vector3?) -> ()`

Sets the culling box size. nil turns culling off for the entity.

### Data

#### `SetData(entity, data: any) -> ()`

Attaches data that's replicated to clients with the entity. Fires `DataChanged`, on the server and on clients when the data arrives.

#### `GetData(entity) -> any`

Returns the entity's custom data.

### Replication

#### `PauseReplication(entity) -> ()` and `ResumeReplication(entity) -> ()`

Stop and restart Chrono's updates for the entity. While it's paused, clients don't move it, and `NATIVE` falls back to Roblox's own replication.

### Mounting

#### `SetMount(entity, parent: Entity?, offset: CFrame?) -> ()`

Server only. Makes the entity follow `parent` at `offset`. A nil parent clears the mount. Errors if the parent is itself or isn't registered. Fires `Events.EntityMountChanged`. See [Mounting](../guides/mounting.md).

#### `ClearMount(entity) -> ()`

Server only. Fires `Events.EntityMountChanged` with nil.

### Events

#### `GetEvent(entity, name: string) -> Event`

Returns one of the entity's events, listed below. Errors on an unknown name.

## Events

```lua
Entity.GetEvent(entity, "NetworkOwnerChanged"):Connect(function(entity, newOwner, prevOwner)
	print(entity.id, "is now owned by", newOwner)
end)
```

| Event | Arguments | Fires when |
|---|---|---|
| `Destroying` | | The entity is being destroyed. |
| `NetworkOwnerChanged` | `newOwner: Player?`, `prevOwner: Player?` | Its owner changes. |
| `PushedSnapShot` | `time: number`, `cframe: CFrame`, `isNewest: boolean` | A snapshot is added. |
| `TickChanged` | `tier: string`: `"NORMAL"`, `"HALF"` or `"NONE"` | It switches between full rate, half rate, and not ticking. |
| `DataChanged` | `data: any` | Its data changes. |
| `Ticked` | `dt: number` | It ticks, on the side that owns it. |
| `ModelChanged` | `newModel`, `oldModel`: each a `Model`, a `BasePart` or nil | Its model changes. |
| `LockChanged` | `isLocked: boolean` | Its `NATIVE_WITH_LOCK` lock changes. |

## Internal functions

These are used inside Chrono and may change.

### `_new(...) -> Entity`

Like `new`, but doesn't register the entity. Register it later with `Holder.RegisterEntity`.

### `_GetRootPart(entity) -> BasePart?`

The part that's actually moved on the server. The hidden locker part if the entity is locked, otherwise the primary part.

### `_SetPartCFrame(entity, cframe: CFrame)`

Sets the root part's CFrame directly.

### `_LockPartPhysicsReplication(part: BasePart) -> BasePart?`

Locks the physics replication of a part. Returns the locker part.

### `_UnlockPartPhysicsReplication(part: BasePart)`

Unlocks a part locked with `_LockPartPhysicsReplication`.
