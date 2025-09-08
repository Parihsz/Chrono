local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local chrono = require(ReplicatedStorage.Packages.chrono)

if RunService:IsServer() then
    Players.PlayerAdded:Connect(function(player)
        local char = player.CharacterAdded:Wait()
        char.Archivable = true
        local c =  char:Clone()
        chrono.Character.SetCharacter(player, c)
        c.PrimaryPart:SetNetworkOwner(player)
    end)
else
    chrono.Character.CharacterAdded:Connect(function(player, model, data)
        if player == Players.LocalPlayer then
            Players.LocalPlayer.Character = model
            workspace.CurrentCamera.CameraSubject = model:FindFirstChildWhichIsA("Humanoid") or model
        end
    end)
end
return nil