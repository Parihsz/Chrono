# ECS

Chrono works alongside an ECS such as jecs or Matter. Chrono will replicate and interpolates entities.

How you connect them depends on whether your entities have models on the server:

- **They have models.** Chrono replicates the models as usual, whether Roblox or your own systems move them, and the ECS mirrors Chrono's entities.
- **They don't have models**, such as positions kept only in the ECS. Push their CFrames to Chrono yourself. See [Custom simulation](#custom-simulation).

These examples use jecs:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local chrono = require(ReplicatedStorage.Packages.chrono)
local jecs = require(ReplicatedStorage.Packages.jecs)
local Entity, Holder, Events = chrono.Entity, chrono.Holder, chrono.Events

local world = jecs.World.new()
local ChronoEntity = world:component() -- the Chrono entity
local Transform = world:component() -- CFrame
```

## Linking entities

On the server, create the Chrono entity with the ECS entity. 

```lua
-- Server
local function SpawnGoblin(cframe: CFrame)
	local e = world:entity()
	local model = ReplicatedStorage.Goblin:Clone()
	model.Parent = workspace
	local goblin = Entity.new("NPC", model, nil, cframe)
	Entity.SetData(goblin, { kind = "Goblin" })
	world:set(e, ChronoEntity, goblin)
	return e
end
```

On the client, mirror Chrono's entities as they arrive and leave:

```lua
-- Client
local linked = {}

local function OnAdded(entity)
	if Entity.GetEntityType(entity) ~= "NPC" then
		return
	end
	local e = world:entity()
	world:set(e, ChronoEntity, entity)
	linked[entity] = e
	local kind = Entity.GetData(entity).kind
end

Events.EntityAdded:Connect(OnAdded)
Events.EntityRemoved:Connect(function(entity)
	local e = linked[entity]
	if e then
		world:delete(e)
		linked[entity] = nil
	end
end)
for _, entity in Holder.idMap do -- entities that arrived before this script ran
	OnAdded(entity)
end
```

!!! note
    This example uses Chrono to create client entities. If your ECS replicates its own entities instead, put the server's ECS id in the entity's data, such as `Entity.SetData(goblin, { ecsId = e })`, and link the two on the client by that id.

    - Either one can arrive first, so make sure to handle for this edge case.
    - `EntityRemoved` also fires when an entity goes out of range, while your ECS entity might stay. Unlink it there.

## Reading positions

On the client, read the model's primary part from `RunService.PreRender`:

```lua
-- Client
RunService.PreRender:Connect(function()
	for e, entity in world:query(ChronoEntity) do
		local part = Entity.GetPrimaryPart(entity)
		if part then
			world:set(e, Transform, part.CFrame)
		end
	end
end)
```

To get the interpolated CFrame without a model, use `Entity.GetAt(entity, Entity.GetTargetRenderTime(entity))`.

You can also do it the other way around: set `INTERPOLATION_MODE = "NONE"`, write `Entity.GetAt` into your ECS, and let your own systems move the models. See [Custom interpolation](stateless.md#custom-interpolation).

## Writing positions

To update the server's ECS when a client sends a new position, use the entity's `PushedSnapShot` event. It fires for each snapshot added, with `isNewest` true for the latest one:

```lua
-- Server
Entity.GetEvent(entity, "PushedSnapShot"):Connect(function(_, time, cframe, isNewest)
	if isNewest then
		world:set(e, Transform, cframe)
	end
end)
```

To check or reject a client's position before Chrono applies it, use [`Receiver.RegisterMiddleMan`](../reference/receiver.md).

## Custom simulation

If your entities have no model on the server, such as a 2D movement system without any instances, Chrono has nothing to read positions from. Push them from your simulation and Chrono still replicates and interpolates them.

- Replicate the entity without a server model, set `AUTO_UPDATE_POSITION = false` and push CFrames from your simulation. See [Stateless replication](stateless.md#stateless-replication).
- Set `INTERPOLATION_MODE = "NONE"` and write `Entity.GetAt` into your ECS on the client. See [Custom interpolation](stateless.md#custom-interpolation).

```lua
-- Server
local config = chrono.Config.GetEntityType("NPC") -- after Start
local ticker = assert(config.ticker)

local connection = ticker.Ticked:Connect(function(tick, dt)
	for e, entity, cframe in world:query(ChronoEntity, Transform) do
		if not entity.destroyed and entity.entityConfig == tick.config then
			Entity.Push(entity, tick.lastTicked, cframe)
		end
	end
end)

```

!!! note
	Avoid using `ticker.objects` to iterate entities. It only contains entities that are being ticked. 

```lua
-- Client
RunService.PreRender:Connect(function()
	for e, entity in world:query(ChronoEntity) do
		local cframe = Entity.GetAt(entity, Entity.GetTargetRenderTime(entity))
		if cframe then
			world:set(e, Transform, cframe)
		end
	end
end)
```

!!! note
    You can also push every frame from your simulation instead of from the type ticker. Chrono sends the newest CFrame each tick, stamped with the tick's time.

    ```lua
    -- Server
    RunService.PreSimulation:Connect(function()
    	for e, entity, cframe in world:query(ChronoEntity, Transform) do
    		Entity.Push(entity, os.clock(), cframe)
    	end
    end)
    ```
