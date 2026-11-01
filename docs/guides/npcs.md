# Entities

Players, NPCs and other replicated objects share the `Entity` API. If you're coming from v1, see [Migration](migration.md).

## Creating an entity

`Entity.new(entityType, model, modelReplicationMode?, initCFrame?)` creates an entity on the server, registers it, and replicates it to clients. Call it after `Chrono.Start()`.

```lua
-- Server
local goblin = Entity.new("DEFAULT", workspace.Goblin)
```

- `entityType` is the name of an [entity type](../getting-started/configurations.md#entity-types). If it's left out or misspelled, the entity uses `DEFAULT`.
- `model` can be a `Model` with a `PrimaryPart`, a `BasePart`, or the name of a registered [entity model](../getting-started/configurations.md#entity-models).

!!! note
    For manual registration, use `Entity._new` followed by `Holder.RegisterEntity`. 

### Sending data with an entity

Use `Entity.SetData` to send extra data with the entity, and `Entity.GetData` to read it. For example, hair color and style:

```lua
-- Server
local npc = Entity.new("DEFAULT", "BasicR6Rig")
Entity.SetData(npc, {
	HAIR_COLOR = "Bright red",
	HAIR_STYLE = "Curly",
})
```

```lua
-- Client
local function ApplyHairStyle(model: Model, hairColor: string, hairStyle: string)
	-- apply the hairstyle to the model
end

Events.EntityAdded:Connect(function(entity)
	local data = Entity.GetData(entity)
	if data and entity.model then
		ApplyHairStyle(entity.model, data.HAIR_COLOR, data.HAIR_STYLE)
	end
end)
```

Connect to `EntityAdded` early, and check `Holder.idMap` for existing entities. Listen to the entity's `DataChanged` event for later changes.

!!! note
    For data that changes often, such as a state machine, use your own remotes and identify the entity by `entity.id`.

## Model replication mode

The model replication mode decides how the entity's model reaches clients. Set it per entity type with `MODEL_REPLICATION_MODE`, per entity in `Entity.new`, or change it later with `Entity.SetModel`.

| | `NATIVE` | `NATIVE_WITH_LOCK` | `CUSTOM` |
|---|---|---|---|
| Model on clients | Replicated by Roblox | Replicated by Roblox | Each client builds its own |
| CFrame replication | Roblox's and Chrono's | Chrono's only | Chrono's only |
| Bandwidth | Highest | Low to medium | Lowest |
| Server's model | Normal physics | Limited physics, including no `Touched` events on server | Separate copy, which can be a plain part |
| Setup | None | None | Register the model on both sides |
| Good for | Dropping Chrono into an existing game, physics NPCs | Characters and other client-owned entities | Many NPCs, or a simple server hitbox with a detailed client model |

### NATIVE_WITH_LOCK

Chrono calls `Entity.LockNativeServerCFrameReplication` to disable Roblox's CFrame replication. For client-owned entities, this also keeps the server model more up to date. See the [showcase](../index.md#showcase).

!!! warning
    This uses a hidden server-side part welded to the primary part. It hasn't been thoroughly tested in live games yet, so feedback is welcome.

### CUSTOM

For a registered model name, each client clones its own template. Otherwise, Chrono sends a model copy and keeps it in the client's `PlayerGui` until the entity goes out of range.

## Different server and client models

In `CUSTOM` mode, register different models under the same name to use a simple server hitbox and a detailed client model:

```lua
-- In your config module
local RunService = game:GetService("RunService")
if RunService:IsServer() then
	chrono.Config.RegisterEntityModel("TestChar", Instance.new("Part"))
else
	chrono.Config.RegisterEntityModel("TestChar", ReplicatedStorage.Models.TestChar)
end
```

## Network ownership

Entities are server-owned by default. Call `Entity.SetNetworkOwner(entity, player)` on the server to let a client move one. Pass `nil` to return ownership to the server.

!!! warning
    Adding parts or welds can reset Roblox ownership to automatic. Call `Entity.SyncOwnerShip(entity)` after changing the model to restore ownership if you encounter this.

## Player characters

A player character is a client-owned entity registered with `Holder.SetAsCharacter`, which also sets up the client's camera. Chrono handles this by default. See [Custom player management](stateless.md#custom-player-management) to register characters yourself.

## Pushing CFrames

With `AUTO_UPDATE_POSITION = true` (the default), move the model normally. Chrono reads its primary part's CFrame every tick and sends changes.

With `false`, call `Entity.Push(entity, time, cframe)` yourself. Use `os.clock()` on the server. The newest CFrame is sent next tick. Automatic updates overwrite manually pushed CFrames.

### SetCFrame vs Push

- `Entity.Push` is for normal movement, and is interpolated like any other update.
- `Entity.SetCFrame` is a teleport: clients jump straight to the new CFrame instead of interpolating to it, and for a client-owned entity the owner's model is moved too.

## Distance-based tick rate

Entities send less often to players who are far away:

- **Full rate** within `NORMAL_TICK_DISTANCE`.
- **Half rate** between `NORMAL_TICK_DISTANCE` and `HALF_TICK_DISTANCE`.
- **Beyond `HALF_TICK_DISTANCE`:** `CUSTOM` and `NATIVE_WITH_LOCK` entities aren't sent to that player at all, and are removed from their client until they come back in range. `NATIVE` entities keep being sent at half rate.

By default every type uses `DEFAULT_NORMAL_TICK_DISTANCE` and `DEFAULT_HALF_TICK_DISTANCE` from your config, and you can override them per type:

```lua
-- In your config module
chrono.Config.RegisterEntityType("NPC", {
	TICK_RATE = 1 / 30, -- 30 Hz
	NORMAL_TICK_DISTANCE = 50, -- 30 Hz up to 50 studs
	HALF_TICK_DISTANCE = 150, -- 15 Hz up to 150 studs
})

local myNPC = Entity.new("NPC", workspace.Goblin)
```

To keep an entity a player already has for a few more studs past `HALF_TICK_DISTANCE`, so one moving along the edge isn't removed and re-sent each time it crosses, set `HALF_TICK_MARGIN`. See [Distance-based replication](../getting-started/configurations.md#distance-based-replication).

To keep an entity on every client no matter the distance, set `HALF_TICK_DISTANCE = math.huge`. The entity's `TickChanged` event fires when it switches between full rate, half rate and not ticking.

## Client-side culling

Pass a culling box size to `Config.RegisterEntityModel` as its third argument, or use `Entity.SetBroadPhase` later. Chrono checks the box's 8 corners and skips interpolation while off screen. `Vector3.zero` checks only the primary part's center. No broadphase means no culling.

!!! warning
    Avoid large culling boxes since corners can be off screen while the middle is still visible if the camera is close.

## Changing models

`Entity.SetModel(entity, model, modelReplicationMode?, noDestroy?)` swaps an entity's model. Pass a replication mode to switch modes at the same time, or leave it out to keep the current one. On the server, the old model is destroyed unless you pass `noDestroy = true`.

## REPLICATE_DEATHS and REPLICATE_CFRAME_SETTERS

These settings preserve Roblox behavior for player-owned entities. See [Death and CFrame replication](../getting-started/configurations.md#death-and-cframe-replication).

- `REPLICATE_CFRAME_SETTERS`: when server code moves a player-owned entity's root part, Chrono calls `Entity.SetCFrame` so the owner is moved too.
- `REPLICATE_DEATHS`: forwards client-reported humanoid deaths to the server and other clients. The default, `PLAYER_CHARACTERS`, prevents players from killing other entities they own through this feature.

Set either to `NONE` to handle these cases yourself with events and remotes.

## Pausing replication

`Entity.PauseReplication` and `Entity.ResumeReplication` stop and restart Chrono's updates for an entity, without destroying it. While it's paused, clients don't move it, and a `NATIVE` model falls back to Roblox's own replication.

## Destroying an entity

`Entity.Destroy` destroys the entity on the server, removes it from every client, and disconnects its events.

!!! warning
    Destroying the model with `Instance:Destroy()` leaves the entity registered. Use `Entity.Destroy`.
