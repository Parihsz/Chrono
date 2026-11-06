# Configuration

Chrono's defaults work for most games. Use a shared config module to change them.

## Applying your configuration

Create a ModuleScript in `ReplicatedStorage` for your settings:

```lua
-- ReplicatedStorage.ChronoConfig (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Packages.chrono).Config

Config.SetConfig("DEFAULT_NORMAL_TICK_DISTANCE", 100)
Config.SetConfig("DEFAULT_HALF_TICK_DISTANCE", 200)

Config.RegisterEntityType("FAST_ENTITY", {
	TICK_RATE = 1 / 60,
	BUFFER = 0,
	FULL_ROTATION = true,
})

Config.RegisterEntityType("SLOW_ENTITY", {
	TICK_RATE = 1 / 10,
	BUFFER = 0.25,
})

return nil
```

Then pass the module to `Start` on both the server and the client:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local chrono = require(ReplicatedStorage.Packages.chrono)
chrono.Start(ReplicatedStorage.ChronoConfig)
```

You can also require the config module yourself before calling `Start()`.

!!! warning
    - Configurations should be the same on the server and client.
    - `SetConfig` and `RegisterEntityType` error once Chrono has started. `RegisterEntityModel` and `SetWarningSeverity` work at any time.
    - `SetConfig` errors on unknown settings. Unknown entity type names fall back to `DEFAULT`.
    - Invalid values error when set. Entity types require a positive `TICK_RATE`, such as `1 / 20`.

## All settings

| Setting | Default | Section |
|---|---|---|
| `MIN_BUFFER` | `0.09` | [Buffering](#buffering) |
| `MAX_BUFFER` | `0.5` | [Buffering](#buffering) |
| `DEFAULT_NORMAL_TICK_DISTANCE` | `50` | [Distance-based replication](#distance-based-replication) |
| `DEFAULT_HALF_TICK_DISTANCE` | `100` | [Distance-based replication](#distance-based-replication) |
| `PLAYER_REPLICATION` | `"AUTOMATIC"` | [Player replication](#player-replication) |
| `REPLICATE_DEATHS` | `"PLAYER_CHARACTERS"` | [Death and CFrame replication](#death-and-cframe-replication) |
| `REPLICATE_CFRAME_SETTERS` | `"PLAYER_ENTITIES"` | [Death and CFrame replication](#death-and-cframe-replication) |
| `DEFAULT_MODEL_REPLICATION_MODE` | `"NATIVE"` | [Model replication modes](#model-replication-modes) |
| `DEFAULT_INTERPOLATION_MODE` | `"CFRAME"` | [Interpolation mode](#interpolation-mode) |
| `WARNING_SEVERITY` | `"MEDIUM"` | [Warning severity](#warning-severity) |
| `GRID_UPDATE_INTERVAL` | `0.1` | [Grid updates](#grid-updates) |
| `GRID_MAX_UPDATE_TIME` | `0.0005` | [Grid updates](#grid-updates) |
| `MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER` | `300` | [Client upload limit](#client-upload-limit) |
| `MAX_SNAPSHOT_COUNT` | `30` | [Max snapshot count](#max-snapshot-count) |
| `CHECK_NEW_VERSION` | `true` | [Version check](#version-check) |

## Buffering

The interpolation buffer delays rendering so clients can blend between snapshots. A small a buffer can causes stalling when packets arrive late. For a fixed buffer, two to three send intervals is a useful starting point:

| Send rate | Send interval | 2–3× the interval |
|---|---|---|
| 10 Hz | 100 ms | 200–300 ms |
| 20 Hz | 50 ms | 100–150 ms |
| 30 Hz | 33 ms | 66–100 ms |
| 60 Hz | 17 ms | 33–50 ms |

`BUFFER = 0` adjusts the buffer automatically, as used by `PLAYER`. Chrono uses `max(send interval, largest recent packet gap) + 2 × jitter`, bounded by `MIN_BUFFER` and `MAX_BUFFER`. At 20 Hz on a steady connection, it settles near `MIN_BUFFER`.

!!! info "Changing the buffer at runtime (client only)"
    - **Single entity:** `Entity.SetClockBuffer(entity, seconds)` gives that entity its own buffer. Pass `0` for an automatic buffer, or `nil` to go back to its type's `BUFFER`.
    - **Entity type:** `Config.GetEntityType(name):UpdateBuffer(seconds)`, after `Start`, updates every entity of that type, except those with their own `SetClockBuffer` value. Pass `0` for an automatic buffer.

## Distance-based replication

- **Within `DEFAULT_NORMAL_TICK_DISTANCE`** (50 studs) of a player, an entity is sent to that player at its full tick rate.
- **Between the two distances,** it's sent at half rate.
- **Beyond `DEFAULT_HALF_TICK_DISTANCE`** (100 studs):
    - `NATIVE_WITH_LOCK` and `CUSTOM` entities stop being sent to that player, and are removed from their client until they come back in range.
    - `NATIVE` entities keep being sent at half rate, since Roblox replicates the model anyway.
    - The owner of a client-owned entity always keeps it.

Each entity type can override these with `NORMAL_TICK_DISTANCE` and `HALF_TICK_DISTANCE`. The built-in `PLAYER` type has `HALF_TICK_DISTANCE = math.huge`, so player characters are always sent, to mimic the behavior in default Roblox.

Distances are measured from each player's character entity. See [EntityGrid](../reference/entitygrid.md) to set it manually.



### Half tick margin

An entity near `HALF_TICK_DISTANCE` can cross it many times, so to reduce redundant overhead, `HALF_TICK_MARGIN` adds a gap between when an entity is added and removed. 

`HALF_TICK_MARGIN` adds a gap between where an entity is added and where it's removed. A player gets the entity once it's within `HALF_TICK_DISTANCE`, then keeps it until it's more than `HALF_TICK_DISTANCE + HALF_TICK_MARGIN` away.

```lua
-- In your config module
chrono.Config.RegisterEntityType("SHIP", {
	TICK_RATE = 1 / 20,
	HALF_TICK_DISTANCE = 1500,
	HALF_TICK_MARGIN = 150, -- added within 1500 studs, removed past 1650
})
```


## Player replication

`PLAYER_REPLICATION` decides who creates entities for player characters.

- `AUTOMATIC` (default): Chrono registers each character as a `PLAYER` entity when it spawns, gives the player ownership, and cleans it up when they leave.
- `CUSTOM`: you register characters yourself. See [Custom player management](../guides/stateless.md#custom-player-management).

## Death and CFrame replication

`REPLICATE_DEATHS` forwards client-reported humanoid deaths to the server and other clients. This handles deaths that don't replicate with locked or custom models.

- `NONE`: off.
- `PLAYER_ENTITIES`: for any entity a player owns.
- `PLAYER_CHARACTERS` (default): only for the player's character. This prevents players from killing other entities they own.

It only runs when `PLAYER_REPLICATION = "AUTOMATIC"`.

`REPLICATE_CFRAME_SETTERS` detects when a server sets a client-owned entity's  Model CFrame, such as setting `PivotTo` or `PrimaryPart.CFrame`, and calls `Entity.SetCFrame` to move the owner too.

- `NONE`: off. Call `Entity.SetCFrame` yourself.
- `PLAYER_ENTITIES` (default): for any entity a player owns.
- `PLAYER_CHARACTERS`: only for player characters.

## Model replication modes

`DEFAULT_MODEL_REPLICATION_MODE` is the mode for entity types that don't set their own `MODEL_REPLICATION_MODE`:

- `NATIVE`: Roblox replicates the model and CFrames alongside Chrono. Uses the most bandwidth and does not require extra setup.
- `NATIVE_WITH_LOCK`: Roblox replicates the model and Chrono handles CFrames. Uses less bandwidth, but limits server physics. For example `Touched` no longer fires on the server as its anchored.
- `CUSTOM`: the server and clients use separate models, with only Chrono sending CFrames. Uses the least bandwidth. Register [entity models](#entity-models) on both sides to use model names.

See [Model replication mode](../guides/npcs.md#model-replication-mode) for a side-by-side comparison.

## Entity types

Chrono lets you define entity archetypes that control how they replicate.
Example:
```lua
DEFAULT = {
	TICK_RATE = 1 / 20,
	BUFFER = 0.1,
},
WITH_ROT = {
	TICK_RATE = 1 / 20,
	BUFFER = 0, -- automatic
	FULL_ROTATION = true,
	MODEL_REPLICATION_MODE = "NATIVE",
	HALF_TICK_DISTANCE = math.huge,
	ASSEMBLY_ROOT_PART_CHECK = true,
},
PLAYER = {
	TICK_RATE = 1 / 20,
	BUFFER = 0, -- automatic
	MODEL_REPLICATION_MODE = "NATIVE",
	HALF_TICK_DISTANCE = math.huge, -- always sent, as in default Roblox
	ASSEMBLY_ROOT_PART_CHECK = true,
},
```

Register your own with `Config.RegisterEntityType(name, settings)` before starting. The fields are:

| Field | Default | Meaning |
|---|---|---|
| `TICK_RATE` | required | Seconds between updates: `1 / 20` sends 20 times a second. |
| `BUFFER` | automatic | Interpolation delay in seconds. `0` or omitted uses an automatic buffer. See [Buffering](#buffering). |
| `FULL_ROTATION` | `false` | Send full 3D rotation instead of only yaw. |
| `MODEL_REPLICATION_MODE` | `DEFAULT_MODEL_REPLICATION_MODE` | `NATIVE`, `NATIVE_WITH_LOCK` or `CUSTOM`. |
| `INTERPOLATION_MODE` | `DEFAULT_INTERPOLATION_MODE` | `CFRAME`, `ALIGN` or `NONE`. |
| `INTERPOLATION_FUNCTION` | Hermite | Function that blends two snapshots. See [Interpolation function](#interpolation-function). |
| `NORMAL_TICK_DISTANCE` | `DEFAULT_NORMAL_TICK_DISTANCE` | Full-rate distance. |
| `HALF_TICK_DISTANCE` | `DEFAULT_HALF_TICK_DISTANCE` | Half-rate distance. |
| `HALF_TICK_MARGIN` | `0` | Studs past `HALF_TICK_DISTANCE` an entity stays sent to a player who already has it. See [Half tick margin](#half-tick-margin). |
| `AUTO_UPDATE_POSITION` | `true` | Read the model's CFrame every tick. With `false`, send only CFrames supplied through `Entity.Push`. |
| `STORE_SNAPSHOTS` | `false` | Keep snapshot history on the server for server-owned entities, for [lag compensation](../guides/lag-compensation.md). Client-owned entities always keep it. |
| `CUSTOM_INTERPOLATION` | `false` | Disable Chrono's interpolation for this type. Prefer `INTERPOLATION_MODE = "NONE"` for runtime control. |
| `ASSEMBLY_ROOT_PART_CHECK` | `false` | Skip client interpolation while the primary part isn't the assembly root, such as when welded to another entity. |

!!! warning "Registering a type replaces it"
    `RegisterEntityType` replaces the whole type. Include every field you want to keep, including `TICK_RATE` and any distance overrides. To add full rotation to `PLAYER`:

    ```lua
    Config.RegisterEntityType("PLAYER", {
        TICK_RATE = 1 / 20,
        BUFFER = 0,
        MODEL_REPLICATION_MODE = "NATIVE",
        HALF_TICK_DISTANCE = math.huge,
        ASSEMBLY_ROOT_PART_CHECK = true,
        FULL_ROTATION = true, -- the change rather then just registering  FULL_ROTATION = true
    })
    ```

### Type ticker

The type's shared ticker. Connect to `ticker.Ticked` to update a simulation at the type's `TICK_RATE`.

The ticker is nil before startup and on clients. See [Ticker](../reference/ticker.md).
## Entity models

Register model templates by name so each side can clone its own copy:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local chrono = require(ReplicatedStorage.Packages.chrono)

chrono.Config.RegisterEntityModel("Goblin", ReplicatedStorage.Models.Goblin)
chrono.Config.RegisterEntityModel("CulledGoblin", ReplicatedStorage.Models.Goblin, Vector3.new(4, 6, 4))

-- Server, after Start
local goblin = chrono.Entity.new("DEFAULT", "Goblin", "CUSTOM", CFrame.new(0, 5, 0))
```

