# NpcRegistry

## Initialization

When required, NpcRegistry automatically:

- Creates a **`NPCCacheCamera`** under `workspace` to hold **client clones**.
- Creates or waits for a **`NPC_MODEL_CACHE`** folder in `ReplicatedStorage` for **replicated NPC models**.
- Connects to:

  - **Server:** `RunService.PostSimulation` for automatic NPC transform updates.
  - **Client:** `AttributeChanged` on `NPC_MODEL_CACHE` for automatic client registration. 

---

## Shared API

### `Npc.RegisterNpcModel(model: Model, npcModelType: string) → number`

Adds the NPC model to the config. Used for creating a copy on the client.

| Parameter          | Type       | Description                                                  |
|--------------------|-----------|--------------------------------------------------------------|
| `model`            | `Model`   | The NPC model to register.      |
| `npcModelType`          | `string` | The type of the NPC model.      |

## Server API

### `Npc.Register(model: Model, npcType: string?, modelType: string?, automaticUpdate: boolean?,initData:any?) → number`

Registers an NPC on the server.

| Parameter          | Type       | Description                                                  |
|--------------------|-----------|--------------------------------------------------------------|
| `model`            | `Model`   | The NPC model to register.      |
| `npcType`          | `string?` | Optional NPC type, defaults to `"DEFAULT"`.                  |
| `modelType`       | `string?` | Optional model type, if defined in config then that will use that as the model other wise `model:clone()` will be used.         |
| `automaticUpdate`  | `boolean?`| If true, the server will automatically replicate cframe changes.|
| `initData`        | `any?`   | Optional data to be passed along during initialization. Sent to `Npc.npcAdded`        |

**Returns:**  
The id for the registered NPC.

:::danger
If `initData` is given the data will be serialized using `HttpService:JSONEncode()`. Be aware of what can and cannot be serialized.
:::


---

### `Npc.UnRegister(idOrModel: number | Model) → Model`

Unregisters an NPC from the server and cleans up its cache.

| Parameter       | Type             | Description                             |
|-----------------|-----------------|-----------------------------------------|
| `idOrModel`     | `number | Model` | NPC ID or the registered model.          |

**Returns:**  
The original NPC `Model`.

---

### `Npc.GetModel(id: number) → Model?`

Returns the **original model** for a given NPC ID, if registered.

---


## Signals

These will fired on both the server and client.

### `Npc.npcAdded`

Fired when a new NPC is added.

| Parameter | Type   | Description               |
|-----------|--------|---------------------------|
| `npcId`   | number | The ID of the added NPC.  |
| `model`   | Model  | The model of the added NPC.  |
| `data`    | any    | The initialization data.  |

---

### `Npc.npcRemoved`

Fired when an NPC is removed.


| Parameter | Type   | Description               |
|-----------|--------|---------------------------|
| `npcId`   | number | The ID of the removed NPC. |
| `model`   | Model  | The model of the removed NPC.  |

---

## Client Behavior

On the **client**, NpcRegistry:

1. Clones each NPC into `workspace.NPCCacheCamera` for rendering.
2. Registers the clone with `ClientReplicate` for **smooth interpolation**.
3. Destroys the clone and unregisters automatically when the NPC is removed.

---

:::danger
Animations are non replicated from server to client. If you want NPC animations to be visible, you must play them on the clients. This is also idiomatic as it optimizes roblox transforms. 
:::

## Usage Example

```lua
local NpcRegistry = require(ReplicatedStorage.Packages.chrono).NpcRegistry

NpcRegistry.npcAdded:Connect(function(npcId, model, data)
    print("NPC added:", npcId, model, data)
end)

NpcRegistry.npcRemoved:Connect(function(npcId, model)
    print("NPC removed:", npcId, model)
end)

--Register npc on server
local npcModel = workspace:WaitForChild("Goblin")
NpcCache.Register(npcModel, "DEFAULT", nil, true, { EyeColor = "Green" })

--Change cframe
npcModel:PivotTo(CFrame.new(Vector3.new(20, 5, -20)))

--Unregister for cleanup
NpcCache.UnRegister(npcModel)
```

