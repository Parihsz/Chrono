# Shared.Stats

Live replication stats, also shown in the [debugger](../guides/debugger.md).

```lua
local Stats = require(ReplicatedStorage.Packages.chrono).Stats
print(Stats.SERVER.AVG_TICKER_TIME_MS)
```

Read client stats from `Stats.CLIENT` and server stats from `Stats.SERVER`. Collection runs while an authorized debugger is open, or when enabled with `Stats.SetForced(true)`. Server stats are sent only to clients that have perms and has the debugger open.

## Permissions

### `ReplicateStatsForPlayer(player: Player | number) -> ()`

Server only. Grants debugger access to a player or UserId.

### `StopReplicatingStatsForPlayer(player: Player | number) -> ()`

Server only. Revokes debugger access.

### `HasPermissionToReplicate(player: Player | number) -> boolean`

Returns whether the player has permission. Works on clients too.


## `Stats.CLIENT`

| Field | Meaning |
|---|---|
| `TOTAL_ENTITIES_CULLED` | Entities culled on the client. |
| `ENTITIES_MOVED_THIS_FRAME` | Entities whose CFrame was set this frame. |
| `TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME` | Entities checked for interpolation this frame. |
| `TOTAL_CLIENT_ENTITIES` | Entities registered on the client. |
| `AVG_INTERPOLATION_TIME_MS` | Average time spent interpolating, in milliseconds. |
| `BYTES_RECEIVED_PER_SEC` | Raw bytes received per second for entity replication. |
| `NEW_ENTITIES_PER_SEC` | New entities registered per second. |
| `ENTITY_CHANGES_PER_SEC` | Entity changes processed per second. |
| `ENTITY_REMOVALS_PER_SEC` | Entity removals processed per second. |

## `Stats.SERVER`

| Field | Meaning |
|---|---|
| `AVG_TICKER_TIME_MS` | Average time the ticker takes to process entities, in milliseconds. |
| `ENTITY_GRID_UPDATE_TIME_MS` | Time the last entity grid update took, in milliseconds. |
| `GRID_UPDATE_SECTIONS` | Grid sections updated in the last cycle. |
| `NUMBER_OF_ENTITIES` | Entities registered on the server. |
| `ENTITIES_FULL_TICKED` | Entities ticking at full rate. |
| `ENTITIES_HALF_TICKED` | Entities ticking at half rate. |
| `NON_TICKED` | Entities not ticking. |
| `REPLICATE_PLAYER_TIME_MS` | Average time to replicate entities to a player, in milliseconds. |
| `BYTES_RECEIVED_PER_SEC` | Raw bytes received per second from clients for entity replication. |
| `BYTES_SENT_PER_SEC` | Raw bytes sent per second for entity replication. |
| `PACKETS_SENT_PER_SEC` | Packets sent per second for entity replication. |