`RegisterEntityModel(name, model, broadphase?)` takes:

- `model`: a `Model` with a `PrimaryPart`, a `BasePart`, or `false` for no model on this side.
- `broadphase`: an optional culling box size. Off-screen entities stop interpolating. `Vector3.zero` checks only the center, and omitting it disables culling. Change it later with `Entity.SetBroadPhase`.

Models can be registered after `Start`. In `CUSTOM` mode, each side can use a different model under the same name. See [Different server and client models](../guides/npcs.md#different-server-and-client-models).

### R6 characters

R6 rigs use the Head as their `PrimaryPart`. Chrono automatically uses `HumanoidRootPart` instead for player characters.

For R6 NPCs, call this before creating the entity or registering the template:

```lua
Config.SetModelPrimaryForChrono(model, "HumanoidRootPart")
```

It sets an attribute that Chrono reads when picking the part to move, without changing the model's `PrimaryPart`.

## Warning severity

`WARNING_SEVERITY` is the lowest level of warning Chrono prints:

- `LOW` prints everything.
- `MEDIUM` (default) hides `LOW` warnings.
- `HIGH` prints warnings that are considered high priority.
- `NONE` prints nothing.

Use `LOW` while debugging to see warnings about missing targets or snapshot history:

```lua
Config.SetWarningSeverity("LOW") -- this can work after start() is called
```

The [debugger](../guides/debugger.md) can also change it while the game runs.

## Grid updates

The server updates replication distances every `GRID_UPDATE_INTERVAL` seconds (default `0.1`). Each update uses at most `GRID_MAX_UPDATE_TIME` seconds per frame (default `0.0005`), continuing next frame if needed.

Lower the interval for faster distance checks, or raise the time budget to process more entities per frame. Both cost more server time.

## Client upload limit

The per-frame upload cap is `MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER + owned entities × 21` bytes. Excess data is dropped with a warning.

## Max snapshot count

`MAX_SNAPSHOT_COUNT` is how many snapshots each entity keeps (30 by default). At 20 Hz that is about 1.5 seconds of history, which also limits how far back [lag compensation](../guides/lag-compensation.md) can rewind.

## Version check

`CHECK_NEW_VERSION` checks GitHub at startup and warns if a newer release exists. It requires HTTP requests. Set it to `false` to disable the check.

## Interpolation mode

`DEFAULT_INTERPOLATION_MODE` controls how clients move entities they don't own. The default is `"CFRAME"`.

- `CFRAME`: sets the primary part's CFrame directly. 
- `ALIGN`: uses `AlignPosition` and `AlignOrientation` to move with physics. Useful for ragdolls.
- `NONE`: leaves movement to your code. Snapshots still arrive for `Entity.GetAt`.

!!! warning
    `ALIGN` is experimental. Use it while ragdolling, then switch back to `CFRAME`. See [Ragdolls](../guides/ragdolls.md). `ALIGN` also uses resources as the client will be simulating the physics for that model (even if they don't have ownership).

### Turning interpolation off

Use `Entity.SetInterpolationMode(entity, "NONE")` to disable interpolation at runtime. Calling it on the server replicates the change to every client.

`CUSTOM_INTERPOLATION = true` turns interpolation off for every entity of a type, and can't be changed at runtime.

### Interpolation function

`INTERPOLATION_FUNCTION` decides the CFrame between two snapshots. It receives both snapshots' CFrames and velocities, the progress `t` from 0 to 1, and the time `dt` between them. The default uses a Hermite curve for position and `CFrame:Lerp` for rotation.

```lua
-- In your config module
chrono.Config.RegisterEntityType("Boat", {
	TICK_RATE = 1 / 20,
	INTERPOLATION_FUNCTION = function(from: CFrame, to: CFrame, v0: Vector3, v1: Vector3, t: number, dt: number): CFrame
		return from:Lerp(to, t) -- linear
	end,
})
```
