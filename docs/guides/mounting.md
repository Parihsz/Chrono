# Mounting
Mounting lets you stick an entity to another. This makes the child follow the parent around in a fixed offset and is quite useful for many gamedev cases. 

## The basics
To mount an entity, you just tell it who the parent is and the relative offset.
```lua
Entity.SetMount(follower, carrier, CFrame.new(5, 0, 0))
```
This will put follower 5 studs right of the carrier. Every frame, Chrono will compute the follower's position as carrier cframe * offset smoothly. 

To detach, use
```lua
Entity.ClearMount(follower)
```

## You can chain them
Mounts nest so you can mount an arm to a body, a hand to the arm, a weapon to the hand, etc.
```lua
Entity.SetMount(arm, body, cframe)
Entity.SetMount(hand, arm, cframe)
--etc
```
The resolver walks up the chain, finds the root and applies the offsets back down. It caches the results as it goes so even big trees only do 1 pass of work.

## Remounting 
You can swap parents whenever you want, no need to clear first.
```lua
Entity.SetMount(follower, newparent, CFrame.new(0, 0, 5))
```

## Few things to note
* This is server-only. You must mount from the server. 
* Offset is fixed, so you can't have something orbit another person without updating the offset
* Mounting players is a bit wonky. If you mount player A to player B, player A's character controller will fight the mount system. You must disable A's movement.
* Parents need to exist first as entities before mounting 