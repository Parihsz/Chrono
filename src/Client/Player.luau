local Holder = require(script.Parent.Parent.Shared.Holder)
local Events = require(script.Parent.Parent.Shared.Events)
local Entity = require(script.Parent.Parent.Shared.Entity)
local Types = require(script.Parent.Parent.Shared.Types)
local Config = require(script.Parent.Parent.Shared.Config)

local LocalPlayer = game:GetService("Players").LocalPlayer

Events.PlayerCharacterRegistered:Connect(function(player: Player, entity: Types.Entity) 
    if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
        return
    end
    if not entity.model then return warn(`No model found for {player}`) end 
    if entity.model then
        player.Character = entity.model
    end
    if LocalPlayer == player then
        -- workspace.CurrentCamera.CameraSubject = entity.model:FindFirstChildWhichIsA("Humanoid") or entity.model.PrimaryPart
        -- for _, localScript in entity.model:QueryDescendants("LocalScript") do
        --     if localScript:IsA("LocalScript") then
        --         localScript.Disabled = true
        --         localScript.Disabled = false
        --     end
        -- end
    end
end)

return nil
