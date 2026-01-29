# ChronoClient

## Public API

### `RegisterClientNPC(id: number, model: Model, npcType: string?)`

Registers a **client-side NPC** for visual interpolation.

- **`id`** – Network ID assigned by ChronoServer  
- **`model`** – NPC model to interpolate  
- **`npcType`** *(optional)* – Type key in `Config.NPC_TYPES`  

> ☑️ **tip**
This is automatically called when registered in NpcRegistry on the server.
---

### `idMap: { [number]: { ... } }`

Stores the **client-side replication state** for all entities:

- `snapshot` – Circular snapshot buffer of CFrames  
- `character` – Linked `Model` (player or NPC)  
- `lastCFrame` – Last rendered CFrame  
- `isNPC` – Marks NPCs for fixed buffer logic  
- `npcType` – Type used for interpolation config  

---

### `playerTickRates: { [number]: number }`

Tracks **per-entity tick rates** dynamically received from the server.

---

### `BufferTracker`

Reference to the **InterpolationBuffer instance** used to calculate dynamic interpolation delays.

---

### `GetAllNetworkIds() → { number }`

Returns a list of all **network IDs** currently tracked on the client.


## Notes

- **Player replication** is fully automatic after requiring ChronoClient  
- **NPCs must be manually registered** with `RegisterClientNPC()`  
- **idMap** can be read for debugging or rendering purposes  
- Motion is **fully decoupled from Roblox physics buffering**

