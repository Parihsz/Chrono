# Shared.Events

Shared events for entities and players.

```lua
local Events = require(ReplicatedStorage.Packages.chrono).Events

Events.EntityAdded:Connect(function(entity)
	print("entity", entity.id, "added")
end)
```

| Event | Arguments | Fires when |
|---|---|---|
| `EntityAdded` | `entity` | An entity is registered or arrives on a client. |
| `EntityRemoved` | `entity` | An entity is unregistered. |
| `PlayerCharacterRegistered` | `player`, `entity` | An entity becomes a player's character. |
| `PlayerCharacterUnregistered` | `player`, `entity` | An entity stops being a player's character. |
| `PlayerOwnedAdded` | `player`, `entity` | A player becomes an entity's owner. |
| `PlayerOwnedRemoved` | `player`, `entity` | `player` stops owning the entity. |
| `EntityMountChanged` | `entity`, `mountParentId: number?` | An entity's mount changes, with nil when it's cleared. Fires on the server from `SetMount` and `ClearMount`, and on clients when the change arrives. |

See also [Entity events](entity.md#events).
