# Shared.Stats

Stores statistical data.

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

TBD



