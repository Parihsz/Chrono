# Start Chrono!
Chrono runs on top of roblox's replication by default, and can optionally take full control. This makes it easy to drop in without breaking your existing character setup/hitbox logic. Most people just wan't faster replication with minimal overhead!

Starting chrono will automatically set your players up to use chrono's replication and snapshot interpolation 💖
```lua
--Client
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```
```lua
--Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage.Packages.chrono).Start()
```
