# Mounting
Mounting lets you stick an entity to another. The child follows the parent at a given CFrame offset each frame.

## The basics
To mount an entity, tell it who the parent is and the relative offset.
```lua
Entity.SetMount(follower, carrier, CFrame.new(5, 0, 0))
```
This puts `follower` 5 studs to the right of `carrier`. Every frame, Chrono computes `follower`'s position as `carrier.cframe * offset`.

To detach:
```lua
Entity.ClearMount(follower)
```

## Dynamic offsets
Calling `SetMount` every frame with a new offset is valid and efficient - no need to clear first. This is how you do orbiting, animated attachments, etc.
```lua
RunService.Heartbeat:Connect(function(dt)
    t += dt
    local offset = CFrame.new(math.cos(t) * 5, 0, math.sin(t) * 5)
    Entity.SetMount(follower, carrier, offset)
end)
```

## Chaining
Mounts nest - mount an arm to a body, a hand to the arm, a weapon to the hand, etc.
```lua
Entity.SetMount(arm, body, cframe)
Entity.SetMount(hand, arm, cframe)
```
The resolver walks up the chain once, finds the root, then applies offsets back down. Results are cached per frame so even deep trees do one pass of work.

## Player entities as parents
A player entity can be the parent. The player's physics is client-owned, so Chrono reads its position as a reference - it does not force-set the player's CFrame.
```lua
local plrEntity = Holder.GetEntityFromPlayer(player)
Entity.SetMount(attachedThing, plrEntity, CFrame.new(0, 3, 0))
```

## Listening for mount changes
`Events.EntityMountChanged` fires whenever an entity's mount parent changes (including when cleared).
```lua
Events.EntityMountChanged:Connect(function(entity, mountParentId)
    if mountParentId then
        print(entity.id, "mounted to", mountParentId)
    else
        print(entity.id, "unmounted")
    end
end)
```

## Things to note
* **Server-only.** `SetMount` and `ClearMount` must be called from the server. Mount state is replicated to clients automatically.
* Parents must be registered entities before mounting.
* Mounting continuously zeros the child's linear and angular velocity to keep it locked to the parent.
* Mounting does not affect collision - a child can phase through geometry if the parent moves into a wall.