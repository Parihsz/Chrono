# InterpolationBuffer

## Constructor

**`InterpolationBuffer.new(minBuffer: number, maxBuffer: number, alpha: number) → InterpolationBuffer`**  

Creates a new interpolation buffer instance.

| Parameter       | Type    | Description                                                                 |
|-----------------|--------|-----------------------------------------------------------------------------|
| `minBuffer`     | number | Minimum interpolation buffer in seconds.                                    |
| `maxBuffer`     | number | Maximum interpolation buffer in seconds.                                    |
| `alpha`         | number | Smoothing factor for the **moving average latency**. |

**Returns:**  
A table representing the InterpolationBuffer instance with the methods below.

---

## Properties

### `PlayerLatencies: { [networkId: number]: { averageLatency: number, deviation: number, lastLatency: number? } }`

A dictionary storing **per‑player latency data**, keyed by **networkId**.  
Each entry tracks:  

- **averageLatency** → smoothed round-trip time (RTT)  
- **deviation** → moving deviation (jitter estimate)  
- **lastLatency** → most recent latency sample  

---

## Methods

### `RegisterPacket(networkId: number, serverTime: number, tickRate: number)`

Registers an incoming packet for latency tracking.  

| Parameter     | Type    | Description                                         |
|---------------|--------|-----------------------------------------------------|
| `networkId`   | number | Unique ID representing the player or NPC.           |
| `serverTime`  | number | Timestamp from the **server** for when the packet was sent. |
| `tickRate`    | number | Sending tick rate (Hz) for this entity.             |

---

### `GetBuffer(networkId: number, tickRate: number) → number`

Calculates the **current recommended interpolation buffer** for a given network ID.

| Parameter     | Type    | Description                        |
|---------------|--------|------------------------------------|
| `networkId`   | number | Player or NPC network ID.           |
| `tickRate`    | number | Tick rate (Hz) for this entity.     |

**Returns:**  
A **buffer duration in seconds**, clamped between `minBuffer` and `maxBuffer`.  
