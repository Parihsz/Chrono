# Start Chrono

Chrono runs on top of Roblox's replication by default, so you can drop it into an existing game. Starting it registers player characters and enables Chrono's interpolation.

Call `Start` once on the server and once on each client:

```lua
-- Script in ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```

```lua
-- LocalScript in StarterPlayerScripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```


## Startup order

- Apply settings before `Start`. `Config.SetConfig` and `Config.RegisterEntityType` error afterwards. See [Configuration](configurations.md).
- Create entities after `Start`. `Entity.new` errors before it.
- `Start` only runs once, and running multiple time will warn you.

## Waiting for startup

Use `Chrono.Started(callback)` if you have a separate script that needs to wait for Chrono to start before creating entities or accessing configs:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local chrono = require(ReplicatedStorage.Packages.chrono)

chrono.Started(function()
	local entity = chrono.Entity.new("DEFAULT", workspace.Goblin)
	-- Configs and their server tickers are initialized by now.
end)
```

Callbacks run once configs are initialized. Registrations made after start is run immediately. 

## Next steps

- [Configuration](configurations.md): tick rates, buffers and replication modes.
- [Entities](../guides/npcs.md): replicating NPCs and other objects.
- [Debugger](../guides/debugger.md): inspect entities and replication stats.
