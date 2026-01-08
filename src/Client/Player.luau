local Events = require(script.Parent.Parent.Shared.Events)
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
end)

Config._WaitForLock(function()
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		return


	end
end)

return nil
