Most people are done from just starting chrono. But Chrono offers a wide range of configurations.

## Applying your configurations
First, we will go over how to apply your configurations.

To override Chrono's default configurations create a shared module script that requires the config module and use `SetConfig`, `RegisterEntityType`, and `RegisterEntityModel` before starting Chrono.

Example:
```lua
-- Shared/ChronoConfig.lua
local Config = require(PATH_TO_CHRONO.Shared.Config)

Config.SetConfig("DEFAULT_NORMAL_TICK_DISTANCE", 100)
Config.SetConfig("DEFAULT_HALF_TICK_DISTANCE", 200)
Config.SetConfig("REPLICATE_DEATHS", "PLAYER_CHARACTERS")

Config.RegisterEntityType("FAST_ENTITY", {
    TICK_RATE = 1 / 60,
    FULL_ROTATION = true,
})

Config.RegisterEntityType("SLOW_ENTITY", {
    TICK_RATE = 1 / 20,
    FULL_ROTATION = true,
})

Config.RegisterEntityModel("NPC", PATH_TO_NPC_MODEL)
Config.RegisterEntityModel("NPC_WITH_CULL", PATH_TO_NPC_MODEL,Vector3.new(4,4,4))

return nil
```

Then, in the main script, you can either pass the module or require the module beforehand manually.
```lua
--MAIN SCRIPT

local chrono = require(PATH_TO_CHRONO)
chrono.Start(Shared.ChronoConfig)
```

## Configurations
These are Chrono's default values. If you don't override them, these are the settings chrono will run with. 

```lua
local BASE_CONFIG = {
    __VERSION = "v2.0.0",
    CHECK_NEW_VERSION = true,

    MIN_BUFFER = 0.09,
    MAX_BUFFER = 0.5,
    QUERY_RADIUS = 100,

    DEFAULT_NORMAL_TICK_DISTANCE = 50,
    DEFAULT_HALF_TICK_DISTANCE = 100, -- Beyond this distance, entities stop replicating

    PLAYER_REPLICATION = "AUTOMATIC",

    REPLICATE_DEATHS = "PLAYER_ENTITIES",
    REPLICATE_CFRAME_SETTERS = "PLAYER_ENTITIES",

    DEFAULT_MODEL_REPLICATION_MODE = "NATIVE",

    SEND_FULL_ROTATION = false,
    SHOW_WARNINGS = false,
    MAX_SNAPSHOT_COUNT = 30,
}
```
 We will walk through each of them here one by one.

### Buffering
`MIN_BUFFER` / `MAX_BUFFER` controls interpolation buffer limits. 

In snapshot interpolation, instead of rendering the newest snapshot immediately, we render the world slightly in the past for smooth interpolation between many snapshots. 

Interpolation delay should be large enough that you can lose ~2 packets in a row and still interpolate forward. 

This leads to the widely used heuristic: `Interpolation buffer = 2-3x snapshot interval (1/sendRate)` 

| Snapshot Rate | Snapshot Interval | Minimum Buffer |
|---------------|-------------------|---------------------|
| 10 Hz         | 100 ms            | 200 ms              |
| 20 Hz         | 50 ms             | 100 ms              |
| 30 Hz         | 33 ms             | 66 ms               |
| 60 Hz         | 16.7 ms           | 33 ms               | 

Chrono uses a dynamic interpolation so that it can maintain the *smallest buffer thats still safe*

`MAX_BUFFER` is the hard cap on the interpolation delay. It is recommended to be 2-3x `MIN_BUFFER` so that your interpolation buffer doesn't suddenly jump to like 10000ms 

### Distance-Based Replication
* `DEFAULT_NORMAL_TICK_DISTANCE` defines the distance where entities are replicated at the full rate 
* `DEFAULT_HALF_TICK_DISTANCE` defines the distance where entities replicate at half the rate. Beyond this distance, entities stop replicating entirely.

`Distance < DEFAULT_NORMAL_TICK_DISTANCE` : `Full Tick Rate`

`DEFAULT_NORMAL_TICK_DISTANCE < Distance < DEFAULT_HALF_TICK_DISTANCE` : `Half Tick Rate`

`Distance > DEFAULT_HALF_TICK_DISTANCE` : `No Replication`

VIDEO: TBD

### Player Replication
```lua
PLAYER_REPLICATION = "AUTOMATIC"
```

