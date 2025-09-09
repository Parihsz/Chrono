# Characters

The **Characters** module manages custom player characters across server and client.  
It handles **registration, cloning, storage, and replication** of player models,  
as well as signals for character lifecycle events.

When required, Characters automatically:

- Creates a container (`PlayerCharacterStorage`) in parented to the `Camera` so it doesn't replicate.
- Creates or waits for a `PLAYER_MODEL_CACHE` folder in `ReplicatedStorage` to hold **replicated player models**.
- Connects to:
  - **Server:** `Players.PlayerRemoving` to clean up models.
  - **Client:** `ChildAdded` on `PLAYER_MODEL_CACHE` to sync characters.

---

## Shared API

### `Characters.GetCharacter(player: Player) → Model?`

Returns the **current character model** registered for the given player,  
or `nil` if no character is set.

---

### `Characters.SetCharacter(player: Player, model: Model | string, data: any?)`

Assigns a character model to the given player.

| Parameter | Type            | Description                                                                 |
|-----------|-----------------|-----------------------------------------------------------------------------|
| `player`  | `Player`        | The player whose character is being set.                                   |
| `model`   | `Model`/`string`| The character model instance, or a key referencing a cached model in `Config.PLAYER_MODELS`. |
| `data`    | `any?`          | Optional initialization data. Serialized via `HttpService:JSONEncode` when replicated. |

- If a **string key** is passed, the model is looked up in `Config.PLAYER_MODELS`.  
- The model is cloned and parented to `PlayerCharacterStorage`.  
- If the player already had a character, it is cleaned up and `CharacterRemoved` is fired.  
- On the **server**, a clone is inserted into `ReplicatedStorage.PLAYER_MODEL_CACHE` to sync with the clients.  
- On the **client**, incoming clones from the cache are registered automatically.

:::danger
If `data` is provided, ensure it is JSON-serializable.
:::

---

## Signals

These fire on both the server and client.

### `Characters.CharacterAdded(player: Player, model: Model, data: any)`

Fired when a new character is registered for a player.

---

### `Characters.CharacterRemoved(player: Player, model: Model)`

Fired when a character is removed (e.g. when replaced or on `PlayerRemoving`).

---

## Internal Behavior

- Models are parented to a hidden **`Camera`** in `workspace` to prevent them from replicating automatically.
- On the **server**, each player’s character is cloned into `PLAYER_MODEL_CACHE`  
  with their `UserId` as the name for identification.  
- On the **client**, clones from `PLAYER_MODEL_CACHE` are consumed, registered, and removed.  
- When a player leaves, their model is destroyed and `CharacterRemoved` is fired.

---

## Usage Example

```lua
--Enable custom characters, else the character system would not work
require(ReplicatedStorage.Packages.chrono).Config.ENABLE_CUSTOM_CHARACTERS = true
local Characters = require(ReplicatedStorage.Packages.chrono).Characters

--Character lifecycles:
Characters.CharacterAdded:Connect(function(player, model, data)
    print("Character added:", player.Name, model, data)
end)

Characters.CharacterRemoved:Connect(function(player, model)
    print("Character removed:", player.Name, model)
end)

--On the server, set a custom character for Chrono to manage
local player = game.Players.PlayerAdded:Wait()
Characters.SetCharacter(player, "paris", { skidding = true })

--On the client (or server), get the character Chrono is managing
local character = Characters.GetCharacter(game.Players.LocalPlayer)

--I recommend setting up your own custom character system and calling chrono so that they can still be custom replicated, rather than depending on chrono to get your characters. We designed chrono's api to be simple and flexible for exactly that. 
```


# Important Notes on Reset Behavior

When using **custom characters** with the `Characters` module, the default Roblox reset flow no longer works.  

- If a player **resets** while using a custom character:
  - The character will **not respawn** automatically.
  - On the **client**, the character will remain in a "dead" state.
  - On the **server**, the character will still be considered alive and will not be replaced.


:::danger
If you enable `Config.ENABLE_CUSTOM_CHARACTERS`, you must implement your own **respawn / reset logic**.  
Roblox’s built-in reset button will no longer respawn the player automatically.
:::

---