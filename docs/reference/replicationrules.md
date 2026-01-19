# Shared.ReplicationRules

Defines replication rules for entity replication in Chrono.

## Functions

### `SetReplicationRule(target: Player | Model | number | Types.Entity, rule: ReplicationRule | RuleFn | nil) -> ()`

Sets a replication rule for a specific target.

- `target` - The target to set the replication rule for. Can be a Player, Model, Entity ID number, or Entity object.
- `rule` - The replication rule to set. Can be a ReplicationRule struct or a function. If nil, removes any existing rule for the target.
     - `ReplicationRule` : `{
    filterPlayers: {Player}?,
    filterType: "exclude" | "include"
    }`
    - `RuleFn` : `(entity: Entity, player: Player) -> boolean`
      should return true to replicate the entity to the player, false to not replicate.