* `AUTOMATIC` means that player characters are automatically registered as entities. This was the default for v1 but we figured we should give users the ability to choose whether to use Chrono for players.
* `CUSTOM` means that you manually manage player entities. 

!!! Warning
    If you choose `AUTOMATIC` Then make sure you have a `PLAYER` entity type defined.

### Death & CFrame Replication

* `REPLICATE_DEATHS` controls whether Chrono replicates player deaths to the Server and other clients. This is useful for as death replication bugs out when the model is locked or with custom models. 
    * `NONE` - No death replication
    * `PLAYER_ENTITIES` - Replicates deaths of player-registered entities (default)
    * `PLAYER_CHARACTERS` - Replicates deaths of player characters

* `REPLICATE_CFRAME_SETTERS` controls whether Chrono replicated when PrimaryPart.CFrame changes are made on the server for client-registered entities. 
    * `NONE` - No CFrame setter replication
    * `PLAYER_ENTITIES` - Replicates CFrame setters of player-registered entities (default)
    * `PLAYER_CHARACTERS` - Replicates CFrame setters of player characters

### Model Replication Modes

* `NATIVE` - Chrono replicates the model along with using Roblox's native model replication. This is good for cases where you want more responsive replication and don't mind the extra bandwidth.
* `NATIVE_WITH_LOCK` - Chrono replicates the model along with using Roblox's native model replication, but locks the model to disable Roblox's native replication and physics. This is good for client-owned models where server doesn't need to simulate physics. Calls `LockNativeServerCFrameReplication` internally.
* `CUSTOM` - Chrono creates a server and client model separately and only replicates CFrames. This is good for low-bandwidth but requires more manual setup.

### Entity Types
Chrono lets you define entity archetypes that control how they replicate.

Example:
```lua
local ENTITY_TYPES = {
    DEFAULT = {
        NAME = "DEFAULT",
        TICK_RATE = 1 / 30,
        BUFFER = 0.1,
    },

    WITH_ROT = {
        NAME = "WITH_ROT",
        TICK_RATE = 1 / 2,
        BUFFER = 0.1,
        FULL_ROTATION = true,
    },

    PLAYER = {
        NAME = "PLAYER",
        MODEL_REPLICATION_MODE = "NATIVE_WITH_LOCK",
        BUFFER = 0, -- dynamically handled
        TICK_RATE = 1 / 20,
    },
}
```

* `BUFFER` - The buffer time for the npc

* `TICK_RATE` - How often the entity replicates per second.
* `FULL_ROTATION` - Whether to replicate full rotation or just yaw. Default is false (yaw only).
* `MODEL_REPLICATION_MODE` - Overrides the default model replication mode for this entity type.
* `AUTO_UPDATE_POSITION` - This determines if Chrono will automatically call `Entity.Push` when the entity model moves. Default is true. 
* `STORE_SNAPSHOTS` - Whether to store snapshots for this entity on the server side. Default is false. Client-owned entities will ignore this and always store snapshots.
* `NORMAL_TICK_DISTANCE` - Overrides the default normal tick distance for this entity type.
* `HALF_TICK_DISTANCE` - Overrides the default half tick distance for this entity type.
* `CUSTOM_INTERPOLATION` - Whether to use custom interpolation for this entity. Default is false. If is true then chrono will not interpolate the entity automatically on the client.

!!! warning
    NAME field is required if modifying the config table directly. But when using `RegisterEntityType`, the name is taken from the first argument.

### Entity Models

Entity models define reuseable models with specific replication settings.
When `MODEL_REPLICATION_MODE` is set to `CUSTOM`, then only the name of the model string is replicated and the client/server create their own copies of the model, Meaning on the server the model could be a part or not even exist physically, but still shows up on the client.

* `RegisterEntityModel(name: string, model: Model|BasePart, broadphase: Vector3?)` - Registers an entity model with the given name, model, and optional broadphase.
    * `name` - The unique name for the entity model.
    * `model` - The model or base part to use for this entity.
    * `broadphase` - Optional Vector3 defining the broadphase hitbox size for culling. Culled entities will not be moved on the client. If the vector is zero then only a point check is done. Otherwise a box check is done. If not provided, no culling is done. This can also be updated later using `Entity.SetBroadPhase`.
!!! info
    Entity models can be registered after Chrono.Start is called.
    Meaning you can dynamically add new entity models during runtime.