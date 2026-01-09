local Events = require(script.Parent.Parent.Shared.Events)
local Entity = require(script.Parent.Parent.Shared.Entity)
local Holder = require(script.Parent.Parent.Shared.Holder)
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
		if not entity.model:IsA("Model") then
			return warn(`Model for {player} is not a Model instance.`)
		end
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
		newModel(entity, entity.model::any)
	end
end)
local DeathRemote = script.Parent.Parent.Shared.Remotes.Death
Config._WaitForLock(function()
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		return
	end
	Events.PlayerOwnedAdded:Connect(function(player: Player, entity: Types.Entity)  
		local prevConnection:RBXScriptConnection?
		local function newModel(_, model: Model|BasePart?)
			if prevConnection then
				prevConnection:Disconnect()
				prevConnection = nil
			end
		
			if not model or not entity.isContextOwner or not model:IsA("Model") then
				return
			end
			local humanoid = model:FindFirstChildWhichIsA("Humanoid")
		
			if humanoid then
				
				prevConnection = humanoid.Died:Connect(function()
					if not entity.isContextOwner then
						return
					end
					print('dead')
					DeathRemote:FireServer(entity.id)
				end)
			end
		end
		Entity.GetEvent(entity, "ModelChanged"):Connect(newModel)
		newModel(entity, entity.model)
		Entity.GetEvent(entity, "Destroying"):Connect(function()
			if prevConnection then
				prevConnection:Disconnect()
				prevConnection = nil
			end
		end)
	end)
end)

DeathRemote.OnClientEvent:Connect(function(id)
	local entity = Holder.GetEntityFromId(id)
	if not entity then
		return
	end
	if entity.isContextOwner then
		return
	end

	local model = entity.model
	if model then
		local humanoid = model:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
			humanoid.Health = 10
			humanoid.Health = 0
		end
	end
end)
return nil
