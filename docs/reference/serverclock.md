# Server.ServerClock
Manages server time and synchronization with clients.

## Functions

### `ConvertTo(player: Player, clock: number, environment: "Server" | "Client") -> number`
Converts a timestamp from server time to client time or vice versa for the given player.

- `player` - The player to convert the time for.
- `clock` - The timestamp to convert.
- `environment` - Specify "Server" to convert from client time to server time, or "Client" to convert from server time to client time.
