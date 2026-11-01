# Server.ServerClock

Server only. Tracks player clock offsets from incoming packets.

```lua
local ServerClock = require(ReplicatedStorage.Packages.chrono).ServerClock
```

## Functions

### `ToServerTime(entity: Entity?, renderTime: number, maxRewind: number?) -> number?`

Converts a client's render time for an entity to server time.

Clamps to the last `maxRewind` seconds, 1 by default. Returns nil for a missing entity or invalid time.

### `ConvertTo(player: Player, clock: number, environment: "Server" | "Client") -> number`

Converts a timestamp from server time to client time or vice versa for the given player.

- `"Server"`: from the player's clock to the server's.
- `"Client"`: from the server's clock to the player's.

Returns `clock` unchanged if nothing has arrived from the player yet.
