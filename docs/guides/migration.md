# Migrating from Chrono v1 to v2

When v1 was being developed it was designed around for player characters and adding support for npcs was an afterthought. This led to a lot of limitations and complications in the codebase. With v2 we redesigned the entire system from the ground up to be more flexible and extensible.

## Starting Chrono

The startup process remains the same—call `Chrono.Start()` on both server and client.

## Configurations

v1 provided direct access to the `Config` table. v2 uses a function-based API instead. Before calling `Chrono.Start()`, create a shared module that requires the config module and uses `SetConfig()`, `RegisterEntityType()`, and `RegisterEntityModel()`.

!!! info
    In v2 we highly encourage using these functions instead of directly modifying the config table because it allows your configurations to not be reset when updating Chrono.

**v1 Configuration:**

```lua
local Config = ...
Config.SHOW_WARNINGS = false
Config.NPC_TYPES.NPC = { TICK_RATE = 1 / 30 }
```

**v2 Configuration:**

```lua
local Config = ...
Config.SetConfig("SHOW_WARNINGS", false)
Config.RegisterEntityType("NPC", { TICK_RATE = 1 / 30 })
```

v2 expands configurability with custom entity types, proximity controls, and per-entity full rotation options.

**v1 Entity Config Type:**

```lua
export type NPC_CONFIG = {
    BUFFER: number,
    TICK_RATE: number,
}
```

**v2 Entity Config Type:**

```lua
export type EntityConfigInput = {
    BUFFER: number,
    TICK_RATE: number,
    FULL_ROTATION: boolean?,
    AUTO_UPDATE_POSITION: boolean?,
    STORE_SNAPSHOTS: boolean?,
    MODEL_REPLICATION_MODE: MODEL_REPLICATION_MODE?,
    NORMAL_TICK_DISTANCE: number?,
    HALF_TICK_DISTANCE: number?,
    CUSTOM_INTERPOLATION: boolean?,
}
```

### Replication Modes

v2 allows replication mode configuration per entity instead of globally.

| v1                                    | v2                 | Description                                                 |
| ------------------------------------- | ------------------ | ----------------------------------------------------------- |
| `ENABLE_CUSTOM_CHARACTERS = true`     | `CUSTOM`           | Server and client create separate models                    |
| `DISABLE_DEFAULT_REPLICATION = true`  | `NATIVE_WITH_LOCK` | Disables replication while maintaining client-side movement |
| `DISABLE_DEFAULT_REPLICATION = false` | `NATIVE`           | Roblox native replication without modification              |

!!! info
    We changed how `DISABLE_DEFAULT_REPLICATION` replication works. In v1 we would anchor the part on the server and unanchored on the client. And for moving the character on the server required a `REPLICATOR` model. With v2 we do a new trick using welds that allows replication to stay disabled while still allowing the server to move the character without needing a mock model.

### Replication Proximity

v1 Only have one global replication proximity setting for players. v2 allows you to configure replication proximity separately for player and npcs.

## Entity API

v2 has a single `Entity` class for all entities instead of separate `NpcRegistry` and `Character`. v2 also supports parts for entity models instead of just models. 

### Usage

Here are some examples of creating entities, setting network owner and destroying entities in v1 vs v2.

```lua
--v1
local id = NpcRegistry.Register(model, "NPC",nil,true)
NpcRegister.SetPosition(id, cframe)
SetPosition.SetNetworkOwner(id, player)
local latestCFrame = Replicate.GetLatestCFrame(id)
NpcRegistry.UnRegister(id)

```

```lua
--v2
local entity = Entity.New("NPC",modelOrpartOrModelName)
Entity.SetCFrame(entity, cframe)
Entity.SetNetworkOwner(entity, player)
local latestCFrame = entity.latestCFrame
Entity.Destroy(entity)
```

## Holder

Holder is a centralized module that keeps track of player entities and character entities. In v1 player entities were stored in its own `Replicate` modules that were different between server and client. In v2 we moved all the player entity management to `Holder` which is shared between server and client. 

## Player handling

v1 had Player handling hardcoded. In v2 you can chose to either use the built in player handling or implement your own custom player replication by setting `PLAYER_REPLICATION` to `AUTOMATIC` or `CUSTOM` respectively. With `AUTOMATIC` Chrono will automatically create entities for player characters and replicate them according to the `PLAYER` entity type settings. With `CUSTOM` you can create and manage player entities yourself which is useful for advanced use cases like custom character rigs or non-character player entities.

### Registering players

With `AUTOMATIC` player entities are automatically created when players join and destroyed when players leave. With `CUSTOM` you can create player entities manually like this:

```lua
local newEntity = Entity.new(config, character, modelRepMode :: any)
Holder.SetAsCharacter(player, newEntity)
Entity.SetNetworkOwner(newEntity, player)
```

!!! info
    `Holder.SetAsCharacter` is just a way to tell chrono that this entity is the character for this player. It just allows chrono to set the character as the camera subject and do other character related things. It doesn't have any special replication behavior by itself.

Because this uses the Entity api you can also change the Character model without having to go through a separate character api like in v1.

```lua
-- v1
Characters.SetCharacter(player, newModel)
```

```lua
-- v2
local playerEntity = Holder.GetEntityFromPlayer(player)
Entity.SetModel(playerEntity, newModel)
```

## Optimizations

### Ticker
Chrono v2 now uses a ticker system per entity type instead of a single global tick rate. This allows you to have different tick rates for different entity types while being very performant. v2 also only keeps track of one Interpolation buffer per entity type instead of per entity which allows for more consistent interpolation and less memory usage.

### Rotation Replication
v2 allows you to choose whether to replicate full rotation (CFrame) or just the y-axis rotation per entity type. While v1 only had 1 global setting for this. You can also change the entity type at runtime which allows you to change whether to replicate full rotation or not at runtime.

### Culling
v2 has built in frustum culling which helps improve performance by only updating entities that are within the camera's view.