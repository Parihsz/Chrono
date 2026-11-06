# Server.Receiver

```lua
local chrono = require(ReplicatedStorage.Packages.chrono)
local Receiver = chrono.ServerReceiver
```

## Functions

### `RegisterMiddleMan(name: string, priority: number, callback) -> ()`

Processes incoming client updates before they're applied. Server only.

- `name`: identifies the middleman.
- `priority`: higher values run first.
- `callback`: `(player: Player, entity: Entity, cframe: CFrame, time: number) -> boolean`. Return true to block the update, or false to allow it.

`entity.latestCFrame` and `entity.latestTime` contain the previous accepted update.

### `UnregisterMiddleMan(name: string) -> ()`

Removes a middleman.

## Blocking an update

Return true to block an update. Use `Entity.SetCFrame` to move the owner back to their last accepted position:

Heres is a simple example for limiting speed exploits.
```lua
local DEFAULT_SPEED = 60 -- studs per second for non humanoids
local MAX_VERTICAL_SPEED = 200
local THRESHOLD = 4 -- extra studs allowed for network delays
local MAX_GAP = 1 -- maximum time gap in seconds

Receiver.RegisterMiddleMan("SpeedCheck", 0, function(player, entity, cframe, time)
	local last = entity.latestCFrame
	local lastTime = entity.latestTime
	if not last or not lastTime then
		return false
	end

	local model = chrono.Entity.GetModel(entity)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local maxSpeed = if humanoid then humanoid.WalkSpeed * 1.25 else DEFAULT_SPEED -- x1.25 for a slight buffer

	local dt = math.clamp(time - lastTime, entity.entityConfig.TICK_RATE, MAX_GAP)
	local delta = cframe.Position - last.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local vertical = math.abs(delta.Y)

	local maxHorizontal = maxSpeed * dt + THRESHOLD
	local maxVertical = MAX_VERTICAL_SPEED * dt + THRESHOLD
	if horizontal > maxHorizontal or vertical > maxVertical then
		task.defer(chrono.Entity.SetCFrame, entity, last)
		return true
	end

	return false
end)
```
