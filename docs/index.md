---
title: Chrono
hide:
  - navigation
  - feedback
---

# Chrono v2  
### Drop-in custom physics replication solution for Roblox!

Chrono provides full control over replication and physics while remaining compatible with Roblox’s networking model.
It is designed to be drop-in for existing games, with a wide range of configurations allowing for custom characters and more. 

If you like Chrono, consider [starring the repo⭐](https://github.com/Parihsz/chrono)!

---
## Roblox replication "issues" (and what chrono does)

### 1. Fixed replication rate

Roblox replication is capped at *20 Hz*.  

Chrono uses a **dynamic tick rate** instead. Tick rate scales from "default" -> "half" -> "not replicated" based on user provided distances!

---

### 2. Forced interpolation delay

When someone moves, it takes x ms to reach the server and then another x ms to reach another client and then another **200-500**ms (or something around that, we're not too sure) to interpolate.

Chrono lets the DEVELOPER, control the minimum and maximum delay (or u can use a static delay!). You can
introspect it in realtime so lag compensation becomes much nicer :3

---

### 3. No usable historical state

Roblox doesn’t store ur snapshots. Chrono does (and has lagcomp api using serverclock).

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
Cubetian, creator of haobical removed all skidding and made everyting better. 