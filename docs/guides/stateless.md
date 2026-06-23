# Integration Patterns

This guide covers advanced patterns for integrating Chrono when you need more control over player management, server-side entity replication, or custom interpolation behavior.

---

## Custom Player Management

### How It Works

To take manual control of player replication, set `PLAYER_REPLICATION = "CUSTOM"` in your config:

```lua
Config.SetConfig("PLAYER_REPLICATION", "CUSTOM")
```

This prevents Chrono from automatically registering players. Instead, you'll handle player setup yourself.

!!!note
    Setting it to custom means will also intern disable `REPLICATE_DEATHS` which may cause issues with player respawning in `NATIVE_WITH_LOCK` and `CUSTOM` replication modes. If you want to replicate deaths, you will need to handle it yourself.

### Implementation

Register a player's character entity manually using either approach:

**Option 1: Direct API calls**
```lua
local entity = -- your entity
local player = -- the player

-- Register entity as the player's character
Holder.SetAsCharacter(player, entity)

-- Give the player network ownership
Entity.SetNetworkOwner(entity, player)
```

**Option 2: Using the Player helper API**
```lua
local Player = require(Chrono.Server.Player)
Player.RegisterPlayer(player, entity)
```

---

## Stateless Replication

If you have entities that don't have physical instances in the world rather stored as data, you can still replicate them to clients using chrono.

### How It Works

Since the entity is stored only as server-side data, you manually push transform updates to replicate it to clients:

```lua
local entity = -- your server entity
local currentTime = os.clock()
local transform = -- your CFrame 
local velocity = -- this is optional, chrono will calculate it if not provided

-- Push the update to clients
Entity.Push(entity, currentTime, transform,velocity)
```

### Integration Pattern

Call `Entity.Push()` at regular intervals—either each frame or when the entity ticks:

```lua
-- Option 1: Every frame
game:GetService("RunService").Heartbeat:Connect(function()
    for _, entity in  entities do
        local newTransform = -- calculate new transform
        Entity.Push(entity, os.clock(), newTransform)
    end
end)

-- Option 2: On entity tick event
local tickEvent = Entity.GetEvent(entity, "Ticked")
tickEvent:Connect(function()
    Entity.Push(entity, os.clock(), newTransform)
end)
```

---

## Custom Interpolation

If you don't want chrono to automatically interpolate the instance CFrame, you can disable it and apply your own logic to the interpolated value. Examples being when dealing with ecs systems or when you want to apply custom logic.

### How It Works

By default, Chrono interpolates entity positions automatically. To take full control:

1. **Disable automatic interpolation** in your entity config:
   ```lua
   Config.RegisterEntityType("CUSTOM_ENTITY", {
        ...,
        CUSTOM_INTERPOLATION = true,
    })
   ```

2. **Manually retrieve interpolated values** using this helper function:
   ```lua
   local function GetInterpolated(entity): CFrame?
       local snapshot = entity.snapshot
       if not snapshot then
           return
       end
       
       local targetTime = Entity.GetTargetRenderTime(entity)
       local targetCFrame = snapshot:GetAt(targetTime)
       
       if not targetCFrame then
           return
       end
       
       return targetCFrame
   end
   ```

3. **Apply your custom logic** to the interpolated value:
   ```lua
   local cframe = GetInterpolated(entity)
   if cframe then
       world:set(jecsEntity, TRANSFORM_COMPONENT, cframe)
   end
   ```

