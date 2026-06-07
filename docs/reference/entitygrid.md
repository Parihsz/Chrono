# Server.EntityGrid
Tracks which entities are replicated to each player and manages per-player entity holders.

## Types

### `PlayerEntityHolder`
Per-player table tracking which entities are currently replicated to that player.

- `PLAYER` : `Player` - The player this holder belongs to.
- `HALF` : `{ Entity }` - Entities replicating at half tick rate for this player.
- `NORMAL` : `{ Entity }` - Entities replicating at normal tick rate for this player.
- `REPLICATED` : `{ [Entity]: true }` - Set of all entities currently replicated to this player.
- `EntityAdded` : `Signal<(entity: Entity) -> ()>` - Fired when an entity starts being replicated to this player.
- `EntityRemoving` : `Signal<(entity: Entity) -> ()>` - Fired when an entity stops being replicated to this player.

## Functions

### `GetEntityHolder(player: Player) -> PlayerEntityHolder?`

Returns the `PlayerEntityHolder` for the given player, or `nil` if the player has not loaded yet.

- `player` - The player to get the holder for.

### `UpdatePlayerPosition(player: Player, position: vector) -> ()`

Updates the position used for proximity-based replication culling for the given player.

- `player` - The player to update.
- `position` - The new position in world space.
