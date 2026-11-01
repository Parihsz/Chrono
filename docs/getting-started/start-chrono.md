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
## Next steps

- [Configuration](configurations.md): tick rates, buffers and replication modes.
- [Entities](../guides/npcs.md): replicating NPCs and other objects.
- [Debugger](../guides/debugger.md): inspect entities and replication stats.
