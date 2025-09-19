local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local chrono = require(ReplicatedStorage.Packages.chrono)

if not chrono.Config.ENABLE_CUSTOM_CHARACTERS then
	return nil
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char: Model)
			chrono.Character.SetCharacter(player, char)
		end)
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
