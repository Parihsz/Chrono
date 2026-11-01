# Shared.ReplicationRules

Server only. Decides which players each entity is sent to.

```lua
local Teams = game:GetService("Teams")
local ReplicationRules = require(ReplicatedStorage.Packages.chrono).ReplicationRules

-- Only the red team can receive this entity
ReplicationRules.SetReplicationRule(npc, function(entity, viewer)
	return viewer.Team == Teams.Red
end)
```

Without a rule, an entity is sent to everyone in range.

## Functions

### `SetReplicationRule(target, rule) -> ()`

Sets or removes the rule for one entity.

`target` accepts an entity, ID, model or player. A player refers to their current character entity.

`rule` accepts:

- A function `(entity, viewer: Player, viewerEntityId: number?) -> boolean`. Return true to send the entity. `viewerEntityId` is the viewer's character entity ID, or nil.
- A table `{ filterType: "include" | "exclude", filterPlayers: { Player }? }`.
- nil to remove the rule.

### `Include(players: { Player }) -> RuleFn` and `Exclude(players: { Player }) -> RuleFn`

```lua
ReplicationRules.SetReplicationRule(npc, ReplicationRules.Include({ player }))
```

An empty `Include` list sends the entity to no one, and an empty `Exclude` list sends it to everyone.

### `Allows(entity, viewer: Player) -> boolean`

Whether the entity's current rule lets `viewer` see it.
