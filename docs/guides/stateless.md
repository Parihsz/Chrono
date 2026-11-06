# Integration Patterns

Manage player characters, replicate entities without server models, or apply interpolation yourself.

## Custom player management

To create player entities yourself, set `PLAYER_REPLICATION` to `CUSTOM` in your config module:

```lua
Config.SetConfig("PLAYER_REPLICATION", "CUSTOM")
```

You'll need to register characters and handle deaths yourself. `REPLICATE_DEATHS` is disabled in this mode, which can affect respawning with locked or custom models. `REPLICATE_CFRAME_SETTERS` still works.

Use Chrono's player helper:

```lua
-- Server
local entity = chrono.Player.RegisterPlayer(player, character, { config = "PLAYER" })
```

This replaces the previous character entity, handles R6's primary part and assigns ownership. Registering the same character again keeps the model.

Chrono doesn't remove character entities when players leave in this mode. Destroy them yourself:

```lua
-- Server
Players.PlayerRemoving:Connect(chrono.Player.UnregisterPlayer)
```

You can also register a character manually:

```lua
local entity = Entity.new("PLAYER", character)
Holder.SetAsCharacter(player, entity)
Entity.SetNetworkOwner(entity, player)
```

!!! note
    Without a registered character (`SetAsCharacter` for player), the [distance-based tick rate](npcs.md#distance-based-tick-rate) treats the player as standing at `(0, 0, 0)`. Set their position with `EntityGrid.UpdatePlayerPosition(player, position)` whenever it changes.

## Stateless replication

For an entity with no server model, register `false` on the server and a model on clients. Use `CUSTOM` mode:

```lua
-- In your config module (runs on both sides)
if RunService:IsServer() then
	Config.RegisterEntityModel("Rocket", false)
else
	Config.RegisterEntityModel("Rocket", ReplicatedStorage.Models.Rocket)
end
```

```lua
-- Server
local rocket = Entity.new("DEFAULT", "Rocket", "CUSTOM", startCFrame)
```

Push CFrames from your simulation with `Entity.Push`. Use `os.clock()` for server timestamps:

```lua
-- Server
local function update()
	Entity.Push(rocket, os.clock(), GetRocketCFrame()) -- your simulation
end

RunService.PostSimulation:Connect(update)
```

Or push at the entity type's tick rate using its shared ticker on the server after `Start`. Its signal continues while subscribed, even when the entity is out of range:

```lua
local config = Config.GetEntityType("DEFAULT")
local ticker = assert(config.ticker)

local connection = ticker.Ticked:Connect(function(tick, dt)
	Entity.Push(rocket, tick.lastTicked, GetRocketCFrame())
end)

-- disconnect when entity is destroyed

```

See [Ticker](../reference/ticker.md) for more details. 

!!! note "Pushing on the client"
	If you want to push on the client then do it in `RunService.PostSimulation` since it runs before heartbeat which is when Chrono pushes the newest CFrame to the server.

## Custom interpolation

To apply CFrames yourself, such as in an ECS, disable Chrono's interpolation:

- **Entity, at runtime:** `Entity.SetInterpolationMode(entity, "NONE")`. Called on the server, it replicates to clients.
- **A whole entity type:** `INTERPOLATION_MODE = "NONE"`, or `CUSTOM_INTERPOLATION = true`, which can't be changed at runtime.


```lua
-- Client
RunService.Heartbeat:Connect(function()
	local cframe = Entity.GetAt(entity, Entity.GetTargetRenderTime(entity))
	if cframe then
		world:set(jecsEntity, TRANSFORM_COMPONENT, cframe)
	end
end)
```

!!! note
    This turns off everything Chrono does while moving the entity, including `ALIGN` mode, culling, ownership smoothing and `ASSEMBLY_ROOT_PART_CHECK`. Handle these yourself if you need them. Mounted entities still follow their mount.
