# Server.Receiver
Handles receiving entity updates from clients on the server.

## Functions

### `RegisterMiddleMan(name: string, priority: number, callback: function) -> ()`

Registers a middleman function that processes incoming entity updates before they are applied.

- `name` - The name of the middleman.
- `priority` - The priority of the middleman. higher priority runs first.
- `callback` - The function to call for processing. It should take parameters `(player: Player, entity: Entity, cframe: CFrame, time: number) -> boolean`. Return true to block the update, else allow it.

### `UnregisterMiddleMan(name: string) -> ()`
Unregisters a previously registered middleman function.