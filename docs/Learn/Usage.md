# Basic Usage

Chrono runs **on top of Roblox’s default replication by default** and can optionally take full control if you disable replication. This makes it **easy to drop in** without breaking your existing character setup.


To implement:

- Drop the client and server modules into **ReplicatedStorage** (with the suggested structure)  
- Require them in your **server and client scripts**  
- Most replication (snapshots, interpolation buffers, networkables) works **automatically**

---

### Initial Setup

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
Once required and started:

- **Player replication** will begin
- **Snapshots** and **dynamic interpolation buffers** are handled internally  
- **CFrame updates** are batched and serialized 

---

### Registering NPCs

If you want to **replicate NPCs** with Chrono:
```lua
--Server-side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NpcRegistry = require(ReplicatedStorage.Packages.chrono).NpcRegistry

NpcRegistry.Register(npcModel, "DEFAULT", "TestNPCs", true)

--you will simply need to update the npc's cframe and it would automatically be replicated.
--default replication is fully disabled in this case.
--animations will not replicate from server. please play them from the client.
```

#### Notes

- You must use ChronoServer/ChronoClient's npc registration function if you want to perform headless tracking without a model. NpcRegistry requires a model for it to work. 
- `PushNPCTransform` **updates the NPC’s snapshot**, which Chrono automatically interpolates on all clients. NpcRegistry will automatically call this if you change the CFrame of a npc registered within it on the server.
- NPCs are treated the same as players except they will have a fixed interpolation buffer

:::danger
Animations are non replicated from server to client. If you want NPC animations to be visible, you must play them on the clients. This is also idiomatic as it optimizes roblox transforms. 
:::
---

### Getting the Latest CFrame

If you need the **latest replicated position** of a player or NPC for logic (hit detection, AI, etc.):
```lua
local ChronoServer = require(ReplicatedStorage.Packages.chrono).ChronoServer
local npcId = ChronoServer.GetId(npcModel_OR_player) -- or npcModel:GetAttribute("NPC_ID") 
local cframe = ChronoServer.GetLatestCFrame(npcId or player)
if cframe then
    print(`Latest replicated position: {cframe.Position}`)
end
```
---
