--!native
local Players = game:GetService("Players")
local Config = require(script.Parent.Parent.Shared.Config)
local Entity = require(script.Parent.Parent.Shared.Entity)
local Holder = require(script.Parent.Parent.Shared.Holder)
local Types = require(script.Parent.Parent.Shared.Types)

local playerEntities = Holder._playerChars

local function RegisterPlayer(
	player: Player,
	character: Model,
	configuration: {
		config: string?,
		modelRepMode: "NATIVE" | "MIRRORED" | "CUSTOM"?,
	}
): Types.Entity
	local entity = playerEntities[player]

	if entity then
		Entity.Destroy(entity)
	end

	local config = configuration.config or "PLAYER"
	local modelRepMode = configuration.modelRepMode
	local newEntity = Entity.new(config, character, modelRepMode :: "NATIVE" | "MIRRORED" | "CUSTOM")
	Holder.RegisterEntity(newEntity)
	Holder.SetAsCharacter(player, newEntity)
	Entity.SetNetworkOwner(newEntity, player)

	-- task.delay(7, function()
	-- 	Entity.SetModel(newEntity, character, "NATIVE", true)
	-- 	task.wait(5)
	-- 	Entity.SetModel(newEntity, character, "MIRRORED", true)
	-- end)

	return newEntity
end

local function UnregisterPlayer(player: Player)
	local entity = playerEntities[player]
	if entity then
		Entity.Destroy(entity)
	end
end

local function OnCharacterAdded(character: Model, player: Player)
	task.wait()
	RegisterPlayer(player, character, {
		config = "PLAYER",
		modelRepMode = Config._GetConfig("DEFAULT_MODEL_REPLICATION_MODE"),
	})
end

local function OnPlayerAdded(player: Player)
	player.CharacterAppearanceLoaded:Connect(function(character: Model)
		OnCharacterAdded(character, player)
	end)
	if player.Character then
		OnCharacterAdded(player.Character, player)
	end
end

Config._WaitForLock(function()
	if Config._GetConfig("PLAYER_REPLICATION") ~= "AUTOMATIC" then
		if Config._GetConfig("SHOW_WARNINGS") then
			warn("automatic player replication is disabled")
		end
		return
	end
	local deathRemote = script.Parent.Parent.Shared.Remotes.Death
	local ReplicateMode:"NONE" | "PLAYER_ENTITIES" | "PLAYER_CHARACTERS" = Config._GetConfig("REPLICATE_DEATHS")
	deathRemote.OnServerEvent:Connect(function(plr, id)
		if ReplicateMode == "NONE" then
			return
		end
		local entity = Holder.GetEntityFromId(id)
		if not entity then
			return
		end
		if entity.networkOwner ~= plr or entity.modelReplicationMode == "NATIVE" then
			return
		end
		if ReplicateMode == "PLAYER_CHARACTERS" and not entity._player then
			return
		end
		
		local model = entity.actualModel or entity.model
		if entity.actualModel then
			local camera = entity.actualModel:FindFirstChildWhichIsA("Camera")
			if camera then
				camera:Destroy()
			end
			entity.actualModel:PivotTo(entity.latestCFrame or CFrame.new())
			if entity.model then
				(entity.model :: any).Parent = nil
			end	
		end
		if model then
			local humanoid = model:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid.Health = 0
				humanoid.Health = 10
				humanoid.Health = 0
			end
		end
		deathRemote:FireAllClients(id)
	end)
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(UnregisterPlayer)

	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
end)

return {
	RegisterPlayer = RegisterPlayer,
	UnregisterPlayer = UnregisterPlayer,
}
