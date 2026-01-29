---
title: Chrono
hide:
  - navigation
  - feedback
---

# Chrono v2  
!!! warning "Docs under active development"
    These documentation pages are **not finished yet**.  Please visit the v1 tab for documentation on Chrono v1.

### Drop-in custom physics replication solution for Roblox!

Chrono provides full control over replication and physics while remaining compatible with Roblox’s networking model.
It is designed to be drop-in for existing games, with a wide range of configurations allowing for custom characters and more. 

If you like Chrono, consider [starring the repo⭐](https://github.com/Parihsz/chrono)!

---
## Roblox replication "issues" (and what chrono does)

### 1. Fixed replication rate

Roblox replication rate is not configurable.

Chrono uses a *dynamic tick rate* instead with user provided bounds that scale based on proximity. 

---

### 2. Forced interpolation delay

Roblox's interpolation buffer varies between 200-500ms.

Chrono lets the developer control the minimum and maximum delay (or u can use a static delay!). You can
introspect it in realtime so lag compensation becomes much nicer.

---

### 3. No usable historical state

Roblox doesn’t store ur snapshots. Chrono does (and has a built-in lagcomp api using serverclock).

---

### 4. Unoptimized af

For 150 NPCs moving randomly:

*  roblox used 
**110.29 kb/s send** and **412 kb/s receive**.
* chrono used
**3.72 kb/s send** and **42.97 kb/s receive**

---

---

## Showcase!

<div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.2rem;" markdown>

<div markdown>
**Chrono**  
<small>With debug menu showing snapshot history and latency data</small>

<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/d/f/2/5/df255ea0c131a685363564cc8419004c0c8c5313.gif" />
</div>

<div markdown>
**Roblox default**  
<small>In studio with barely any incomingreplatiocatlag</small>

<img src="https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/3/7/4/e/374eb991c49c55d6ac1aa0e935ab31f3224580f0.gif" />
</div>

</div>

---
## Whats new in v2?
* Optimizations to replicator
* More reliable npc replication
* Custom half tick for different npc types
* Mount system
* New method for disabling default replication
* Optional frustum culling