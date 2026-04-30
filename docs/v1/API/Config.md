# Config
Configs on how chronos works. This can be modified pre-runtime or at runtime before initialization.

> ⚠️ **Danger**
Remember to modify the config on both the server and client.

> ⚠️ **Danger**
Only the properties `NPC_MODELS` and `NPC_TYPES` may be modified after `Chrono.Start()` is called, otherwise an error would occur. Other properties must be modified before running `Chrono.Start()`.

## Types

### `NPC_CONFIG`


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

> ⚠️ **Danger**
This will also prevent you from anchoring the primary part of player characters as chrono would be unanchoring locally so they can move as they are anchored on the server to prevent replication.

---

### `SEND_FULL_ROTATION: boolean`
If true, clients and server will replicate **full 3D rotation** (as 3× mapped `u16` values).  
If false (default), only yaw rotation is sent.  
This property can be modified during as chrono is running. 

> 📕 **Note**
Full rotation packets are slightly larger (**24 bytes**) compared to yaw-only packets (**20 bytes**).

---

### `WARNING_SEVERITY: "NONE" | "LOW" | "MEDIUM" | "HIGH"`

Controls the severity of warnings that Chrono outputs. This can be set to "NONE" to disable warnings, or "LOW", "MEDIUM", "HIGH" to control the severity of warnings that are printed. Default is "MEDIUM". Warnings can be set after Chrono is initialize via `Config.SetWarningSeverity()`.

---

### `NPC_MODELS: { [string]: Model }`
A mapping of NPC model names to models that will be cloned.

---

### `NPC_TYPES: {[string]: NPC_CONFIG}`
A mapping of NPC types to their configuration.

---

### `PLAYER_MODELS: { [string]: Model }`
A mapping of player model strings to template models.  
Useful for when `ENABLE_CUSTOM_CHARACTERS` is true.
