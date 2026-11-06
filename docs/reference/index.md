# API Overview

Chrono returns a table of modules when you require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local chrono = require(ReplicatedStorage.Packages.chrono)

local Entity = chrono.Entity
```

| Field | Module | Context | Page |
|---|---|---|---|
| `Start(config?)` | | Both | [Start Chrono](../getting-started/start-chrono.md) |
| `Started(callback)` | | Both | [Waiting for startup](../getting-started/start-chrono.md#waiting-for-startup) |
| `Config` | `Shared.Config` | Both | [Configuration](../getting-started/configurations.md) |
| `Entity` | `Shared.Entity` | Both | [Entity](entity.md) |
| `Holder` | `Shared.Holder` | Both | [Holder](holder.md) |
| `Events` | `Shared.Events` | Both | [Events](event.md) |
| `Snapshots` | `Shared.Snapshots` | Both | [Snapshots](snapshots.md) |
| `Stats` | `Shared.Stats` | Both | [Stats](stats.md) |
| `ReplicationRules` | `Shared.ReplicationRules` | Server | [ReplicationRules](replicationrules.md) |
| `ServerReceiver` | `Server.Receiver` | Server | [Receiver](receiver.md) |
| `ServerClock` | `Server.ServerClock` | Server | [ServerClock](serverclock.md) |
| `EntityGrid` | `Server.EntityGrid` | Server | [EntityGrid](entitygrid.md) |
| `Player` | `Server.Player` | Server | [Custom player management](../guides/stateless.md#custom-player-management) |

Each initialized entity type config also exposes a server-side [`ticker`](ticker.md).

Types are also exported:

```lua
local function Heal(entity: chrono.Entity) end
```
