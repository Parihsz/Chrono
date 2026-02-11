# Entities

## Introduction

In chrono v1 we kept Entities and Player's separate, but in v2 we have merged them together. This means both players and entities utilize the same systems. v2 Npcs also get more configuration options such as model replication mode and distance-based tick rate which v1 npcs didn't have.

## Creating an Entity

When you create an entity via `Entity.new` this will automatically register it and replicate the data to other clients. Entities will also take on the `DEFAULT` config if no config is specified.

!!! note
    You could have more manual control over when the entity via `Entity._new` where it will create the entity but not register it. You would have to call `Holder.RegisterEntity` manually to register it and replicate it to clients. 

### Sending data related to the entity

When you create an entity you can add data to it via `Entity.SetData` and retrieve it via `Entity.GetData`. This is useful for sending information related to the entity that isn't easily derived from the model. For example you can send small details like hair color/style and when the client receives the entity data, they can apply the hair color/style to the model.

Example:

```lua
-- Server
local myEntity = Entity.new("Entity", "BasicR6Rig")
Entity.SetData(myEntity, {
    HAIR_COLOR = "Bright red",
    HAIR_STYLE = "Curly",
})

--- Client
local function ApplyHairStyle(model: Model, hairColor: string, hairStyle: string)
    -- apply the hairstyle to the model
end

Events.EntityAdded:Connect(function(entity)
    local data = Entity.GetData(entity)
    local hairColor = data.HAIR_COLOR
    local hairStyle = data.HAIR_STYLE

    local model = entity.model
    ApplyHairStyle(model, hairColor, hairStyle)
end)

```

!!! note
    If you want to send other data that is related to the entity such as when a state changes we recommend using your own implementation via remotes and using `entity.id` as and identifier to send the data related to that entity.

## Model Replication Mode

When you create an entity, you can specify the model replication mode via the entity configuration. This controls how the model is replicated to clients. The options are:

### NATIVE

Chrono replicates the model along with using Roblox's native model replication. The server models can simulate physics normally while clients receive live updates.

**Best for:** Physics-based NPCs, simpler setups where you want to leverage Roblox's native replication and don't mind the extra bandwidth.

**Bandwidth:** Medium

### NATIVE_WITH_LOCK

Chrono replicates the model using Roblox's native replication, but locks server-side physics. On the client, the model is unlocked so it can simulate physics, while on the server physics is stopped to save Bandwidth. Calls `Entity.LockNativeServerCFrameReplication` internally.

**Best for:** Client-owned entities (player characters, client-controlled objects) where you want the client to still be able to simulate physics but the server doesn't need to and saving bandwidth is a concern.

**Bandwidth:** Low 

!!! warning
    The way we current implement this is by having an server-side anchored part (hidden via camera) welded to the primary part of the model. This method will stop replication but still allow the model to be moved on the server. However, this has not been thoroughly tested in live environments so any feedback on this method is appreciated.


### CUSTOM

Chrono creates a server and client model separately and only replicates CFrames. This is good for low-bandwidth but requires more manual setup. 

**Best for:** NPCs where you want a more detailed client model but a simpler server model for hitbox calculations and performance, or any entity where you want to minimize bandwidth and are okay with the extra setup.

**Bandwidth:** Low

!!! note
    Initial model replication differs by mode. For `NATIVE` and `NATIVE_WITH_LOCK`, the model is replicated using Roblox's native system. For `CUSTOM`, if the model is a string reference it's passed to the client to load, otherwise a copy is created and temporarily stored in the client's `PlayerGui` until it's out of range.

## Different Server and Client Models

With `CUSTOM` replication mode, you can have completely different models on the server and client. This is useful for NPCs where you want the client to have a more detailed model while the server has a simpler model for hitbox calculations and performance. You can specify the server and client models when registering the entity model in your config.`

Example:

```lua
--server.luau
Config.RegisterEntityModel("TestChar", Instance.new("Part"))

--client.luau
Config.RegisterEntityModel("TestChar", Path.To.Model)
```

This would register a part as the model for the entity on the server and a different model on the client. This is useful for NPCs where you want the client to have a more detailed model while the server has a simpler model for hitbox calculations and performance.

## Network ownership

Entities will have a default ownership of the server, to give a client control of an entity you can set it via `Entity.SetNetworkOwner`.

## Player Character

The only thing that separates a player character from a client-owned entity is that player characters should also be registered to `Holder.SetAsCharacter` so that when a character is added chrono knows to change the camera logic on the client.

```lua
--Example from Server/Player.luau

