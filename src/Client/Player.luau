local Events = require(script.Parent.Parent.Shared.Events)
local Entity = require(script.Parent.Parent.Shared.Entity)
local Types = require(script.Parent.Parent.Shared.Types)
local Config = require(script.Parent.Parent.Shared.Config)

local LocalPlayer = game:GetService("Players").LocalPlayer

Events.PlayerCharacterRegistered:Connect(function(player: Player, entity: Types.Entity)
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		return
	end
	if not entity.model then
		return warn(`No model found for {player}`)
	end
	if entity.model then
		player.Character = entity.model
	end

	local function newModel(entity, model: Model?)
		if not model then
			return
		end
		LocalPlayer.Character = entity.model
		local cf = workspace.CurrentCamera.CFrame
		workspace.CurrentCamera.CameraSubject = entity.model:FindFirstChildWhichIsA("Humanoid")
			or entity.model.PrimaryPart
		workspace.CurrentCamera.CFrame = cf
		for i,v in model:QueryDescendants("LocalScript") do
			if v:IsA("LocalScript") then
				v.Disabled = true
				v.Disabled = false
			end
		end
	end

	if LocalPlayer == player then
		Entity.GetEvent(entity, "ModelChanged"):Connect(newModel)
		newModel(entity, entity.model)
	end
end)

Config._WaitForLock(function()
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		return
	end
end)

return nil
