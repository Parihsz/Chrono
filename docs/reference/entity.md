# Shared.Entity

## Properties

- `broadPhase` : `Vector3?` - The broadphase size of the entity used for culling.

- `autoUpdatePosition` : `boolean?` - Whether Chrono will automatically call `Entity.Push` when the entity model moves. Default is true.

- `isContextOwner` : `boolean` - Whether this entity is owned by the current context (server or client).

- `networkOwner` : `Player?` - The player who owns this entity on the server. Nil if unowned or on client.

- `snapshot` : `Snapshot?` - Snapshot data for the entity.

- `latestCFrame` : `CFrame?` - The latest CFrame of the entity.

- `latestTime` : `number?` - The latest timestamp of the entity.

- `id` : `number` - The unique ID of the entity. Will be -1 if not registered.

- `entityConfig` : `EntityType` - The configuration table for this entity.

- `modelString` : `string?` - The model string name for this entity if present.

- `model` : `Model|BasePart?` - The model or base part of this entity.

- `paused` : `boolean` - Whether this entity is paused.

- `modelReplicationMode` : `"NATIVE" | "CUSTOM"?"` - The model replication mode for this entity.

- `registered` : `boolean` - Whether this entity is registered in holder.

- `mountParentId` : `number?` - The ID of the parent entity this entity is mounted to, if any.

- `mountOffset` : `CFrame?` - The offset CFrame of this entity when mounted to a parent entity.

- `interpolation` : `Boolean` - If this is false, Chrono will not interpolate the entity on the client. 

!!! info
    For setting properties use the appropriate methods like `Entity.SetBroadPhase`, `Entity.SetAutoUpdatePosition`, etc. Goes the same for getting properties.

## Functions

### `new(entityConfig: string?, model: Model | BasePart | string?, modelReplicationMode: MODEL_REPLICATION_MODE?, initCFrame: CFrame?) -> Entity`

Creates a new Entity instance and automatically registers it.

- `entityConfig` - The entity type name to use for this entity. If nil, uses "DEFAULT".
- `model` - The model or base part to use for this entity, or the model string name if using custom replication.
- `modelReplicationMode` - The model replication mode to use for this entity. If nil, uses the default from config or entity type.
- `initCFrame` - The initial CFrame to set for this entity. If nil, uses the model's current CFrame.

### `SetModel(self: Entity, model: Model | BasePart | string?, modelReplicationMode: MODEL_REPLICATION_MODE?, noDestroy: boolean?) -> ()`

Sets the model or base part for this entity. If using custom replication, can also provide a model string name. If model is nil, unsets the model.

- `model` - The model or base part to set for this entity, or the model string name if using custom replication.
- `modelReplicationMode` - The model replication mode to use for this entity. If nil, uses the default from config or entity type.
- `noDestroy` - If true, does not destroy the previous model when changing. Only applies to SERVER context.

### `GetModel(self: Entity) -> Model | BasePart?`

Gets the model or base part of this entity. Returns nil if not set.

### `SetConfig(self: Entity, entityConfig: string) -> ()`

Sets the entity type configuration for this entity.

- `entityConfig` - The entity type name to use for this entity.

### `SetClockBuffer(self: Entity, buffer: number?) -> ()`

!!! Warning "Client Only"
    Calling this on the server errors.

Sets a per-entity interpolation buffer, creating a dedicated client clock for this entity. This overrides the entity config's `BUFFER` and is not affected by later `config:UpdateBuffer` changes.

- `buffer` - The buffer time in seconds. Pass `0` (or a negative value) for a dynamic buffer. Pass `nil` to clear the override and fall back to the entity config's buffer.

!!! note
    Intended for client-owned entities. To change the buffer for server-owned entities, use `config:UpdateBuffer` (per type) instead.

### `SetBroadPhase(self: Entity, broadPhase: Vector3?) -> ()`

Sets the broadphase size for this entity used for culling. If nil, unsets broad

- `broadPhase` - The broadphase size to set for this entity.

### `GetData(self: Entity) -> any`

Gets the custom data table for this entity. Can be used to store arbitrary data.

### `SetData(self: Entity, data: any) -> ()`

Sets the custom data table for this entity. Can be used to store arbitrary data which gets replicated to clients.

### `SetMount(self: Entity, parent: Entity, offset: CFrame?) -> ()`

!!! warning "Server Only"
    This can only be called on the server. Mount state is automatically replicated to clients.

Sets the mount parent of this entity to another entity with an optional offset CFrame. Can be called every frame to animate the offset. Fires `Events.EntityMountChanged`.

- `parent` - The entity to mount this entity to.
- `offset` - The CFrame offset applied relative to the parent each frame.

### `ClearMount(self: Entity) -> ()`

