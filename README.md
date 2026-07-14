# Chrono

Drop-in custom physics replication and lag compensation for Roblox.

## Why Chrono?

Roblox's default replication has several limitations that make responsive multiplayer gameplay difficult to achieve. By default, physics is replicated at 20hz, and all characters are subject to a large, non-configurable interpolation delay designed primarily for mobile devices on low-bandwidth connections.

NPC replication is especially inefficient. Roblox often triggers excessive recv traffic for parts moved on the server - sometimes 10x higher than an optimized custom solution - and can also incur unnecessary send usage that is 100x more than normal. This wastes bandwidth and reduces performance.

Chrono solves all of these problems, while also improving developer experience:

- **Bypasses Roblox's interpolation delay** by manually forwarding CFrame data to other players with a configurable, custom dynamic interpolation delay.
- **Far more accurate lag compensation** by providing access to historical snapshot data and exposing the interpolation delay.
- **Optimized server-controlled entity replication** by elegantly disabling default replication. Chrono then sends its own compressed replication data using a fraction of the bandwidth.
- **Real-time debugging** - Chrono’s API allows developers to create real time debuggers that hooks onto its snapshot and latency system, letting you view exact replication data, packet loss, and per player interpolation states.

## Docs

Full documentation: https://parihsz.github.io/Chrono/

## Quickstart

```lua
local chrono = require(ReplicatedStorage.Packages.chrono)
chrono.Start()
```

## Showcase

<table>
<tr>
<td width="50%">
<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/d/f/2/5/df255ea0c131a685363564cc8419004c0c8c5313.gif" alt="Chrono replication" width="100%" />
<p align="center"><strong>Chrono</strong></p>
</td>
<td width="50%">
<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/3/7/4/e/374eb991c49c55d6ac1aa0e935ab31f3224580f0.gif" alt="Roblox default replication" width="100%" />
<p align="center"><strong>Roblox default replication</strong></p>
</td>
</tr>
</table>

<img src="docs/assets/showcase.gif" alt="Side by side comparison of replication modes" width="100%" />
<p align="center">Side by side comparison: <strong>Red</strong> = Roblox, <strong>Blue</strong> = Native with lock, <strong>Black</strong> = Native</p>

## Benchmarks

150 entities moved using `Humanoid:MoveTo` every 0.1 seconds to a random location (half ticking disabled). Chrono tick rate set to 10 TPS without full rotation. Packet size was measured using the `Stats` service (`Stats.DataSendKbps + Stats.PhysicsSendKbps`), sampled every 0.1 seconds and averaged over 60 seconds.

| Mode | Server Send (Kbps) | Client Recv (Kbps) |
|---|---|---|
| Native | 56.81 | 50.49 |
| Roblox | 34.57 | 28.74 |
| Native with lock | 28.98 | 22.13 |
| Custom | 22.10 | 21.92 |

Raw footage: https://youtu.be/xo8EJ9YHSi4

See [benchmarks/EntityBench.md](benchmarks/EntityBench.md) and [test/tests/benchEntities.luau](test/tests/benchEntities.luau) for more details on the tests.
