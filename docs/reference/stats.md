# Shared.Stats

Stores statistical data used by Chrono.

### `REPLICATE_PERMISSIONS` : { [`number`]: `boolean` } 

A table mapping UserIds to booleans indicating whether that user is allowed to receive server stats updates. 

## Client

### `TOTAL_ENTITIES_CULLED` : `number`

Total number of entities that have been culled on the client.

### `ENTITIES_MOVED_THIS_FRAME` : `number`

Number of entities whose CFrame was moved during the current frame.

### `TOTAL_CLIENT_ENTITIES_CHECKED_THIS_FRAME` : `number`

Total number of client entities checked for updates in the current frame during interpolation.

### `TOTAL_CLIENT_ENTITIES` : `number`

Total number of entities registered on the client.

### `AVG_INTERPOLATION_TIME_MS` : `number`

Average time in milliseconds spent on interpolation calculations on the client.

### `BYTES_RECEIVED_PER_SEC` : `number`

Average raw bytes received per second by the client for entity replication.

### `NEW_ENTITIES_PER_SEC` : `number`

Average number of new entities registered per second on the client.

### `ENTITY_CHANGES_PER_SEC` : `number`

Average number of entity change events processed per second on the client.

### `ENTITY_REMOVALS_PER_SEC` : `number`

Average number of entity removals processed per second on the client.

## Server

### `AVG_TICKER_TIME_MS` : `number`

Average time in milliseconds taken for the server ticker to process entity updates.

### `ENTITY_GRID_UPDATE_TIME_MS` : `number`

Total time in milliseconds taken for the entity grid update in the last cycle.

### `GRID_UPDATE_SECTIONS` : `number`

Number of grid sections updated during the last grid update cycle.

### `NUMBER_OF_ENTITIES` : `number`

Total number of entities registered on the server.

### `ENTITIES_FULL_TICKED` : `number`

Number of entities being fully ticked on the server.

### `ENTITIES_HALF_TICKED` : `number`

Number of entities being half-ticked on the server.

### `NON_TICKED` : `number`

Number of entities that are not being ticked on the server.

### `REPLICATE_PLAYER_TIME_MS` : `number`

Average time in milliseconds taken to replicate entities to a player.

### `BYTES_RECEIVED_PER_SEC` : `number`

Average raw bytes received per second by the server for entity replication.

### `BYTES_SENT_PER_SEC` : `number`

Average raw bytes sent per second by the server for entity replication.

### `PACKETS_SENT_PER_SEC` : `number`

Average number of packets sent per second by the server for entity replication.

## Functions

### `HasPermissionToReplicate(userId: number | Player)` : `boolean`

Returns whether the specified player or userId is allowed to receive replicated stats.

### `ReplicateStatsForPlayer(userId: number | Player)`

Marks the given player or userId as allowed to receive server stats updates. SERVER ONLY.

### `StopReplicatingStatsForPlayer(userId: number | Player)`

Removes the given player or userId from the stats replication permission list. SERVER ONLY.