character.Archivable = true
local newEntity = Entity.new(config, character, modelRepMode)
Holder.SetAsCharacter(player, newEntity)
Entity.SetNetworkOwner(newEntity, player)
```

## Pushing CFrames

By default `AUTO_UPDATE_POSITION` is set as true. This means Chrono will automatically call `Entity.Push` every tick passing in the primary part's CFrame to replicate movement.

If set to false, you must manually call `Entity.Push` whenever the entity's position changes. This is useful if you want to control exactly when position updates are sent (e.g., only on significant movements to save bandwidth).

!!! note
    When `AUTO_UPDATE_POSITION` is true, calling `Entity.Push` manually will also work and its update will be sent alongside the automatic one.

### SetCFrame vs Push

`Entity.SetCFrame` will set the CFrame of the entity's model on the server and if the entity is client-owned, it will also teleport the client model to that CFrame. While `Entity.Push` is ment to be used for non-teleporting movement where you want the server to replicate the movement.

## Distance-based tick rate

Entities automatically adjust their update frequency based on distance to nearby players, reducing network traffic for distant entities.

**Distance Zones:**

- **Full Updates** (0 to NORMAL_TICK_DISTANCE): Full tick rate - updates every tick
- **Half Updates** (NORMAL_TICK_DISTANCE to HALF_TICK_DISTANCE): Reduced tick rate - updates every other tick
- **No Replication** (beyond HALF_TICK_DISTANCE): Entity is not replicated to this player only applies for CUSTOM replication mode, NATIVE and NATIVE_WITH_LOCK entities will continue to replicate at half tick

By default, Chrono uses `DEFAULT_NORMAL_TICK_DISTANCE` and `DEFAULT_HALF_TICK_DISTANCE` from your config. You can override these per-entity by setting `NORMAL_TICK_DISTANCE` and `HALF_TICK_DISTANCE` in the entity configuration.

**Example:**

```lua
Config.RegisterEntityType("NPC", {
    TICK_RATE = 1 / 30,           -- Replicates every 1/30th of a second (30 hz)
    NORMAL_TICK_DISTANCE = 50,    -- Full updates up to 50 studs (30 hz)
    HALF_TICK_DISTANCE = 150,     -- Half updates up to 150 studs (15 hz)

})

local myNPC = Entity.new("NPC",...)
```

!!! note
    For `CUSTOM` replication mode: Entities are completely removed from clients when outside `HALF_TICK_DISTANCE` and re-added when within range. To keep entities always present on the client, set `HALF_TICK_DISTANCE = math.huge`.

## Client Side Culling

Chrono can reduce rendering costs on the client by not updating the CFrames if the entities are not in the player's viewport. To enable culling for an entity you can passing in a third parameter to `Config.RegisterEntityModel` which specifies the broad phase size of the hitbox for culling. If the vector is zero then only a point check is done from the center of the primary part. Otherwise 8 corner points of a box will be checked. If the parameter is not passed then no culling will be done. Another way to is via `Entity.SetBroadPhase` which allows you to change the broad phase size dynamically as well.

!!! warning
    We do not recommend adding a broad phase for a large hitbox due to the fact that we do corner checks to see if an entity should be on screen and a large hitbox would potentially be marked as off screen even if it should be on screen because all the corner points are off screen.

## Changing models

You can change a entity's model by calling `Entity.SetModel` you can also use this method to change the entities replication mode by passing in a model with a different replication mode registered to it. If a replication mode is not specified for the model then it will use the current replication mode of the entity.

## REPLICATE_DEATHS & REPLICATE_CFRAME_SETTERS

These configs are useful for maintaining default Roblox behavior.
`PLAYER_ENTITIES` means all player owned entities will have this behavior, while `PLAYER_CHARACTERS` means only entities registered as characters will have this behavior. You can disable these by setting them to `NONE` and implementing your own custom logic for handling these cases via events and remotes.

### REPLICATE_CFRAME_SETTERS
When set to `PLAYER_ENTITIES` or `PLAYER_CHARACTERS` then the server will automatically call `Entity.SetCFrame` for player-registered entities when their we detect that their primary part CFrame has changed. This is useful for when you want to be able to move the character on the server and have it replicate to clients without having to call `Entity.SetCFrame` manually. 

### REPLICATE_DEATHS
When set to `PLAYER_ENTITIES` or `PLAYER_CHARACTERS` then the server will automatically destroy the entity when we detect that the player's character has died. This is due to sometimes death state not properly replicating to the server even in `NATIVE` mode. 

!!! warning
    When using REPLICATE_DEATHS we recommend setting it to `PLAYER_CHARACTERS` as this makes it so users can't just kill other entities they own.


## Pausing replication

You can pause/resume replication of an entity via `Entity.PauseReplication` and `Entity.ResumeReplication`. Pausing the replication of an entity will stop the server from sending updates to clients, but the entity will still exist on the client and server. This is useful for cases where you want to temporarily stop replication of an entity without destroying it.

## Destroying an Entity

When you call `Entity.Destroy`, this will destroy the entity on the server and remove the entity from the registry, which will remove it from all clients. This will also cleanup and listeners connected to the entity.
