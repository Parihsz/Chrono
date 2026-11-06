# Server.EntityGrid

Server only. Tracks which entities are sent to each player.

```lua
local EntityGrid = require(ReplicatedStorage.Packages.chrono).EntityGrid
```

## Types

### `PlayerEntityHolder`

Entities sent to one player:

- `PLAYER: Player`: the player this holder belongs to.
- `NORMAL: { Entity }`: entities sent to them at full rate.
- `HALF: { Entity }`: entities sent to them at half rate.
- `REPLICATED: { [Entity]: true }`: every entity currently sent to them.
- `EntityAdded: Signal<(entity: Entity) -> ()>`: fires when an entity starts being sent to them.
- `EntityRemoving: Signal<(entity: Entity) -> ()>`: fires when an entity stops being sent to them.


!!! info
    Connect through `.Event`, for example: `holder.EntityAdded.Event:Connect(fn)`.

## Functions

### `GetEntityHolder(player: Player) -> PlayerEntityHolder?`

The player's holder, or nil until their client has loaded Chrono.

### `IsReplicated(player: Player, entity: Entity) -> boolean`

Whether the entity is currently sent to the player. 

### `UpdatePlayerPosition(player: Player, position: Vector3) -> ()`

Sets the player's position for distance checks. Chrono updates this automatically for registered characters. Without a position, it uses <0,0,0>.
