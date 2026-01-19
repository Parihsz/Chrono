# Shared.Events
Holds shared event definitions for Chrono.

### `EntityAdded` 
Fired when an entity is added to the holder.

- `entity` - The entity that was added.

### `EntityRemoved`
Fired when an entity is removed from the holder.    
- `entity` - The entity that was removed.

### `PlayerCharacterRegistered`
Fired when a player character entity is registered.
- `player` - The player whose character was registered.
- `entity` - The entity that was registered as the player's character.

### `PlayerCharacterUnregistered`
Fired when a player character entity is unregistered.
- `player` - The player whose character was unregistered.
- `entity` - The entity that was unregistered as the player's character.

### `PlayerOwnedAdded`
Fired when a player-owned entity is added.
- `player` - The player who owns the entity.
- `entity` - The entity that was added as player-owned.

### `PlayerOwnedRemoved`
Fired when a player-owned entity is removed.
- `player` - The player who owned the entity.
- `entity` - The entity that was removed as player-owned.