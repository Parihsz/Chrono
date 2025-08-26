# Config
Configs on how chronos works. This can be modified pre-runtime or at runtime before initialization.

:::danger
Remember to modify the config on both the server and client.
:::

:::danger
All properties except for `NPC_MODELS` and `NPC_TYPES` may be modified after `Chrono.Start()` is called, otherwise an error would occur.
:::

## Types

### `NPC_CONFIG`

| Field     | Type   | Description              |
|----------|-------|--------------------------|
| `TICK_RATE`      | number | The tick rate for the npc   |
| `BUFFER`  | number    | the buffer time for the npc |

---

## Properties

### `MIN_BUFFER: number`

The minimum buffer time for snapshots.

---

### `MAX_BUFFER: number`

The maximum buffer time for snapshots.

---

### `PROXIMITY: number`

The proximity threshold in studs where TICK_RATE is applied.

---

### `ENABLE_CUSTOM_CHARACTERS: boolean`
If true, allows the use of custom characters in the game. This will disable default roblox replication as well.

---

### `DISABLE_DEFAULT_REPLICATION: boolean`
If true, disables default roblox replication for players.

---

### `NPC_MODELS: { [string]: Model }`
A mapping of NPC model names to models that will be cloned.

---

### `NPC_TYPES: {[string]: NPC_CONFIG}`
A mapping of NPC types to their configuration.

---