!!! warning "Server Only"
    This can only be called on the server.

Clears the mount parent of this entity, if any. Fires `Events.EntityMountChanged` with `nil`.

### `SetNetworkOwner(self: Entity, player: Player?) -> ()`

Sets the network owner of this entity on the server. If nil, unsets ownership.

### `SyncOwnerShip(self: Entity) -> ()`

Syncs the ownership status of this entity and its model. This is useful if you encounter issues with Roblox resetting the parts ownership.

### `Clear(self: Entity) -> ()`

Clears snapshot data and resets last cached cframe and time.

### `PauseReplication(self: Entity) -> ()`

Pauses replication for this entity.

### `ResumeReplication(self: Entity) -> ()`

Resumes replication for this entity.

### `Push(self: Entity, time: number, value: CFrame, velocity: Vector3?) -> boolean`

Pushes a new snapshot value for this entity at the given time. Returns true if it is the latest snapshot.

- `time` - The timestamp of the snapshot.
- `value` - The CFrame value of the snapshot.
- `velocity` - The velocity of the snapshot. If nil, velocity will be calculated based on the previous snapshot.

### `GetAtTime(self: Entity, time: number) -> CFrame?`

Gets the interpolated CFrame of this entity at the given time. Returns nil if no data

- `time` - The timestamp to get the interpolated CFrame for.

### `GetTargetRenderTime(self: Entity) -> number`

Gets the target render time for this entity based on buffer settings. Returns `-1` if no render cache is configured.

### `SetAutoUpdatePosition(self: Entity, autoUpdate: boolean) -> ()`

Sets whether Chrono will automatically call `Entity.Push` when the entity model moves.

### `GetCFrame(self: Entity) -> CFrame?`

Gets the latest CFrame of this entity. Will first check `self.latestCFrame` then fall back to the model's PrimaryPart CFrame if available.

### `SetCFrame(self: Entity, cframe: CFrame) -> ()`

This will move the entity instead of interpolating it.

### `GetPrimaryPart(self: Entity) -> BasePart?`

Gets the PrimaryPart of the entity's model, if available.

### `LockNativeServerCFrameReplication(self: Entity) -> ()`

Locks the native server CFrame replication for this entity's model. Only applies to SERVER context and NATIVE model replication mode.

### `UnlockNativeServerCFrameReplication(self: Entity) -> ()`

Unlocks the native server CFrame replication for this entity's model. Only applies to SERVER context and NATIVE model replication mode.

### `Destroy(self: Entity) -> ()`

Destroys this entity and unregisters it from the holder. Cleans up model and snapshot data.

### `GetEvent(self: Entity, eventName: string) -> Event?`

Gets a custom event for this entity by name.

## Events

These events can be accessed via `Entity.GetEvent(self,eventName)`.

### `Destroying`

Fired when the entity is being destroyed.

### `NetworkOwnerChanged`

Fired when the network owner of the entity changes. Provides the new Player or nil.

- newOwner : `Player?` - The new network owner player or nil.
- prevOwner : `Player?` - The previous network owner player or nil.

### `PushedSnapShot`

Fired when a new snapshot is pushed to the entity.

- time : `number` - The timestamp of the pushed snapshot.
- value : `CFrame` - The CFrame value of the pushed snapshot.
- isLatest : `boolean` - Whether this snapshot is the latest one.

### `TickChanged`

Fired when the tick rate of the entity changes.

- newTickType : `string` - The new tick type name.
  - NONE - No ticking
  - NORMAL - Normal tick rate
  - HALF - Half tick rate

### `DataChanged`

Fired when the custom data of the entity changes.

- newData : `any` - The new custom data.

### `Ticked`

Fired when the entity is ticked.

- deltaTime : `number` - The delta time since last tick.

### `ModelChanged`

Fired when the model of the entity changes.

- newModel : `Model | BasePart?` - The new model or base part of the entity.
- oldModel : `Model | BasePart?` - The previous model or base part of the entity.

### `LockChanged`

Fired when the native server CFrame replication lock state changes.

- isLocked : `boolean` - Whether the native server CFrame replication is locked.


## Internal Functions

### `_GetRootPart(entity: Entity) -> BasePart?`

Returns the root part, if the entity is locked then this will return the locker part, otherwise it will return the primary part or base part.

### `_SetPartCFrame(entity: Entity, cframe: CFrame)`

Sets the root part's CFrame directly.

### `_LockPartPhysicsReplication(part: BasePart): BasePart?`

Locks the physics replication of the given part. Returns the locker part if successful, otherwise returns nil.

### `_UnlockPartPhysicsReplication(part: BasePart)`
Unlocks the physics replication of the given part if it is currently locked.