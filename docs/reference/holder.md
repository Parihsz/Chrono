# Shared.Holder

A registry that keeps track of every entity.

```lua
local Holder = require(ReplicatedStorage.Packages.chrono).Holder
```

## Properties

### `idMap: { [number]: Entity }`

A map of entity IDs to entity objects.

## Functions

### `GetEntityFromId(id: number) -> Entity?`

The entity with this ID, or nil.

### `GetEntityFromPlayer(player: Player) -> Entity?`

The player's character entity, or nil if they don't have one.

### `GetEntityFromModel(model: Model | BasePart) -> Entity?`

Returns the entity using this model, or nil. Searches all entities, so it's O(n).

### `SetAsCharacter(player: Player, entity: Entity) -> ()`

Sets an already registered entity as the player's character. The previous character entity stays registered. Errors if the new entity isn't registered. Fires `Events.PlayerCharacterRegistered`.

### `RemovePlayerCharacter(entity: Entity) -> ()`

Removes the entity as a player's character, if it is one. Fires `Events.PlayerCharacterUnregistered`.

### `RegisterEntity(entity: Entity) -> ()`

Registers an entity created with `Entity._new`. `Entity.new` already does this for you.

### `UnregisterEntity(entity: Entity) -> ()`

Unregisters an entity without destroying it. Most code should call `Entity.Destroy` instead.
