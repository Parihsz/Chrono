# Shared.Stats

Stores statistical data.

### `REPLICATE_PERMISSIONS` :{[`number`]: `boolean`} | `nil`

A table mapping UserIds to booleans indicating whether that user is allowed to receive server stats updates. If `nil`, stats are sent to all players.

## Client

### `TOTAL_ENTITIES_CULLED` : `number`

Total number of entities that have been culled on the client.

### `ENTITIES_MOVED_THIS_FRAME` : `number`

Number of entities that had their CFrames moved in the current frame.

### `TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME` : `number`

Total number of client entities that were checked for updates in the current frame during interpolation.

### `TOTAL_CLIENT_ENTITIES` : `number`

Total number of entities registered on the client.

### `AVG_INTERPOLATION_TIME_MS` : `number`

Average time in milliseconds taken for interpolation calculations on the client.

### `BYTES_RECEIVED_PER_SEC` : `number`

Average number of raw bytes received per second by the client for entity replication. Does not include compression.

### `NEW_ENTITIES_PER_SEC` : `number`

Average number of new entities registered per second on the client.

### `REMOVED_ENTITIES_PER_SEC` : `number`

Average number of entities removed per second on the client.

### `ENTITY_REMOVALS_PER_SEC` : `number`

Average number of entity removals processed per second on the client.

## Server

### `AVG_TICKER_TIME_MS` : `number`
Average time in milliseconds taken for the server ticker to process entity updates.

### `GRID_UPDATE_SECTIONS` : `number`
Number of grid sections updated in the last grid update cycle.

### `ENTITY_GRID_UPDATE_TIME_MS` : `number`
Total time in milliseconds taken for the entity grid to update in the last cycle.

### `NUMBER_OF_ENTITIES` : `number`
Total number of entities registered on the server.

### `ENTITIES_HALF_TICKED` : `number`
Number of entities that are being half-ticked on the server.

### `ENTITIES_FULL_TICKED` : `number`
Number of entities that are being fully ticked on the server.

### `NON_TICKED` : `number`
Number of entities that are not being ticked on the server.

### `REPLICATE_PLAYER_TIME_MS` : `number`
Average time in milliseconds taken to replicate entities to a player.

### `BYTES_RECEIVED_PER_SEC` : `number`
Average number of raw bytes received per second by the server for entity replication. Does not include compression.

### `BYTES_SENT_PER_SEC` : `number`
Average number of raw bytes sent per second by the server for entity replication. Does not include compression

### `PACKETS_SENT_PER_SEC` : `number`
Average number of packets sent per second by the server for entity replication.

