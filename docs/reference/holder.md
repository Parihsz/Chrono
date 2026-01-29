# Share.Holder
A registry that holds entities.

## Properties

### `idMap : {[number]: Entity}`
A map of entity IDs to entity objects.

## Functions

### `SetAsCharacter(player: Player, entity: Entity) -> ()`
Sets the given entity as the main character for the player.

- `player` - The player whose character entity to set.
- `entity` - The entity to set as the player's character.

### `RemovePlayerCharacter(entity: Entity) -> ()`
Removes the given entity as a player character, if it is one.

- `entity` - The entity to remove as a player character.

### `RegisterEntity(entity: Entity) -> ()`
Registers the given entity in the holder.

### `UnregisterEntity(entity: Entity) -> ()`
Unregisters the given entity from the holder.


### `GetEntityFromId(id: number) -> Entity?`
Gets the entity with the given ID, or nil if not found.

### `GetEntityFromModel(model: Model | BasePart) -> Entity?`
Gets the entity associated with the given model or base part, or nil if not found. This is an o(n) operation.

### `GetEntityFromPlayer(player: Player) -> Entity?`
Gets the entity associated with the given player character, or nil if not found.