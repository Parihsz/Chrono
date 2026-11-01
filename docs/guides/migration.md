# Migrating from Chrono v1 to v2

v2 brings players and NPCs into one Entity API, with per-type replication settings.

## Starting Chrono

Starting is the same: call `Chrono.Start()` on both the server and the client.

## Configurations

v1 gave you direct access to the `Config` table. v2 uses functions instead: before calling `Chrono.Start()`, create a shared module that calls `SetConfig()`, `RegisterEntityType()` and `RegisterEntityModel()`. See [Configuration](../getting-started/configurations.md).

!!! info
    Use a separate config module so updating Chrono doesn't overwrite your settings.

**v1 configuration:**

```lua
local Config = ...
Config.SHOW_WARNINGS = false
Config.NPC_TYPES.NPC = { TICK_RATE = 1 / 30 }
```

**v2 configuration:**

```lua
local Config = require(ReplicatedStorage.Packages.chrono).Config
Config.SetConfig("WARNING_SEVERITY", "NONE") -- or Config.SetWarningSeverity("NONE")
Config.RegisterEntityType("NPC", { TICK_RATE = 1 / 30 })
```

v2 adds custom entity types, distance controls, and full rotation per entity type.

**v1 entity config type:**

```lua
export type NPC_CONFIG = {
    BUFFER: number,
    TICK_RATE: number,
}
```

**v2 entity config type**:

```lua
export type EntityConfigInput = {
    BUFFER: number,
    TICK_RATE: number,
    FULL_ROTATION: boolean?,
    AUTO_UPDATE_POSITION: boolean?,
    STORE_SNAPSHOTS: boolean?,
    MODEL_REPLICATION_MODE: MODEL_REPLICATION_MODE?,
    ASSEMBLY_ROOT_PART_CHECK: boolean?,
    NORMAL_TICK_DISTANCE: number?,
    HALF_TICK_DISTANCE: number?,
    CUSTOM_INTERPOLATION: boolean?,
    INTERPOLATION_MODE: INTERPOLATION_MODE?,
}
```

The fields are explained under [Entity types](../getting-started/configurations.md#entity-types).

### Replication Modes

v2 allows replication mode configuration per entity instead of globally.

| v1                                    | v2                 | Description                                                 |
| ------------------------------------- | ------------------ | ----------------------------------------------------------- |
| `ENABLE_CUSTOM_CHARACTERS = true`     | `CUSTOM`           | Server and client create separate models                    |
| `DISABLE_DEFAULT_REPLICATION = true`  | `NATIVE_WITH_LOCK` | Disables replication while maintaining client-side movement |
| `DISABLE_DEFAULT_REPLICATION = false` | `NATIVE`           | Roblox native replication without modification              |

!!! info
    v1 anchored the server part and used a `REPLICATOR` model for server movement. v2 uses a hidden welded part, so you can move the model directly while replication is locked.

### Replication proximity

v1 had a single global replication distance for players (`PROXIMITY`). v2 has `DEFAULT_NORMAL_TICK_DISTANCE` and `DEFAULT_HALF_TICK_DISTANCE`, and each entity type can override them. See [Distance-based replication](../getting-started/configurations.md#distance-based-replication).

## Entity API

v2 has a single `Entity` module for everything, instead of the separate `NpcRegistry` and `Character` modules. Entity models can also be plain parts, not just models.

### Usage

Creating an entity, moving it, setting its network owner and destroying it, in v1 and v2:

```lua
-- v1
local id = NpcRegistry.Register(model, "NPC", nil, true)
NpcRegistry.SetPosition(id, cframe)
NpcRegistry.SetNetworkOwner(id, player)
local latestCFrame = ChronoServer.GetLatestCFrame(id)
NpcRegistry.UnRegister(id)
```

```lua
-- v2
local entity = Entity.new("NPC", modelOrPartOrModelName)
Entity.SetCFrame(entity, cframe)
Entity.SetNetworkOwner(entity, player)
local latestCFrame = entity.latestCFrame
Entity.Destroy(entity)
```

## Holder

`Holder` replaces v1's separate server and client registries. It tracks entities and player characters on both sides.

## Player handling

`PLAYER_REPLICATION = "AUTOMATIC"` registers characters using the `PLAYER` entity type. Set it to `CUSTOM` to manage player entities yourself.

### Registering players

With `AUTOMATIC`, player entities are created when characters spawn and destroyed when players leave. With `CUSTOM`, register them yourself:

```lua
local newEntity = Entity.new("PLAYER", character)
Holder.SetAsCharacter(player, newEntity)
Entity.SetNetworkOwner(newEntity, player)
```

`chrono.Player.RegisterPlayer(player, character, {})` does the same in one call. See [Custom player management](stateless.md#custom-player-management).

!!! info
    `Holder.SetAsCharacter` sets up character handling, including the camera. It doesn't change replication settings.

Because this uses the Entity API, you can also change a player's character model without a separate character API like v1's.

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
Each entity type has its own ticker. Server-owned entities of the same type share a client clock and interpolation buffer, saving memory and keeping their interpolation consistent.

### Rotation replication
Rotation is set per entity type instead of globally. Use `Entity.SetConfig` to switch types at runtime.

### Culling
v2 has built-in frustum culling, which saves client time by only updating entities the camera can see.
