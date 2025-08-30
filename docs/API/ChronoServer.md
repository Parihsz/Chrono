# ChronoServer 


## Types

### `ReplicationRule`

| Field     | Type   | Description              |
|----------|-------|--------------------------|
| `filterType`      | "include"/"exclude" | The filter type for the replication rule.   |
| `filterPlayers`  | `{Player}`    | the players to include/exclude from the replication rule. |

If no rule is found then  every Player will receive updates. Otherwise, only the specified players will receive updates.

:::danger
When players leave, players stored in `filterPlayers` will continue to exist, make sure to clean them up if necessary.
:::

---

## Public API

### `idMap: { [number]: { ... } }`

Stores the **server-side replication state** for all entities:
- `player` - The player instance
- `snapshot` – Circular snapshot buffer of CFrames 
- `clientLastTick` The last timestamp of the client 
- `serverOwned` – Whether or not the entity is server-owned (player vs NPC)
- `npcType?` - Type of NPC, if any
- `model` – Linked model to the id
- `replicationRule` – The replication filter the entity is under

---

### `RegisterNPC(model: Model?, npcType: string?) → number`

Registers a new **NPC** on the server and returns its **network ID**.

- **`model`** *(optional)* – The NPC’s physical `Model`.  
  If omitted, Chrono still tracks the NPC **headlessly**.
- **`npcType`** *(optional)* – Type key in `Config.NPC_TYPES`.  
  Defaults to `"DEFAULT"`.

:::danger
Use NpcCache for physical npcs, or you will need to manually push transforms for movement to be replicated
:::
---

### `GetReplicationRule(input: Player | Model | number) → ReplicationRule`

Returns the **replication rule** for a given id, player or model. If no valid id given then return a blank replication rule.

---

### `SetReplicationRule(input: Player | Model | number, rule: ReplicationRule?)`

Sets the **replication rule** for a given id, player or model. If no rule given then remove the existing rule.

---

### `PushNPCTransform(target: number|Model, cframe: CFrame)`

Pushes a new **CFrame snapshot** for a server-owned NPC.

---

### `GetLatestCFrame(target: Player | Model | number) → CFrame?`

Returns the **latest replicated CFrame** for a:

- **Player** – Pass the `Player` instance  
- **NPC** – Pass the `Model` instance  
- **Network ID** – Pass the network ID (`number`)

---

### `GetLatestTime(target: Player | Model | number) → number?`

Returns the **latest replicated time** for a:

- **Player** – Pass the `Player` instance  
- **NPC** – Pass the `Model` instance  
- **Network ID** – Pass the network ID (`number`)

---

### `GetId(target: Player | Model | number) → number?`

Returns the **network ID** for a:

- **Player** – Pass the `Player` instance  
- **NPC** – Pass the `Model` instance
- **Network ID** – Pass the network ID (`number`)

---

### `TogglePlayerReplication(player: Player, on: boolean)`

Toggles whether Chrono should interpolate the player

- **player** – Pass the `Player` instance  
- **on** – Pass a boolean of whether chrono should interpolate

---

### `GetAllNetworkIds() → { number }`

Returns a list of all **network IDs** currently tracked on the server.

---


### `Replicators`

A table mapping **network IDs → dummy Models** used when  
`Config.DISABLE_DEFAULT_REPLICATION = true`.

- Replicators are **visual proxies** cloned from `StarterPlayer.Replicator`  
  and parented to `workspace.CurrentCamera`.  
- Chrono updates them each frame with `BulkMoveTo` based on snapshots.  
- They are useful for running queries on the player's characters on the server.
- You can also access a player's replicator via workspace.Camera[player.Name].

---

## Notes

- ChronoServer drives **all server-side replication**  
- **Players are registered automatically**  
- **NPCs require manual registration** with `RegisterNPC()`  
- `PushNPCTransform` **does not move the model on the server**, only updates snapshots for clients  
- **Disabling default replication** requires:
  - `Config.DISABLE_DEFAULT_REPLICATION = true`
  - Optional **dummy clones** for client visualization

---
