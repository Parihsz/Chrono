---
title: Chrono
hide:
  - navigation
  - feedback
---

# Chrono


### Drop-in custom physics replication solution for Roblox!
Chrono provides full control over replication and physics while remaining compatible with Roblox’s networking model. It is designed to be drop-in for existing games, with a wide range of configurations allowing for custom characters and more.

---

## Quickstart 
Copy this into your client and server starter scripts to enable Chrono immediately.

```lua
-- Shared (both client & server)
local chrono = require(ReplicatedStorage.Packages.chrono)
chrono.Start()
```

For configurations, see [Getting Started: Configurations](getting-started/configurations.md).

---

## Why Chrono?

- **Fixes Roblox replication limitations:** dynamic tick rates and distance-based replication.
- **Smaller interpolation delay:** configurable buffer control for smoother client rendering.
- **Snapshot history & lag compensation:** snapshots API and built in lagcomp api.
- **Flexible model replication modes:** `NATIVE`, `NATIVE_WITH_LOCK`, and `CUSTOM` for  [bandwidth/perf tradeoffs](../guides/npcs#model-replication-mode).

---

## Showcase

<div class="grid" style="grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1.2rem;">

<figure style="margin: 0;">
<div style="aspect-ratio: 16 / 9; overflow: hidden;">
<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/d/f/2/5/df255ea0c131a685363564cc8419004c0c8c5313.gif" alt="Chrono debug menu showing snapshot history and latency" style="display:block; width:100%; height:100%; object-fit:cover;" />
</div>
<figcaption>Chrono</figcaption>
</figure>

<figure style="margin: 0;">
<div style="aspect-ratio: 16 / 9; overflow: hidden;">
<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/3/7/4/e/374eb991c49c55d6ac1aa0e935ab31f3224580f0.gif" alt="Roblox default replication example" style="display:block; width:100%; height:100%; object-fit:cover;" />
</div>
<figcaption>Roblox default replication</figcaption>
</figure>

<figure style="margin: 0; grid-column: 1;">
<div style="aspect-ratio: 16 / 9; overflow: hidden;">
<img src="assets/showcase.gif" alt="Chrono showcase animation" style="display:block; width:100%; height:100%; object-fit:cover;" />
</div>
<figcaption>Side By Side Comparison: <strong style="color: #d32f2f;">Red</strong> = Roblox, <strong style="color: #1976d2;">Blue</strong> = Native with lock, <strong style="color: #111111;">Black</strong> = Native</figcaption>
</figure>

</div>

---

## What's new in v2

- Optimizations to the replicator
- More reliable NPC replication
- Custom half-tick for different NPC types
- Mount system
- New method for disabling default replication
- Optional frustum culling (client-sided)

---


If you like Chrono, consider [starring the repo ⭐](https://github.com/Parihsz/Chrono). If you encounter any issues feel free to open an issue on GitHub or on the Roblox Developer Forum.
